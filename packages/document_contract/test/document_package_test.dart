import 'package:flutter_test/flutter_test.dart';

import 'package:document_contract/document_contract.dart';

void main() {
  test('minimal package round trips through json', () {
    const package = DocumentPackage(
      packageVersion: 1,
      documentId: 'doc-1',
      metadata: DocumentMetadata(
        title: 'Attention Is All You Need',
        sourceFilename: 'paper.pdf',
        originalPdfSha256: 'abc123',
      ),
      sections: [
        DocumentSection(
          id: 'sec-abstract',
          title: 'Abstract',
          blockIds: ['b1'],
        ),
      ],
      blocks: [
        DocumentBlock.paragraph(
          id: 'b1',
          sectionId: 'sec-abstract',
          text: 'The model architecture is shown in Figure 1.',
          referenceSpans: [
            ReferenceSpan(
              start: 35,
              end: 43,
              targetAssetId: 'fig-1',
              kind: ReferenceKind.figure,
              label: 'Figure 1',
            ),
          ],
        ),
      ],
      assets: [
        DocumentAsset(
          id: 'fig-1',
          kind: AssetKind.figure,
          label: 'Figure 1',
          relativePath: 'assets/fig-1.png',
          caption: 'Model architecture.',
        ),
      ],
    );

    final roundTripped = DocumentPackage.fromJson(package.toJson());

    expect(roundTripped.documentId, 'doc-1');
    expect(roundTripped.blocks.single.text, contains('Figure 1'));
    expect(
      roundTripped.blocks.single.referenceSpans.single.targetAssetId,
      'fig-1',
    );
  });
}
