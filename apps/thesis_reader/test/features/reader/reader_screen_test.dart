import 'package:document_contract/document_contract.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';

void main() {
  testWidgets('renders text blocks as selectable text with theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(['Selectable thesis text']),
          initialSettings: const ReaderSettings(themeId: 'dark'),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final theme = ReaderThemeCatalog.resolve('dark');

    expect(selectable.data, 'Selectable thesis text');
    expect(selectable.style?.color, theme.textColor);
    expect(
      tester
          .widget<ColoredBox>(find.byKey(const Key('reader-theme-background')))
          .color,
      theme.backgroundColor,
    );
  });

  testWidgets('reports scroll progress after scroll end', (tester) async {
    final progressChanges = <ReaderProgress>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _packageWithBlocks(
            List.generate(
              30,
              (index) =>
                  'Paragraph $index has enough text to require a scrollable '
                  'reader surface for progress reporting.',
            ),
          ),
          initialSettings: const ReaderSettings(
            readingMode: ReadingMode.scroll,
          ),
          onProgressChanged: progressChanges.add,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    await gesture.moveBy(const Offset(0, -300));
    await tester.pump();

    expect(progressChanges, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(progressChanges, hasLength(1));
    expect(progressChanges.single.scrollOffset, greaterThan(0));
    expect(progressChanges.single.scrollProgress, greaterThan(0));
    expect(progressChanges.single.scrollProgress, lessThanOrEqualTo(1));
  });

  testWidgets('renders valid asset references as clickable styled spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: _package()),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final rootSpan = selectable.textSpan!;
    final referenceSpan = rootSpan.children!.whereType<TextSpan>().singleWhere(
      (span) => span.text == 'Figure 1',
    );

    expect(referenceSpan.recognizer, isNotNull);
    expect(referenceSpan.style?.decoration, TextDecoration.underline);
    expect(referenceSpan.style?.color, isNotNull);
  });

  testWidgets('opens referenced asset in a bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(documentId: 'doc-1', package: _package()),
      ),
    );

    _referenceTapRecognizer(tester).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-asset-bottom-sheet')), findsOneWidget);
    expect(find.text('Figure 1'), findsWidgets);
    expect(find.text('Architecture diagram'), findsOneWidget);
    expect(find.text('assets/figures/figure-1.png'), findsOneWidget);
  });

  testWidgets('opens referenced asset in fullscreen mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _package(),
          initialSettings: const ReaderSettings(
            assetOpenMode: AssetOpenMode.fullScreen,
          ),
        ),
      ),
    );

    _referenceTapRecognizer(tester).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-asset-fullscreen')), findsOneWidget);
    expect(find.text('Figure 1'), findsWidgets);
    expect(find.text('figure'), findsOneWidget);
  });

  testWidgets('ignores invalid and missing-target reference spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          documentId: 'doc-1',
          package: _package(
            referenceSpans: const [
              ReferenceSpan(
                start: 34,
                end: 42,
                targetAssetId: 'missing',
                kind: ReferenceKind.figure,
              ),
              ReferenceSpan(
                start: 90,
                end: 100,
                targetAssetId: 'figure-1',
                kind: ReferenceKind.figure,
              ),
            ],
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(selectable.data, _referenceText);
    expect(selectable.textSpan, isNull);
  });
}

DocumentPackage _packageWithBlocks(List<String> texts) {
  final blockIds = [
    for (var index = 0; index < texts.length; index++) 'b$index',
  ];

  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: [DocumentSection(id: 's1', title: 'Body', blockIds: blockIds)],
    blocks: [
      for (var index = 0; index < texts.length; index++)
        DocumentBlock.paragraph(
          id: blockIds[index],
          sectionId: 's1',
          text: texts[index],
        ),
    ],
    assets: const [],
  );
}

const _referenceText = 'This paragraph cites Figure 1 in context.';

TapGestureRecognizer _referenceTapRecognizer(WidgetTester tester) {
  return tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .children!
          .whereType<TextSpan>()
          .singleWhere((span) => span.text == 'Figure 1')
          .recognizer!
      as TapGestureRecognizer;
}

DocumentPackage _package({List<ReferenceSpan>? referenceSpans}) {
  return DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: const DocumentMetadata(
      title: 'Reader Test',
      sourceFilename: 'reader.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: const [
      DocumentSection(id: 's1', title: 'Body', blockIds: ['b1']),
    ],
    blocks: [
      DocumentBlock.paragraph(
        id: 'b1',
        sectionId: 's1',
        text: _referenceText,
        referenceSpans:
            referenceSpans ??
            const [
              ReferenceSpan(
                start: 21,
                end: 29,
                targetAssetId: 'figure-1',
                kind: ReferenceKind.figure,
              ),
            ],
      ),
    ],
    assets: const [
      DocumentAsset(
        id: 'figure-1',
        kind: AssetKind.figure,
        label: 'Figure 1',
        relativePath: 'assets/figures/figure-1.png',
        caption: 'Architecture diagram',
      ),
    ],
  );
}
