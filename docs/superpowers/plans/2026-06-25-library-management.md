# Library Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add folder-based library management, document rename/move/delete, and a main settings screen for OpenAI token and default translation mode.

**Architecture:** Extend Drift with folders and document folder assignment, add small repositories for library metadata and safe file cleanup, then wire those into the existing `_LibraryHomeState`. Keep the reader unchanged except for receiving default translation mode later if needed.

**Tech Stack:** Flutter, Drift, `path_provider`, `path`, `shared_preferences`, `flutter_secure_storage`, existing `OpenAiKeyStore`.

---

## File Structure

- Modify `apps/thesis_reader/lib/shared/storage/app_database.dart`: add `LibraryFolders`, add nullable `folderId` to `Documents`, schema migration.
- Regenerate `apps/thesis_reader/lib/shared/storage/app_database.g.dart` with build runner.
- Create `apps/thesis_reader/lib/features/library/data/library_repository.dart`: folder CRUD plus document rename/move/delete metadata operations.
- Modify `apps/thesis_reader/lib/shared/storage/document_file_store.dart`: safe document/package directory cleanup.
- Modify `apps/thesis_reader/lib/features/library/presentation/library_screen.dart`: two-pane folder UI, overflow actions.
- Create `apps/thesis_reader/lib/features/settings/presentation/app_settings_screen.dart`: OpenAI token and default translation mode settings.
- Modify `apps/thesis_reader/lib/app.dart`: load folders/documents, route callbacks, delete files, open settings.
- Add/modify tests under `apps/thesis_reader/test/features/library`, `apps/thesis_reader/test/features/settings`, and `apps/thesis_reader/test/shared/storage`.

---

### Task 1: Data Model and Repository

**Files:**
- Modify: `apps/thesis_reader/lib/shared/storage/app_database.dart`
- Create: `apps/thesis_reader/lib/features/library/data/library_repository.dart`
- Test: `apps/thesis_reader/test/features/library/library_repository_test.dart`
- Test: `apps/thesis_reader/test/shared/storage/app_database_test.dart`

- [ ] **Step 1: Write failing repository tests**

Create `apps/thesis_reader/test/features/library/library_repository_test.dart`:

```dart
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
    await database.into(database.documents).insert(
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/library/library_repository_test.dart
```

Expected: fails because `library_repository.dart`, `LibraryFolders`, and `folderId` do not exist.

- [ ] **Step 3: Update Drift schema**

In `apps/thesis_reader/lib/shared/storage/app_database.dart`, add:

