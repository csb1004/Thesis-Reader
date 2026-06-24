import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/document_repository.dart';
import 'package:thesis_reader/shared/storage/document_file_store.dart';

void main() {
  test('imported pdf is copied and registered', () async {
    final temp = await Directory.systemTemp.createTemp('thesis_reader_test');
    final source = File('${temp.path}/paper.pdf');
    await source.writeAsBytes([37, 80, 68, 70]);

    final store = DocumentFileStore(rootDirectory: temp);
    final repo = InMemoryDocumentRepository(fileStore: store);

    final document = await repo.importPdf(source);

    expect(document.id, isNotEmpty);
    expect(document.sourceFilename, 'paper.pdf');
    expect(await File(document.localPdfPath).exists(), isTrue);
  });
}
