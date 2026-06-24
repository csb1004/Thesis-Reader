import 'package:flutter_test/flutter_test.dart';

import 'package:document_contract/document_contract.dart';

void main() {
  test('exports document package contract types', () {
    const metadata = DocumentMetadata(
      title: 'Title',
      sourceFilename: 'paper.pdf',
      originalPdfSha256: 'sha',
    );

    expect(metadata.toJson()['sourceFilename'], 'paper.pdf');
  });
}
