import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thesis_reader/shared/storage/document_file_store.dart';
import 'package:uuid/uuid.dart';

abstract interface class DocumentRepository {
  Future<DocumentRecord> importPdf(File source);
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.sourceFilename,
    required this.localPdfPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceFilename;
  final String localPdfPath;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InMemoryDocumentRepository implements DocumentRepository {
  InMemoryDocumentRepository({required DocumentFileStore fileStore, Uuid? uuid})
    : _fileStore = fileStore,
      _uuid = uuid ?? const Uuid();

  final DocumentFileStore _fileStore;
  final Uuid _uuid;
  final Map<String, DocumentRecord> _documents = {};

  List<DocumentRecord> get documents => List.unmodifiable(_documents.values);

  @override
  Future<DocumentRecord> importPdf(File source) async {
    final documentId = _uuid.v4();
    final localPdf = await _fileStore.copyPdfIntoDocumentDirectory(
      documentId: documentId,
      sourcePdf: source,
    );
    final now = DateTime.now().toUtc();
    final document = DocumentRecord(
      id: documentId,
      sourceFilename: p.basename(source.path),
      localPdfPath: localPdf.path,
      status: 'imported',
      createdAt: now,
      updatedAt: now,
    );

    _documents[document.id] = document;
    return document;
  }
}
