import 'package:drift/drift.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';

abstract interface class ReaderSettingsRepository {
  Future<ReaderSettings> load(String documentId);
  Future<void> saveDefaults(ReaderSettings settings);
  Future<void> save({
    required String documentId,
    required ReaderSettings settings,
  });
}

final class DriftReaderSettingsRepository implements ReaderSettingsRepository {
  const DriftReaderSettingsRepository(this._database);

  static const defaultDocumentId = '__reader_defaults__';

  final AppDatabase _database;

  @override
  Future<ReaderSettings> load(String documentId) async {
    final row = await _loadRow(documentId) ?? await _loadRow(defaultDocumentId);
    if (row == null) {
      return const ReaderSettings();
    }

    return _settingsFromRow(row);
  }

  @override
  Future<void> saveDefaults(ReaderSettings settings) {
    return _save(defaultDocumentId, settings);
  }

  @override
  Future<void> save({
    required String documentId,
    required ReaderSettings settings,
  }) {
    return _save(documentId, settings);
  }

  Future<ViewerSetting?> _loadRow(String documentId) {
    return (_database.select(_database.viewerSettings)
          ..where((settings) => settings.documentId.equals(documentId)))
        .getSingleOrNull();
  }

  ReaderSettings _settingsFromRow(ViewerSetting row) {
    return ReaderSettings(
      themeId: row.themeId,
      fontFamily: row.fontFamily,
      fontScale: row.fontScale,
      lineHeight: row.lineHeight,
      marginScale: row.marginScale,
      bottomMarginScale: row.bottomMarginScale,
      readingMode:
          _enumByName(ReadingMode.values, row.readingMode) ?? ReadingMode.page,
      assetOpenMode:
          _enumByName(AssetOpenMode.values, row.assetOpenMode) ??
          AssetOpenMode.bottomSheet,
    );
  }

  Future<void> _save(String documentId, ReaderSettings settings) {
    return _database
        .into(_database.viewerSettings)
        .insertOnConflictUpdate(
          ViewerSettingsCompanion.insert(
            documentId: documentId,
            readingMode: settings.readingMode.name,
            themeId: settings.themeId,
            fontFamily: Value(settings.fontFamily),
            fontScale: settings.fontScale,
            lineHeight: settings.lineHeight,
            marginScale: settings.marginScale,
            bottomMarginScale: Value(settings.bottomMarginScale),
            assetOpenMode: settings.assetOpenMode.name,
          ),
        );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}
