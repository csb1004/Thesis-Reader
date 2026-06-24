import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:thesis_reader/features/library/data/document_repository.dart';
import 'package:thesis_reader/shared/storage/document_file_store.dart';

void main() {
  test('imported pdf is copied and registered', () async {
    final sourceBytes = [37, 80, 68, 70];
    final (:source, :temp) = await _createSourcePdf(sourceBytes);

    final store = DocumentFileStore(rootDirectory: temp);
    final repo = InMemoryDocumentRepository(fileStore: store);

    final document = await repo.importPdf(source);
    final copiedFile = File(document.localPdfPath);
    final documentDirectory = p.join(temp.path, 'documents', document.id);

    expect(document.id, isNotEmpty);
    expect(document.sourceFilename, 'paper.pdf');
    expect(repo.documents, contains(document));
    expect(p.isWithin(documentDirectory, copiedFile.path), isTrue);
    expect(await copiedFile.exists(), isTrue);
    expect(await copiedFile.readAsBytes(), sourceBytes);
  });

  group('DocumentFileStore', () {
    test('rejects parent directory document ids', () async {
      final (:source, :temp) = await _createSourcePdf();
      final store = DocumentFileStore(rootDirectory: temp);

      await expectLater(
        store.copyPdfIntoDocumentDirectory(
          documentId: '../escape',
          sourcePdf: source,
        ),
        throwsArgumentError,
      );
    });

    test('rejects document ids containing path separators', () async {
      final (:source, :temp) = await _createSourcePdf();
      final store = DocumentFileStore(rootDirectory: temp);

      await expectLater(
        store.copyPdfIntoDocumentDirectory(
          documentId: 'nested/escape',
          sourcePdf: source,
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.copyPdfIntoDocumentDirectory(
          documentId: r'nested\escape',
          sourcePdf: source,
        ),
        throwsArgumentError,
      );
    });
  });
}

Future<({File source, Directory temp})> _createSourcePdf([
  List<int> bytes = const [37, 80, 68, 70],
]) async {
  final temp = await Directory.systemTemp.createTemp('thesis_reader_test');
  final source = File('${temp.path}/paper.pdf');
  await source.writeAsBytes(bytes);

  return (source: source, temp: temp);
}
