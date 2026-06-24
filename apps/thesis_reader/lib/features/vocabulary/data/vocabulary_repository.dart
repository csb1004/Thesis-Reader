import 'package:drift/drift.dart';
import 'package:thesis_reader/features/vocabulary/domain/vocabulary_normalizer.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';
import 'package:uuid/uuid.dart';

abstract interface class VocabularyRepository {
  Future<VocabularyEntryView> upsert(VocabularyDraft draft);
  Future<List<VocabularyEntryView>> listForDocument(String documentId);
  Future<int> countForDocument(String documentId);
  Future<void> delete(String entryId);

  Future<VocabularyEntryView> updateUserMeaningAndMemo({
    required String entryId,
    required String? userMeaning,
    required String? userMemo,
  });
}

final class VocabularyDraft {
  const VocabularyDraft({
    required this.documentId,
    required this.expression,
    required this.meaningKo,
    required this.sourceSentence,
    required this.contextBefore,
    required this.contextAfter,
    this.blockId,
    this.textOffset,
    this.userMeaning,
    this.userMemo,
  });

  final String documentId;
  final String expression;
  final String? meaningKo;
  final String? sourceSentence;
  final String? contextBefore;
  final String? contextAfter;
  final String? blockId;
  final int? textOffset;
  final String? userMeaning;
  final String? userMemo;
}

