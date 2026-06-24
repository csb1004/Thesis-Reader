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

    expect(find.text('No vocabulary yet'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Edit vocabulary note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Your meaning'),
      '내 뜻',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Memo'),
      'review later',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('내 뜻'), findsOneWidget);
    expect(find.text('review later'), findsOneWidget);
  });
}
