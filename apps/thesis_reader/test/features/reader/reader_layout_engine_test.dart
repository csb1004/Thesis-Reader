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

    const viewport = ReaderViewport(width: 360, height: 640);

    final normal = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.0),
      viewport,
    );
    final large = ReaderLayoutEngine.paginate(
      package,
      const ReaderSettings(fontScale: 1.6),
      viewport,
    );

    expect(normal.orderedBlockIds, ['b1', 'b2']);
    expect(large.orderedBlockIds, ['b1', 'b2']);
    expect(normal.pages.length, isNot(large.pages.length));
  });
}