final class VocabularyEntryView {
  const VocabularyEntryView({
    required this.id,
    required this.documentId,
    required this.expressionKey,
    required this.expression,
    required this.meaningKo,
    required this.sourceSentence,
    required this.contextBefore,
    required this.contextAfter,
    required this.blockId,
    required this.textOffset,
    required this.userMeaning,
    required this.userMemo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String documentId;
  final String expressionKey;
  final String expression;
  final String? meaningKo;
  final String? sourceSentence;
  final String? contextBefore;
  final String? contextAfter;
  final String? blockId;
  final int? textOffset;
  final String? userMeaning;
  final String? userMemo;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class DriftVocabularyRepository implements VocabularyRepository {
  DriftVocabularyRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<VocabularyEntryView> upsert(VocabularyDraft draft) {
    final expressionKey = normalizeVocabularyExpression(draft.expression);
    if (expressionKey.isEmpty) {
      throw ArgumentError.value(draft.expression, 'expression', 'is empty');
    }

    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.vocabularyEntries)..where(
                (entry) =>
                    entry.documentId.equals(draft.documentId) &
                    entry.expressionKey.equals(expressionKey),
              ))
              .getSingleOrNull();

      final now = DateTime.now().toUtc();

      if (existing != null) {
        await (_database.update(
          _database.vocabularyEntries,
        )..where((entry) => entry.id.equals(existing.id))).write(
          VocabularyEntriesCompanion(
            expression: Value(draft.expression),
            meaningKo: Value(draft.meaningKo),
            sourceSentence: Value(draft.sourceSentence),
            contextBefore: Value(draft.contextBefore),
            contextAfter: Value(draft.contextAfter),
            blockId: Value(draft.blockId),
            textOffset: Value(draft.textOffset),
            userMeaning: Value(draft.userMeaning ?? existing.userMeaning),
            userMemo: Value(draft.userMemo ?? existing.userMemo),
            updatedAt: Value(now),
          ),
        );

        return _findById(existing.id);
      }

      final id = _uuid.v4();
      await _database
          .into(_database.vocabularyEntries)
          .insert(
            VocabularyEntriesCompanion.insert(
              id: id,
              documentId: draft.documentId,
              expressionKey: expressionKey,
              expression: draft.expression,
              meaningKo: Value(draft.meaningKo),
              sourceSentence: Value(draft.sourceSentence),
              contextBefore: Value(draft.contextBefore),
              contextAfter: Value(draft.contextAfter),
              blockId: Value(draft.blockId),
              textOffset: Value(draft.textOffset),
              userMeaning: Value(draft.userMeaning),
              userMemo: Value(draft.userMemo),
              createdAt: now,
              updatedAt: now,
            ),
          );

      return _findById(id);
    });
  }

  @override
  Future<List<VocabularyEntryView>> listForDocument(String documentId) async {
    final rows =
        await (_database.select(_database.vocabularyEntries)
              ..where((entry) => entry.documentId.equals(documentId))
              ..orderBy([(entry) => OrderingTerm.asc(entry.expressionKey)]))
            .get();

    return rows.map(_toView).toList(growable: false);
  }

  @override
  Future<int> countForDocument(String documentId) async {
    final count = _database.vocabularyEntries.id.count();
    final row =
        await (_database.selectOnly(_database.vocabularyEntries)
              ..addColumns([count])
              ..where(
                _database.vocabularyEntries.documentId.equals(documentId),
              ))
            .getSingle();

    return row.read(count) ?? 0;
  }

  @override
  Future<void> delete(String entryId) {
    return (_database.delete(
      _database.vocabularyEntries,
    )..where((entry) => entry.id.equals(entryId))).go();
  }

  @override
  Future<VocabularyEntryView> updateUserMeaningAndMemo({
    required String entryId,
    required String? userMeaning,
    required String? userMemo,
  }) async {
    await (_database.update(
      _database.vocabularyEntries,
    )..where((entry) => entry.id.equals(entryId))).write(
      VocabularyEntriesCompanion(
        userMeaning: Value(userMeaning),
        userMemo: Value(userMemo),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    return _findById(entryId);
  }

  Future<VocabularyEntryView> _findById(String id) async {
    final row = await (_database.select(
      _database.vocabularyEntries,
    )..where((entry) => entry.id.equals(id))).getSingle();

    return _toView(row);
  }
}

final class InMemoryVocabularyRepository implements VocabularyRepository {
  final Map<String, VocabularyEntryView> _entries = {};
  var _nextId = 0;

  @override
  Future<VocabularyEntryView> upsert(VocabularyDraft draft) async {
    final expressionKey = normalizeVocabularyExpression(draft.expression);
    if (expressionKey.isEmpty) {
      throw ArgumentError.value(draft.expression, 'expression', 'is empty');
    }

    final existing = _entries.values
        .where(
          (entry) =>
              entry.documentId == draft.documentId &&
              entry.expressionKey == expressionKey,
        )
        .firstOrNull;
    final now = DateTime.now().toUtc();

    if (existing != null) {
      final updated = VocabularyEntryView(
        id: existing.id,
        documentId: existing.documentId,
        expressionKey: existing.expressionKey,
        expression: draft.expression,
        meaningKo: draft.meaningKo,
        sourceSentence: draft.sourceSentence,
        contextBefore: draft.contextBefore,
        contextAfter: draft.contextAfter,
        blockId: draft.blockId,
        textOffset: draft.textOffset,
        userMeaning: draft.userMeaning ?? existing.userMeaning,
        userMemo: draft.userMemo ?? existing.userMemo,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _entries[updated.id] = updated;
      return updated;
    }

    final entry = VocabularyEntryView(
      id: 'vocab-${++_nextId}',
      documentId: draft.documentId,
      expressionKey: expressionKey,
      expression: draft.expression,
      meaningKo: draft.meaningKo,
      sourceSentence: draft.sourceSentence,
      contextBefore: draft.contextBefore,
      contextAfter: draft.contextAfter,
      blockId: draft.blockId,
      textOffset: draft.textOffset,
      userMeaning: draft.userMeaning,
      userMemo: draft.userMemo,
      createdAt: now,
      updatedAt: now,
    );
    _entries[entry.id] = entry;
    return entry;
  }

  @override
  Future<List<VocabularyEntryView>> listForDocument(String documentId) async {
    final entries =
        _entries.values
            .where((entry) => entry.documentId == documentId)
            .toList()
          ..sort((a, b) => a.expressionKey.compareTo(b.expressionKey));
    return List.unmodifiable(entries);
  }

  @override
  Future<int> countForDocument(String documentId) async {
    return _entries.values
        .where((entry) => entry.documentId == documentId)
        .length;
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.remove(entryId);
  }

  @override
  Future<VocabularyEntryView> updateUserMeaningAndMemo({
    required String entryId,
    required String? userMeaning,
    required String? userMemo,
  }) async {
    final existing = _entries[entryId];
    if (existing == null) {
      throw StateError('Vocabulary entry not found: $entryId');
    }

    final updated = VocabularyEntryView(
      id: existing.id,
      documentId: existing.documentId,
      expressionKey: existing.expressionKey,
      expression: existing.expression,
      meaningKo: existing.meaningKo,
      sourceSentence: existing.sourceSentence,
      contextBefore: existing.contextBefore,
      contextAfter: existing.contextAfter,
      blockId: existing.blockId,
      textOffset: existing.textOffset,
      userMeaning: userMeaning,
      userMemo: userMemo,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    _entries[entryId] = updated;
    return updated;
  }
}

VocabularyEntryView _toView(VocabularyEntry entry) {
  return VocabularyEntryView(
    id: entry.id,
    documentId: entry.documentId,
    expressionKey: entry.expressionKey,
    expression: entry.expression,
    meaningKo: entry.meaningKo,
    sourceSentence: entry.sourceSentence,
    contextBefore: entry.contextBefore,
    contextAfter: entry.contextAfter,
    blockId: entry.blockId,
    textOffset: entry.textOffset,
    userMeaning: entry.userMeaning,
    userMemo: entry.userMemo,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
  );
}
