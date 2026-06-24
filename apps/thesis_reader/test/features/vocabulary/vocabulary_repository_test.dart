import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';

void main() {
  late AppDatabase database;
  late DriftVocabularyRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftVocabularyRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'upsert prevents duplicates within a document by normalized expression',
    () async {
      await database.into(database.documents).insert(_document(id: 'doc-1'));

      final first = await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: '  In Context, ',
          meaningKo: '문맥 안에서',
          sourceSentence: 'Read this in context.',
          contextBefore: 'before',
          contextAfter: 'after',
        ),
      );
      final second = await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: 'in   context',
          meaningKo: '맥락 속에서',
          sourceSentence: 'The phrase appears in context.',
          contextBefore: null,
          contextAfter: null,
          userMemo: 'second save',
        ),
      );

      expect(second.id, first.id);
      expect(second.expressionKey, 'in context');
      expect(second.expression, 'in   context');
      expect(second.meaningKo, '맥락 속에서');
      expect(second.userMemo, 'second save');
      expect(await repository.countForDocument('doc-1'), 1);
    },
  );

  test(
    'same normalized expression can be saved in different documents',
    () async {
      await database.into(database.documents).insert(_document(id: 'doc-1'));
      await database.into(database.documents).insert(_document(id: 'doc-2'));

      await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: 'Attention',
          meaningKo: '주의',
          sourceSentence: null,
          contextBefore: null,
          contextAfter: null,
        ),
      );
      await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-2',
          expression: 'attention.',
          meaningKo: '어텐션',
          sourceSentence: null,
          contextBefore: null,
          contextAfter: null,
        ),
      );

      expect(await repository.countForDocument('doc-1'), 1);
      expect(await repository.countForDocument('doc-2'), 1);
    },
  );

  test(
    'listForDocument returns only entries for the requested document',
    () async {
      await database.into(database.documents).insert(_document(id: 'doc-1'));
      await database.into(database.documents).insert(_document(id: 'doc-2'));

      await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: 'Beta',
          meaningKo: '베타',
          sourceSentence: 'Beta comes second.',
          contextBefore: null,
          contextAfter: null,
        ),
      );
      await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: 'Alpha',
          meaningKo: '알파',
          sourceSentence: 'Alpha comes first.',
          contextBefore: null,
          contextAfter: null,
        ),
      );
      await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-2',
          expression: 'Gamma',
          meaningKo: '감마',
          sourceSentence: null,
          contextBefore: null,
          contextAfter: null,
        ),
      );

      final entries = await repository.listForDocument('doc-1');

      expect(entries.map((entry) => entry.expressionKey), ['alpha', 'beta']);
    },
  );

  test(
    'updateUserMeaningAndMemo edits user fields without changing source fields',
    () async {
      await database.into(database.documents).insert(_document(id: 'doc-1'));
      final entry = await repository.upsert(
        const VocabularyDraft(
          documentId: 'doc-1',
          expression: 'Context',
          meaningKo: '문맥',
          sourceSentence: 'Context matters.',
          contextBefore: 'left',
          contextAfter: 'right',
        ),
      );

      final updated = await repository.updateUserMeaningAndMemo(
        entryId: entry.id,
        userMeaning: '내 뜻',
        userMemo: 'review later',
      );

      expect(updated.userMeaning, '내 뜻');
      expect(updated.userMemo, 'review later');
      expect(updated.meaningKo, '문맥');
      expect(updated.sourceSentence, 'Context matters.');
    },
  );
}

DocumentsCompanion _document({required String id}) {
  final now = DateTime.utc(2026);

  return DocumentsCompanion.insert(
    id: id,
    title: 'A Paper',
    sourceFilename: '$id.pdf',
    localPdfPath: '/tmp/$id.pdf',
    status: 'imported',
    createdAt: now,
    updatedAt: now,
  );
}