```dart
class LibraryFolders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Add to `Documents`:

```dart
TextColumn get folderId => text().nullable().references(LibraryFolders, #id)();
```

Change database annotation and version:

```dart
@DriftDatabase(tables: [LibraryFolders, Documents, VocabularyEntries, ViewerSettings])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2;
```

Set migration:

```dart
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.createTable(libraryFolders);
      await m.addColumn(documents, documents.folderId);
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

- [ ] **Step 4: Generate Drift code**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_database.g.dart` updates with `LibraryFolders`.

- [ ] **Step 5: Implement repository**

Create `apps/thesis_reader/lib/features/library/data/library_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';
import 'package:uuid/uuid.dart';

final class LibraryFolderView {
  const LibraryFolderView({required this.id, required this.name});
  final String id;
  final String name;
}

final class LibraryDocumentRecordView {
  const LibraryDocumentRecordView({
    required this.id,
    required this.title,
    required this.sourceFilename,
    required this.localPdfPath,
    required this.packagePath,
    required this.status,
    required this.folderId,
  });

  final String id;
  final String title;
  final String sourceFilename;
  final String localPdfPath;
  final String? packagePath;
  final String status;
  final String? folderId;
}

abstract interface class LibraryRepository {
  Future<LibraryFolderView> createFolder(String name);
  Future<List<LibraryFolderView>> listFolders();
  Future<List<LibraryDocumentRecordView>> listDocuments();
  Future<void> renameDocument({required String documentId, required String title});
  Future<void> moveDocument({required String documentId, required String? folderId});
  Future<void> deleteDocument(String documentId);
}

final class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<LibraryFolderView> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database.into(_database.libraryFolders).insert(
          LibraryFoldersCompanion.insert(
            id: id,
            name: trimmed,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return LibraryFolderView(id: id, name: trimmed);
  }

  @override
  Future<List<LibraryFolderView>> listFolders() async {
    final rows = await (_database.select(_database.libraryFolders)
          ..orderBy([(folder) => OrderingTerm.asc(folder.name)]))
        .get();
    return rows.map((row) => LibraryFolderView(id: row.id, name: row.name)).toList();
  }

  @override
  Future<List<LibraryDocumentRecordView>> listDocuments() async {
    final rows = await (_database.select(_database.documents)
          ..orderBy([(document) => OrderingTerm.desc(document.updatedAt)]))
        .get();
    return rows
        .map(
          (row) => LibraryDocumentRecordView(
            id: row.id,
            title: row.title,
            sourceFilename: row.sourceFilename,
            localPdfPath: row.localPdfPath,
            packagePath: row.packagePath,
            status: row.status,
            folderId: row.folderId,
          ),
        )
        .toList();
  }

  @override
  Future<void> renameDocument({required String documentId, required String title}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    return (_database.update(_database.documents)
          ..where((document) => document.id.equals(documentId)))
        .write(
      DocumentsCompanion(
        title: Value(trimmed),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> moveDocument({required String documentId, required String? folderId}) {
    return (_database.update(_database.documents)
          ..where((document) => document.id.equals(documentId)))
        .write(
      DocumentsCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> deleteDocument(String documentId) {
    return _database.transaction(() async {
      await (_database.delete(_database.vocabularyEntries)
            ..where((entry) => entry.documentId.equals(documentId)))
          .go();
      await (_database.delete(_database.viewerSettings)
            ..where((setting) => setting.documentId.equals(documentId)))
          .go();
      await (_database.delete(_database.documents)
            ..where((document) => document.id.equals(documentId)))
          .go();
    });
  }
}
```

- [ ] **Step 6: Verify tests pass**

Run:

```powershell
flutter test test/features/library/library_repository_test.dart test/shared/storage/app_database_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```powershell
git add apps/thesis_reader/lib/shared/storage/app_database.dart apps/thesis_reader/lib/shared/storage/app_database.g.dart apps/thesis_reader/lib/features/library/data/library_repository.dart apps/thesis_reader/test/features/library/library_repository_test.dart apps/thesis_reader/test/shared/storage/app_database_test.dart
git commit -m "feat(library): add folders and document metadata repository"
```

---

### Task 2: Safe File Cleanup

**Files:**
- Modify: `apps/thesis_reader/lib/shared/storage/document_file_store.dart`
- Test: `apps/thesis_reader/test/features/library/document_repository_test.dart`

- [ ] **Step 1: Write failing cleanup test**

Append to `document_repository_test.dart`:

```dart
test('DocumentFileStore deletes only the selected document directories', () async {
  final root = await Directory.systemTemp.createTemp('thesis-reader-store-test');
  addTearDown(() => root.delete(recursive: true));
  final store = DocumentFileStore(rootDirectory: root);

  final source = File(p.join(root.path, 'paper.pdf'));
  await source.writeAsString('%PDF test');
  await store.copyPdfIntoDocumentDirectory(documentId: 'doc-1', sourcePdf: source);
  await Directory(p.join(root.path, 'packages', 'doc-1')).create(recursive: true);
  await File(p.join(root.path, 'packages', 'doc-1', 'package.json')).writeAsString('{}');
  await Directory(p.join(root.path, 'documents', 'doc-2')).create(recursive: true);

  await store.deleteDocumentFiles(documentId: 'doc-1');

  expect(Directory(p.join(root.path, 'documents', 'doc-1')).existsSync(), isFalse);
  expect(Directory(p.join(root.path, 'packages', 'doc-1')).existsSync(), isFalse);
  expect(Directory(p.join(root.path, 'documents', 'doc-2')).existsSync(), isTrue);
});
```

Add imports if missing:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/features/library/document_repository_test.dart
```

Expected: fails because `deleteDocumentFiles` is missing.

- [ ] **Step 3: Implement safe cleanup**

In `DocumentFileStore`, add:

```dart
Future<void> deleteDocumentFiles({required String documentId}) async {
  _validateDocumentId(documentId);
  await _deleteChildDirectory('documents', documentId);
  await _deleteChildDirectory('packages', documentId);
}

Future<void> _deleteChildDirectory(String parentName, String documentId) async {
  final root = _rootDirectory.resolveSymbolicLinksSync();
  final directory = Directory(p.join(_rootDirectory.path, parentName, documentId));
  if (!directory.existsSync()) {
    return;
  }
  final resolved = directory.resolveSymbolicLinksSync();
  final normalizedRoot = p.normalize(root);
  final normalizedTarget = p.normalize(resolved);
  if (!p.isWithin(normalizedRoot, normalizedTarget)) {
    throw StateError('Refusing to delete outside app storage: $normalizedTarget');
  }
  await directory.delete(recursive: true);
}
```

- [ ] **Step 4: Verify test passes**

Run:

```powershell
flutter test test/features/library/document_repository_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib/shared/storage/document_file_store.dart apps/thesis_reader/test/features/library/document_repository_test.dart
git commit -m "feat(storage): delete managed document files safely"
```

---

### Task 3: Library UI

**Files:**
- Modify: `apps/thesis_reader/lib/features/library/presentation/library_screen.dart`
- Test: `apps/thesis_reader/test/features/library/library_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add tests for folder filtering and actions:

```dart
testWidgets('library shows folder pane and filters selected folder', (tester) async {
  String? selectedFolderId;
  await tester.pumpWidget(
    MaterialApp(
      home: LibraryScreen(
        folders: const [
          LibraryFolderViewModel(id: 'folder-1', name: 'Transformer'),
        ],
        selectedFolderId: 'folder-1',
        documents: const [
          LibraryDocumentViewModel(
            id: 'doc-1',
            title: 'Attention',
            conversionStatus: 'converted',
            lastReadProgress: 0.5,
            folderId: 'folder-1',
          ),
        ],
        onFolderSelected: (folderId) => selectedFolderId = folderId,
      ),
    ),
  );

  expect(find.text('전체'), findsOneWidget);
  expect(find.text('미분류'), findsOneWidget);
  expect(find.text('Transformer'), findsOneWidget);
  expect(find.text('Attention'), findsOneWidget);

  await tester.tap(find.text('전체'));
  expect(selectedFolderId, LibraryScreen.allFolderId);
});

testWidgets('document overflow exposes management actions', (tester) async {
  String? renamed;
  String? moved;
  String? deleted;
  await tester.pumpWidget(
    MaterialApp(
      home: LibraryScreen(
        documents: const [
          LibraryDocumentViewModel(
            id: 'doc-1',
            title: 'Attention',
            conversionStatus: 'converted',
            lastReadProgress: 0.5,
          ),
        ],
        onRenameDocument: (id) => renamed = id,
        onMoveDocument: (id) => moved = id,
        onDeleteDocument: (id) => deleted = id,
      ),
    ),
  );

  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('이름 변경'));
  expect(renamed, 'doc-1');

  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('폴더 이동'));
  expect(moved, 'doc-1');

  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('삭제'));
  expect(deleted, 'doc-1');
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/library/library_screen_test.dart
```

Expected: fails because new view models and callbacks are missing.

- [ ] **Step 3: Implement UI model and callbacks**

Update `LibraryDocumentViewModel` with:

```dart
this.folderId,
final String? folderId;
```

Add:

```dart
class LibraryFolderViewModel {
  const LibraryFolderViewModel({required this.id, required this.name});
  final String id;
  final String name;
}
```

Add `LibraryScreen` constants and callbacks:

```dart
static const allFolderId = '__all__';
static const unfiledFolderId = '__unfiled__';
final List<LibraryFolderViewModel> folders;
final String selectedFolderId;
final ValueChanged<String>? onFolderSelected;
final VoidCallback? onCreateFolder;
final VoidCallback? onSettingsPressed;
final ValueChanged<String>? onRenameDocument;
final ValueChanged<String>? onMoveDocument;
final ValueChanged<String>? onDeleteDocument;
```

- [ ] **Step 4: Implement two-pane layout**

Use `LayoutBuilder`. For width >= 560, render:

```dart
Row(
  children: [
    SizedBox(width: 176, child: _FolderPane(...)),
    const VerticalDivider(width: 1),
    Expanded(child: _DocumentList(...)),
  ],
)
```

For narrow screens, render a `Column` with horizontal folder chips and the document list.

- [ ] **Step 5: Implement document popup menu**

In `_LibraryDocumentRow`, add trailing `PopupMenuButton<String>` with values `rename`, `move`, `delete`, and call the corresponding callback. Keep read progress text in the row trailing area by using a small `Row(mainAxisSize: MainAxisSize.min, children: [...])`.

- [ ] **Step 6: Verify tests pass**

Run:

```powershell
flutter test test/features/library/library_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```powershell
git add apps/thesis_reader/lib/features/library/presentation/library_screen.dart apps/thesis_reader/test/features/library/library_screen_test.dart
git commit -m "feat(library): add folder navigation and document actions"
```

---

### Task 4: Main Settings Screen

**Files:**
- Create: `apps/thesis_reader/lib/features/settings/presentation/app_settings_screen.dart`
- Test: `apps/thesis_reader/test/features/settings/app_settings_screen_test.dart`

- [ ] **Step 1: Write failing settings widget test**

Create `app_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/settings/presentation/app_settings_screen.dart';

void main() {
  testWidgets('settings edits token and translation mode', (tester) async {
    String? savedToken;
    String? clearedToken;
    var selectedMode = TranslationModePreference.simple;

    await tester.pumpWidget(
      MaterialApp(
        home: AppSettingsScreen(
          hasOpenAiToken: false,
          translationMode: selectedMode,
          onSaveOpenAiToken: (token) async => savedToken = token,
          onClearOpenAiToken: () async => clearedToken = 'cleared',
          onTranslationModeChanged: (mode) async => selectedMode = mode,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), ' sk-test ');
    await tester.tap(find.text('저장'));
    expect(savedToken, 'sk-test');

    await tester.tap(find.text('OpenAI 번역'));
    expect(selectedMode, TranslationModePreference.openAi);

    await tester.tap(find.text('토큰 삭제'));
    expect(clearedToken, 'cleared');
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/features/settings/app_settings_screen_test.dart
```

Expected: fails because screen does not exist.

- [ ] **Step 3: Implement settings screen**

Create `app_settings_screen.dart` with:

```dart
import 'package:flutter/material.dart';

enum TranslationModePreference { simple, openAi }

final class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.hasOpenAiToken,
    required this.translationMode,
    required this.onSaveOpenAiToken,
    required this.onClearOpenAiToken,
    required this.onTranslationModeChanged,
  });

  final bool hasOpenAiToken;
  final TranslationModePreference translationMode;
  final Future<void> Function(String token) onSaveOpenAiToken;
  final Future<void> Function() onClearOpenAiToken;
  final Future<void> Function(TranslationModePreference mode) onTranslationModeChanged;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

final class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _tokenController = TextEditingController();
  late var _mode = widget.translationMode;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('OpenAI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(widget.hasOpenAiToken ? '토큰 저장됨' : '저장된 토큰 없음'),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'OpenAI API key'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final token = _tokenController.text.trim();
                  if (token.isEmpty) return;
                  await widget.onSaveOpenAiToken(token);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('저장'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await widget.onClearOpenAiToken();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('토큰 삭제'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('기본 번역 방식', style: Theme.of(context).textTheme.titleMedium),
          RadioListTile<TranslationModePreference>(
            title: const Text('간단 번역'),
            value: TranslationModePreference.simple,
            groupValue: _mode,
            onChanged: _setMode,
          ),
          RadioListTile<TranslationModePreference>(
            title: const Text('OpenAI 번역'),
            value: TranslationModePreference.openAi,
            groupValue: _mode,
            onChanged: _setMode,
          ),
        ],
      ),
    );
  }

  Future<void> _setMode(TranslationModePreference? mode) async {
    if (mode == null) return;
    setState(() => _mode = mode);
    await widget.onTranslationModeChanged(mode);
  }
}
```

- [ ] **Step 4: Verify test passes**

Run:

```powershell
flutter test test/features/settings/app_settings_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/thesis_reader/lib/features/settings/presentation/app_settings_screen.dart apps/thesis_reader/test/features/settings/app_settings_screen_test.dart
git commit -m "feat(settings): add app settings screen"
```

---

### Task 5: App Wiring, Dialogs, and Verification

**Files:**
- Modify: `apps/thesis_reader/lib/app.dart`
- Modify: `apps/thesis_reader/test/features/library/library_screen_test.dart`

- [ ] **Step 1: Wire repositories into `_LibraryHomeState`**

Add `LibraryRepository? _libraryRepository;` and:

```dart
LibraryRepository get _appLibraryRepository =>
    _libraryRepository ??= DriftLibraryRepository(_appDatabase);
```

Load folders in `_loadSavedDocuments()`:

```dart
final folders = await _appLibraryRepository.listFolders();
```

Map to `LibraryFolderViewModel`, and store `_folders`.

- [ ] **Step 2: Add state fields**

In `_LibraryHomeState`, add:

```dart
final List<LibraryFolderViewModel> _folders = [];
var _selectedFolderId = LibraryScreen.allFolderId;
static const _translationModeKey = 'default_translation_mode';
```

Update document VM creation to include `folderId: row.folderId`.

- [ ] **Step 3: Pass callbacks to `LibraryScreen`**

In `build`, pass:

```dart
folders: _folders,
selectedFolderId: _selectedFolderId,
onFolderSelected: (folderId) => setState(() => _selectedFolderId = folderId),
onCreateFolder: _createFolder,
onSettingsPressed: _openSettings,
onRenameDocument: _renameDocument,
onMoveDocument: _moveDocument,
onDeleteDocument: _deleteDocument,
```

- [ ] **Step 4: Implement folder/document dialogs**

Add helpers:

```dart
Future<String?> _promptForText({required String title, required String initialValue})
Future<bool> _confirm({required String title, required String body})
```

Use `AlertDialog` with `TextField`, `취소`, and `저장` / `삭제`.

- [ ] **Step 5: Implement actions**

Add:

```dart
Future<void> _createFolder()
Future<void> _renameDocument(String documentId)
Future<void> _moveDocument(String documentId)
Future<void> _deleteDocument(String documentId)
```

Use `_appLibraryRepository` for DB changes. In delete, find `localPdfPath`, call repository delete, then `DocumentFileStore(rootDirectory: appDirectory).deleteDocumentFiles(documentId: documentId)`, clear maps and progress keys, then refresh lists.

- [ ] **Step 6: Implement settings open**

Add `_openSettings()`:

```dart
Future<void> _openSettings() async {
  final preferences = await _appPreferences;
  final modeName = preferences.getString(_translationModeKey) ?? TranslationModePreference.simple.name;
  final mode = TranslationModePreference.values.byName(modeName);
  final hasToken = ((await _appOpenAiKeyStore.readKey()) ?? '').trim().isNotEmpty;
  if (!mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => AppSettingsScreen(
        hasOpenAiToken: hasToken,
        translationMode: mode,
        onSaveOpenAiToken: (token) => _appOpenAiKeyStore.writeKey(token),
        onClearOpenAiToken: _appOpenAiKeyStore.clear,
        onTranslationModeChanged: (mode) async {
          final prefs = await _appPreferences;
          await prefs.setString(_translationModeKey, mode.name);
        },
      ),
    ),
  );
}
```

- [ ] **Step 7: Verify full app**

Run:

```powershell
flutter analyze
flutter test
services\converter\.venv\Scripts\python -m pytest services/converter/tests/test_pdf_converter.py services/converter/tests/test_jobs_api.py -q
flutter build apk --release
```

Expected: all commands exit 0.

- [ ] **Step 8: Commit, push, release**

```powershell
git add apps/thesis_reader/lib/app.dart apps/thesis_reader/lib/features/library/presentation/library_screen.dart apps/thesis_reader/lib/features/settings/presentation/app_settings_screen.dart apps/thesis_reader/test
git commit -m "feat(app): manage library folders and settings"
git push origin HEAD:main
```

Create GitHub release `v0.1.8-mvp` with `apps/thesis_reader/build/app/outputs/flutter-apk/app-release.apk`.

---

## Self-Review

- Spec coverage: folder organization, rename, move, delete, internal file cleanup, settings, OpenAI token, and default translation mode are covered.
- Placeholder scan: no unfinished placeholder markers remain; code snippets define concrete APIs.
- Type consistency: `LibraryFolderViewModel`, `LibraryDocumentViewModel.folderId`, `LibraryRepository`, and `TranslationModePreference` are introduced before use.
