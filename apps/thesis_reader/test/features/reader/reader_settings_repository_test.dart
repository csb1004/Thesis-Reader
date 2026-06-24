import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/reader/data/reader_settings_repository.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';

void main() {
  late AppDatabase database;
  late ReaderSettingsRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftReaderSettingsRepository(database);
    await database.into(database.documents).insert(_document(id: 'doc-1'));
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'returns default settings when a document has no saved settings',
    () async {
      final settings = await repository.load('doc-1');

      expect(settings.themeId, const ReaderSettings().themeId);
      expect(settings.readingMode, ReadingMode.page);
    },
  );

  test('persists every reader setting for a document', () async {
    const expected = ReaderSettings(
      themeId: 'white',
      fontFamily: 'serif',
      fontScale: 1.35,
      lineHeight: 1.8,
      marginScale: 1.2,
      readingMode: ReadingMode.scroll,
      assetOpenMode: AssetOpenMode.fullScreen,
    );

    await repository.save(documentId: 'doc-1', settings: expected);

    final loaded = await repository.load('doc-1');

    expect(loaded.themeId, expected.themeId);
    expect(loaded.fontFamily, expected.fontFamily);
    expect(loaded.fontScale, expected.fontScale);
    expect(loaded.lineHeight, expected.lineHeight);
    expect(loaded.marginScale, expected.marginScale);
    expect(loaded.readingMode, expected.readingMode);
    expect(loaded.assetOpenMode, expected.assetOpenMode);
  });
}

DocumentsCompanion _document({required String id}) {
  final now = DateTime.utc(2026);

  return DocumentsCompanion.insert(
    id: id,
    title: 'A Paper',
    sourceFilename: '$id.pdf',
    localPdfPath: '/tmp/$id.pdf',
    status: 'imported',
    createdAt: now,
    updatedAt: now,
  );
}
