import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get sourceFilename => text()();
  TextColumn get localPdfPath => text()();
  TextColumn get packagePath => text().nullable()();
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
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get readingMode => text()();
  TextColumn get themeId => text()();
  TextColumn get fontFamily => text().nullable()();
  RealColumn get fontScale => real()();
  RealColumn get lineHeight => real()();
  RealColumn get marginScale => real()();
  TextColumn get assetOpenMode => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId};
}

@DriftDatabase(tables: [Documents, VocabularyEntries, ViewerSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'thesis_reader'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
