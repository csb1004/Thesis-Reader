import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';
import 'package:thesis_reader/features/vocabulary/presentation/vocabulary_screen.dart';

void main() {
  testWidgets('shows an empty state for a document with no vocabulary', (
    tester,
  ) async {
    final repository = InMemoryVocabularyRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: VocabularyScreen(documentId: 'doc-1', repository: repository),
      ),
    );
    await tester.pump();

    expect(find.text('아직 단어장이 비어 있습니다'), findsOneWidget);
  });

  testWidgets('lists document vocabulary and edits user fields', (
    tester,
  ) async {
    final repository = InMemoryVocabularyRepository();
    await repository.upsert(
      const VocabularyDraft(
        documentId: 'doc-1',
        expression: 'In Context',
        meaningKo: '문맥 안에서',
        sourceSentence: 'Read this in context.',
        contextBefore: null,
        contextAfter: null,
      ),
    );
    await repository.upsert(
      const VocabularyDraft(
        documentId: 'doc-2',
        expression: 'Hidden',
        meaningKo: '숨김',
        sourceSentence: null,
        contextBefore: null,
        contextAfter: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VocabularyScreen(documentId: 'doc-1', repository: repository),
      ),
    );
    await tester.pump();

    expect(find.text('In Context'), findsOneWidget);
    expect(find.text('문맥 안에서'), findsOneWidget);
    expect(find.text('Read this in context.'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);

    await tester.tap(find.byTooltip('단어 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '내 뜻'), '문맥상 의미');
    await tester.enterText(
      find.widgetWithText(TextField, '메모'),
      'review later',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('문맥상 의미'), findsOneWidget);
    expect(find.text('review later'), findsOneWidget);
  });

  testWidgets('keeps source context compact and opens details on tap', (
    tester,
  ) async {
    const longSource =
        '2023 Abstract Knowledge Representation and Reasoning is a central, '
        'longstanding, and active area of Artificial Intelligence. Over the '
        'years it has evolved significantly and has been challenged by '
        'research in reasoning under uncertainty.';
    final repository = InMemoryVocabularyRepository();
    await repository.upsert(
      const VocabularyDraft(
        documentId: 'doc-1',
        expression: 'Over the years',
        meaningKo: '수년에 걸쳐',
        sourceSentence: longSource,
        contextBefore: 'Previous sentence.',
        contextAfter: 'Next sentence.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VocabularyScreen(documentId: 'doc-1', repository: repository),
      ),
    );
    await tester.pump();

    final preview = tester.widget<Text>(
      find.byKey(const Key('vocabulary-source-preview-text')),
    );
    expect(preview.maxLines, 2);
    expect(preview.overflow, TextOverflow.ellipsis);

    await tester.tap(find.byKey(const Key('vocabulary-source-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vocabulary-context-sheet')), findsOneWidget);
    expect(find.text(longSource), findsWidgets);
    expect(find.text('Previous sentence.'), findsOneWidget);
    expect(find.text('Next sentence.'), findsOneWidget);
  });

  testWidgets('deletes vocabulary entries from the screen', (tester) async {
    final repository = InMemoryVocabularyRepository();
    await repository.upsert(
      const VocabularyDraft(
        documentId: 'doc-1',
        expression: 'Attention',
        meaningKo: '주의',
        sourceSentence: 'Attention matters.',
        contextBefore: null,
        contextAfter: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VocabularyScreen(documentId: 'doc-1', repository: repository),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('단어 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('Attention'), findsNothing);
    expect(find.text('아직 단어장이 비어 있습니다'), findsOneWidget);
  });
}
