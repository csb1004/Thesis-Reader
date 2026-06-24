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
      bottomMarginScale: 1.6,
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
    expect(loaded.bottomMarginScale, expected.bottomMarginScale);
    expect(loaded.readingMode, expected.readingMode);
    expect(loaded.assetOpenMode, expected.assetOpenMode);
  });

  test('uses shared defaults when a document has no saved settings', () async {
    const defaults = ReaderSettings(
      themeId: 'dark',
      fontFamily: 'serif',
      fontScale: 1.25,
      lineHeight: 1.7,
      marginScale: 1.1,
      bottomMarginScale: 1.4,
      readingMode: ReadingMode.scroll,
      assetOpenMode: AssetOpenMode.fullScreen,
    );

    await repository.saveDefaults(defaults);

    final loaded = await repository.load('doc-1');

    expect(loaded.themeId, defaults.themeId);
    expect(loaded.fontFamily, defaults.fontFamily);
    expect(loaded.fontScale, defaults.fontScale);
    expect(loaded.lineHeight, defaults.lineHeight);
    expect(loaded.marginScale, defaults.marginScale);
    expect(loaded.bottomMarginScale, defaults.bottomMarginScale);
    expect(loaded.readingMode, defaults.readingMode);
    expect(loaded.assetOpenMode, defaults.assetOpenMode);
  });

  test('document settings override shared defaults', () async {
    await repository.saveDefaults(const ReaderSettings(themeId: 'dark'));
    await repository.save(
      documentId: 'doc-1',
      settings: const ReaderSettings(themeId: 'white'),
    );

    final loaded = await repository.load('doc-1');

    expect(loaded.themeId, 'white');
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
