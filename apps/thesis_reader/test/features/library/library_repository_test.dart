import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/library_repository.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftLibraryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates folders and lists them by name', () async {
    await repository.createFolder('Transformer');
    await repository.createFolder(' Medical AI ');

    final folders = await repository.listFolders();

    expect(folders.map((folder) => folder.name), ['Medical AI', 'Transformer']);
  });

  test('renames and moves a document', () async {
    final now = DateTime.utc(2026);
    await database
        .into(database.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'doc-1',
            title: 'paper.pdf',
            sourceFilename: 'paper.pdf',
            localPdfPath: '/tmp/paper.pdf',
            status: 'converted',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final folder = await repository.createFolder('Transformer');

    await repository.renameDocument(documentId: 'doc-1', title: 'Attention');
    await repository.moveDocument(documentId: 'doc-1', folderId: folder.id);

    final documents = await repository.listDocuments();

    expect(documents.single.title, 'Attention');
    expect(documents.single.folderId, folder.id);
  });
}
