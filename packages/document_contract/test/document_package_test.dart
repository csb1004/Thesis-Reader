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

  test('package parses conversion metadata and latex equation blocks', () {
    final package = DocumentPackage.fromJson({
      'packageVersion': 1,
      'documentId': 'doc-1',
      'metadata': {
        'title': 'DDPM',
        'sourceFilename': '2006.11239.pdf',
        'originalPdfSha256': 'abc123',
      },
      'conversionMode': 'latex-source',
      'fallbackReason': null,
      'sourceInfo': {'arxivId': '2006.11239', 'mainTex': 'main.tex'},
      'sections': [
        {
          'id': 'sec-1',
          'title': 'Document',
          'blockIds': ['eq-1'],
        },
      ],
      'blocks': [
        {
          'id': 'eq-1',
          'sectionId': 'sec-1',
          'kind': 'equation',
          'latex': r'q(x_t \mid x_0) = \mathcal{N}(x_t; 0, I)',
          'source': {'mode': 'latex', 'environment': 'equation'},
        },
      ],
      'assets': [],
    });

    expect(package.conversionMode, 'latex-source');
    expect(package.sourceInfo?['arxivId'], '2006.11239');
    expect(package.blocks.single.latex, contains(r'\mathcal'));
    expect(package.blocks.single.source?['environment'], 'equation');
  });

  test('package round trips structured text style spans', () {
    final package = DocumentPackage.fromJson({
      'packageVersion': 1,
      'documentId': 'doc-1',
      'metadata': {
        'title': 'Styled TeX',
        'sourceFilename': 'styled.pdf',
        'originalPdfSha256': 'abc123',
      },
      'sections': [
        {
          'id': 'sec-1',
          'title': 'Document',
          'blockIds': ['b1'],
        },
      ],
      'blocks': [
        {
          'id': 'b1',
          'sectionId': 'sec-1',
          'kind': 'paragraph',
          'text': 'First line\nSecond line with bold and marked.',
          'source': {'mode': 'latex', 'preserveStructure': true},
          'textSpans': [
            {'start': 28, 'end': 32, 'bold': true},
            {'start': 37, 'end': 43, 'highlight': true},
          ],
        },
      ],
      'assets': [],
    });

    final block = package.blocks.single;

    expect(block.text, contains('\n'));
    expect(block.textSpans, hasLength(2));
    expect(block.textSpans.first.bold, isTrue);
    expect(block.textSpans.last.highlight, isTrue);
    expect(block.toJson()['textSpans'], isA<List<Object?>>());
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
