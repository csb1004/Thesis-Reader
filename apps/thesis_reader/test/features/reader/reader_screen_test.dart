import 'package:document_contract/document_contract.dart';
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
