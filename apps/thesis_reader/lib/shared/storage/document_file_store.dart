import 'dart:io';

import 'package:path/path.dart' as p;

class DocumentFileStore {
  DocumentFileStore({required Directory rootDirectory})
    : _rootDirectory = rootDirectory;

  static final RegExp _safeDocumentIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final Directory _rootDirectory;

  Future<File> copyPdfIntoDocumentDirectory({
    required String documentId,
    required File sourcePdf,
  }) async {
    _validateDocumentId(documentId);

    final documentDirectory = _documentDirectory(documentId);
    await documentDirectory.create(recursive: true);

    final extension = _safePdfExtension(sourcePdf.path);
    final target = File(p.join(documentDirectory.path, 'source$extension'));
    return sourcePdf.copy(target.path);
  }

  Future<void> deleteDocumentFiles(String documentId) async {
    _validateDocumentId(documentId);

    final documentDirectory = _documentDirectory(documentId);
    final rootPath = p.canonicalize(_rootDirectory.path);
    final documentPath = p.canonicalize(documentDirectory.path);

    if (!p.isWithin(rootPath, documentPath)) {
      throw StateError('Refusing to delete files outside the app directory.');
    }
    if (await documentDirectory.exists()) {
      await documentDirectory.delete(recursive: true);
    }
  }

  Directory _documentDirectory(String documentId) {
    return Directory(p.join(_rootDirectory.path, 'documents', documentId));
  }

  String _safePdfExtension(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return extension == '.pdf' ? extension : '.pdf';
  }

  void _validateDocumentId(String documentId) {
    if (!_safeDocumentIdPattern.hasMatch(documentId)) {
      throw ArgumentError.value(
        documentId,
        'documentId',
        'must contain only letters, numbers, underscores, or hyphens',
      );
    }
  }
}
