import 'package:flutter_test/flutter_test.dart';

import 'package:document_contract/document_contract.dart';

void main() {
  Map<String, Object?> minimalPackageJson() => const DocumentPackage(
    packageVersion: 1,
    documentId: 'doc-1',
    metadata: DocumentMetadata(
      title: 'Attention Is All You Need',
      sourceFilename: 'paper.pdf',
      originalPdfSha256: 'abc123',
    ),
    sections: [
      DocumentSection(id: 'sec-abstract', title: 'Abstract', blockIds: ['b1']),
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
  ).toJson();

  test('minimal package round trips through json', () {
    final roundTripped = DocumentPackage.fromJson(minimalPackageJson());

    expect(roundTripped.documentId, 'doc-1');
    expect(roundTripped.blocks.single.text, contains('Figure 1'));
    expect(
      roundTripped.blocks.single.referenceSpans.single.targetAssetId,
      'fig-1',
    );
  });

  test('missing sections throws during json parsing', () {
    final json = minimalPackageJson()..remove('sections');

    expect(() => DocumentPackage.fromJson(json), throwsFormatException);
  });

  test('missing section blockIds throws during json parsing', () {
    final json = minimalPackageJson();
    json['sections'] = [
      {'id': 'sec-abstract', 'title': 'Abstract'},
    ];

    expect(() => DocumentPackage.fromJson(json), throwsFormatException);
  });
}
