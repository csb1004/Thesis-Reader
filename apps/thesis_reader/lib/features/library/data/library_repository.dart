import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/storage/app_database.dart';

class LibraryDocumentView {
  const LibraryDocumentView({
    required this.id,
    required this.title,
    required this.sourceFilename,
    required this.localPdfPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.packagePath,
    this.folderId,
  });

  final String id;
  final String title;
  final String sourceFilename;
  final String localPdfPath;
  final String? packagePath;
  final String? folderId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LibraryDocumentView.fromDocument(Document document) {
    return LibraryDocumentView(
      id: document.id,
      title: document.title,
      sourceFilename: document.sourceFilename,
      localPdfPath: document.localPdfPath,
      packagePath: document.packagePath,
      folderId: document.folderId,
      status: document.status,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );
  }
}

abstract interface class LibraryRepository {
  Future<List<LibraryFolder>> listFolders();
  Future<List<LibraryDocumentView>> listDocuments();
  Future<LibraryFolder> createFolder(String name);
  Future<void> renameFolder({required String folderId, required String name});
  Future<void> deleteFolder(String folderId);
  Future<void> renameDocument({
    required String documentId,
    required String title,
  });
  Future<void> moveDocument({required String documentId, String? folderId});
  Future<void> deleteDocument(String documentId);
}

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<List<LibraryFolder>> listFolders() {
    return (_database.select(
      _database.libraryFolders,
    )..orderBy([(folder) => OrderingTerm.asc(folder.name)])).get();
  }

  @override
  Future<List<LibraryDocumentView>> listDocuments() async {
    final documents =
        await (_database.select(_database.documents)..orderBy([
              (document) => OrderingTerm.desc(document.updatedAt),
              (document) => OrderingTerm.asc(document.title),
            ]))
            .get();
    return documents.map(LibraryDocumentView.fromDocument).toList();
  }

  @override
  Future<LibraryFolder> createFolder(String name) async {
    final trimmedName = _normalizeName(name);
    final now = DateTime.now().toUtc();
    final folder = LibraryFoldersCompanion.insert(
      id: _uuid.v4(),
      name: trimmedName,
      createdAt: now,
      updatedAt: now,
    );
    await _database.into(_database.libraryFolders).insert(folder);
    final folderId = folder.id.value;
    return (_database.select(
      _database.libraryFolders,
    )..where((row) => row.id.equals(folderId))).getSingle();
  }

  @override
  Future<void> renameFolder({
    required String folderId,
    required String name,
  }) async {
    await (_database.update(
      _database.libraryFolders,
    )..where((folder) => folder.id.equals(folderId))).write(
      LibraryFoldersCompanion(
        name: Value(_normalizeName(name)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await _database.transaction(() async {
      await (_database.update(_database.documents)
            ..where((document) => document.folderId.equals(folderId)))
          .write(const DocumentsCompanion(folderId: Value(null)));
      await (_database.delete(
        _database.libraryFolders,
      )..where((folder) => folder.id.equals(folderId))).go();
    });
  }

  @override
  Future<void> renameDocument({
    required String documentId,
    required String title,
  }) async {
    await (_database.update(
      _database.documents,
    )..where((document) => document.id.equals(documentId))).write(
      DocumentsCompanion(
        title: Value(_normalizeName(title)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> moveDocument({
    required String documentId,
    String? folderId,
  }) async {
    await (_database.update(
      _database.documents,
    )..where((document) => document.id.equals(documentId))).write(
      DocumentsCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.vocabularyEntries,
      )..where((entry) => entry.documentId.equals(documentId))).go();
      await (_database.delete(
        _database.viewerSettings,
      )..where((settings) => settings.documentId.equals(documentId))).go();
      await (_database.delete(
        _database.documents,
      )..where((document) => document.id.equals(documentId))).go();
    });
  }

  String _normalizeName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name must not be empty.');
    }
    return normalized;
  }
}
