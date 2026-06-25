import 'package:document_contract/document_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/domain/reader_layout_engine.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';

void main() {
  test('setting changes alter page count without changing block order', () {
    const package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: DocumentMetadata(
        title: 'Reader Test',
        sourceFilename: 'reader.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: [
        DocumentSection(id: 's1', title: 'Abstract', blockIds: ['b1', 'b2']),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'b1',
          sectionId: 's1',
          text:
              'This first paragraph is intentionally long enough to exercise '
              'the approximate reader layout engine across multiple lines. '
              'Dense mobile reading needs deterministic pagination while '
              'preserving the original package order. '
              'This first paragraph is intentionally long enough to exercise '
              'the approximate reader layout engine across multiple lines. '
              'Dense mobile reading needs deterministic pagination while '
              'preserving the original package order. '
              'This first paragraph is intentionally long enough to exercise '
              'the approximate reader layout engine across multiple lines.',
        ),
        DocumentBlock.paragraph(
          id: 'b2',
          sectionId: 's1',
          text:
              'The second paragraph must remain after the first paragraph even '
              'when settings change the pagination calculation. '
              'Reader settings can alter estimated page boundaries without '
              'reordering the document blocks. '
              'The second paragraph must remain after the first paragraph even '
              'when settings change the pagination calculation. '
              'Reader settings can alter estimated page boundaries without '
              'reordering the document blocks. '
              'The second paragraph must remain after the first paragraph even '
              'when settings change the pagination calculation.',
        ),
      ],
      assets: [],
    );

    const viewport = ReaderViewport(width: 320, height: 360);

    final normal = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0),
      viewport,
    );
    final large = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 2.4),
      viewport,
    );

    expect(normal.orderedBlockIds, ['b1', 'b2']);
    expect(large.orderedBlockIds, ['b1', 'b2']);
    expect(large.charsPerLine, lessThan(normal.charsPerLine));
    expect(large.linesPerPage, lessThan(normal.linesPerPage));
  });

  test('page mode reserves user configured bottom margin', () {
    const package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: DocumentMetadata(
        title: 'Reader Test',
        sourceFilename: 'reader.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: [
        DocumentSection(id: 's1', title: 'Abstract', blockIds: ['b1']),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'b1',
          sectionId: 's1',
          text: 'A short paragraph for layout.',
        ),
      ],
      assets: [],
    );

    final compact = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(
        fontScale: 1.0,
        lineHeight: 1.5,
        bottomMarginScale: 0.5,
      ),
      const ReaderViewport(width: 320, height: 640),
    );
    final spacious = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(
        fontScale: 1.0,
        lineHeight: 1.5,
        bottomMarginScale: 2.0,
      ),
      const ReaderViewport(width: 320, height: 640),
    );

    expect(compact.linesPerPage, greaterThan(spacious.linesPerPage));
    expect(spacious.linesPerPage, lessThanOrEqualTo(21));
  });

  test('page mode reserves fixed top and bottom safe reading space', () {
    const package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: DocumentMetadata(
        title: 'Reader Test',
        sourceFilename: 'reader.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: [
        DocumentSection(id: 's1', title: 'Abstract', blockIds: ['b1']),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'b1',
          sectionId: 's1',
          text: 'A short paragraph for layout.',
        ),
      ],
      assets: [],
    );

    final full = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0, lineHeight: 1.5),
      const ReaderViewport(width: 360, height: 720),
    );
    final reserved = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0, lineHeight: 1.5),
      const ReaderViewport(
        width: 360,
        height: 720,
        topReserve: 88,
        bottomReserve: 24,
      ),
    );

    expect(reserved.linesPerPage, lessThan(full.linesPerPage));
  });

  test(
    'keeps section headings with following body instead of orphaning them',
    () {
      final package = DocumentPackage(
        packageVersion: 1,
        documentId: 'doc-1',
        metadata: const DocumentMetadata(
          title: 'Reader Test',
          sourceFilename: 'reader.pdf',
          originalPdfSha256: 'abc123',
        ),
        sections: const [
          DocumentSection(
            id: 's1',
            title: 'Body',
            blockIds: ['body', 'number', 'heading', 'next'],
          ),
        ],
        blocks: [
          DocumentBlock.paragraph(
            id: 'body',
            sectionId: 's1',
            text: 'Almost fills the first page. ${'body text ' * 250}',
          ),
          const DocumentBlock.paragraph(
            id: 'number',
            sectionId: 's1',
            text: '2',
          ),
          const DocumentBlock.paragraph(
            id: 'heading',
            sectionId: 's1',
            text: 'Background',
          ),
          DocumentBlock.paragraph(
            id: 'next',
            sectionId: 's1',
            text:
                'The next section body should travel with the heading. '
                '${'background text ' * 220}',
          ),
        ],
        assets: const [],
      );

      final layout = ReaderLayoutEngine.paginate(
        package,
        const ReaderSettings(fontScale: 1.2, lineHeight: 1.5),
        const ReaderViewport(width: 360, height: 640),
      );

      expect(
        layout.pages.any(
          (page) =>
              page.blockIds.contains('heading') &&
              page.blockIds.contains('next'),
        ),
        isTrue,
      );
    },
  );

  test('moves heading to next page when only the heading fits at bottom', () {
    final package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: const DocumentMetadata(
        title: 'Reader Test',
        sourceFilename: 'reader.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: const [
        DocumentSection(
          id: 's1',
          title: 'Body',
          blockIds: ['body', 'heading', 'next'],
        ),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'body',
          sectionId: 's1',
          text:
              'This opening paragraph leaves just enough space for a short '
              'heading but not enough space for the first lines of the next '
              'section body. ${'filler text ' * 5}',
        ),
        const DocumentBlock.paragraph(
          id: 'heading',
          sectionId: 's1',
          text: 'Decoder',
        ),
        DocumentBlock.paragraph(
          id: 'next',
          sectionId: 's1',
          text:
              'The decoder body should stay visually attached to its '
              'section title instead of starting on a separate page.',
        ),
      ],
      assets: const [],
    );

    final layout = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0, lineHeight: 1.5),
      const ReaderViewport(width: 360, height: 360),
    );

    expect(layout.pages[0].blockIds, ['body']);
    expect(layout.pages[1].blockIds, containsAllInOrder(['heading', 'next']));
    expect(
      layout.pages.every(
        (page) => page.estimatedLineCount <= layout.linesPerPage,
      ),
      isTrue,
    );
  });

  test('splits long paragraphs across pages to keep pages filled', () {
    final package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: const DocumentMetadata(
        title: 'Reader Test',
        sourceFilename: 'reader.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: const [
        DocumentSection(id: 's1', title: 'Body', blockIds: ['long']),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'long',
          sectionId: 's1',
          text: List.generate(120, (index) => 'word$index').join(' '),
        ),
      ],
      assets: const [],
    );

    final layout = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0, lineHeight: 1.5),
      const ReaderViewport(width: 360, height: 360),
    );

    expect(layout.pages.length, greaterThan(1));
    expect(layout.pages.first.blockIds, ['long']);
    expect(layout.pages.first.items.single.blockId, 'long');
    expect(layout.pages.first.items.single.text, isNotNull);
    expect(layout.pages.first.items.single.text, isNot(contains('word119')));
    expect(layout.pages.last.items.single.text, contains('word119'));
    expect(
      layout.pages.every(
        (page) => page.estimatedLineCount <= layout.linesPerPage,
      ),
      isTrue,
    );
  });
}
