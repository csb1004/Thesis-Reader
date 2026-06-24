import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('foreign key enforcement rejects orphan vocabulary entries', () async {
    await expectLater(
      database.into(database.vocabularyEntries).insert(
            _vocabularyEntry(
              id: 'vocab-1',
              documentId: 'missing-document',
              expressionKey: 'orphan',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('expression keys are unique per document', () async {
    await database.into(database.documents).insert(_document(id: 'document-1'));
    await database.into(database.vocabularyEntries).insert(
          _vocabularyEntry(
            id: 'vocab-1',
            documentId: 'document-1',
            expressionKey: 'same-expression',
          ),
        );

    await expectLater(
      database.into(database.vocabularyEntries).insert(
            _vocabularyEntry(
              id: 'vocab-2',
              documentId: 'document-1',
              expressionKey: 'same-expression',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('expression keys can repeat across different documents', () async {
    await database.into(database.documents).insert(_document(id: 'document-1'));
    await database.into(database.documents).insert(_document(id: 'document-2'));

    await database.into(database.vocabularyEntries).insert(
          _vocabularyEntry(
            id: 'vocab-1',
            documentId: 'document-1',
            expressionKey: 'shared-expression',
          ),
        );
    await database.into(database.vocabularyEntries).insert(
          _vocabularyEntry(
            id: 'vocab-2',
            documentId: 'document-2',
            expressionKey: 'shared-expression',
          ),
        );

    final entries = await database.select(database.vocabularyEntries).get();

    expect(entries, hasLength(2));
  });
}

DocumentsCompanion _document({required String id}) {
  final now = DateTime.utc(2026);

  return DocumentsCompanion.insert(
    id: id,
    title: 'A Paper',
    sourceFilename: 'paper.pdf',
    localPdfPath: '/tmp/paper.pdf',
    status: 'imported',
    createdAt: now,
    updatedAt: now,
  );
}

VocabularyEntriesCompanion _vocabularyEntry({
  required String id,
  required String documentId,
  required String expressionKey,
}) {
  final now = DateTime.utc(2026);

  return VocabularyEntriesCompanion.insert(
    id: id,
    documentId: documentId,
    expressionKey: expressionKey,
    expression: 'expression',
    createdAt: now,
    updatedAt: now,
  );
}
