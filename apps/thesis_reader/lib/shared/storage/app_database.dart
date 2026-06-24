import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class LibraryFolders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get sourceFilename => text()();
  TextColumn get localPdfPath => text()();
  TextColumn get packagePath => text().nullable()();
  TextColumn get folderId =>
      text().nullable().references(LibraryFolders, #id)();
  TextColumn get status => text()();
  TextColumn get lastReadBlockId => text().nullable()();
  IntColumn get lastReadOffset => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VocabularyEntries extends Table {
  TextColumn get id => text()();
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get expressionKey => text()();
  TextColumn get expression => text()();
  TextColumn get meaningKo => text().nullable()();
  TextColumn get sourceSentence => text().nullable()();
  TextColumn get contextBefore => text().nullable()();
  TextColumn get contextAfter => text().nullable()();
  TextColumn get blockId => text().nullable()();
  IntColumn get textOffset => integer().nullable()();
  TextColumn get userMeaning => text().nullable()();
  TextColumn get userMemo => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {documentId, expressionKey},
  ];
}

class ViewerSettings extends Table {
  TextColumn get documentId => text()();
  TextColumn get readingMode => text()();
  TextColumn get themeId => text()();
  TextColumn get fontFamily => text().nullable()();
  RealColumn get fontScale => real()();
  RealColumn get lineHeight => real()();
  RealColumn get marginScale => real()();
  RealColumn get bottomMarginScale => real().withDefault(const Constant(1.0))();
  TextColumn get assetOpenMode => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId};
}

@DriftDatabase(
  tables: [LibraryFolders, Documents, VocabularyEntries, ViewerSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'thesis_reader'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(libraryFolders);
        await m.addColumn(documents, documents.folderId);
      }
      if (from < 3) {
        await m.addColumn(viewerSettings, viewerSettings.bottomMarginScale);
      }
      if (from < 4) {
        await customStatement('PRAGMA foreign_keys = OFF');
        await customStatement('''
CREATE TABLE IF NOT EXISTS viewer_settings_new (
  document_id TEXT NOT NULL PRIMARY KEY,
  reading_mode TEXT NOT NULL,
  theme_id TEXT NOT NULL,
  font_family TEXT NULL,
  font_scale REAL NOT NULL,
  line_height REAL NOT NULL,
  margin_scale REAL NOT NULL,
  bottom_margin_scale REAL NOT NULL DEFAULT 1.0,
  asset_open_mode TEXT NOT NULL
)
''');
        await customStatement('''
INSERT OR REPLACE INTO viewer_settings_new (
  document_id,
  reading_mode,
  theme_id,
  font_family,
  font_scale,
  line_height,
  margin_scale,
  bottom_margin_scale,
  asset_open_mode
)
SELECT
  document_id,
  reading_mode,
  theme_id,
  font_family,
  font_scale,
  line_height,
  margin_scale,
  bottom_margin_scale,
  asset_open_mode
FROM viewer_settings
''');
        await customStatement('DROP TABLE viewer_settings');
        await customStatement(
          'ALTER TABLE viewer_settings_new RENAME TO viewer_settings',
        );
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
