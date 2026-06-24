import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:document_contract/document_contract.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
import 'package:thesis_reader/features/ai/data/simple_translation_client.dart';
import 'package:thesis_reader/features/ai/domain/summary_service.dart';
import 'package:thesis_reader/features/ai/domain/translation_service.dart';
import 'package:thesis_reader/features/library/data/converter_client.dart';
import 'package:thesis_reader/features/library/data/document_repository.dart';
import 'package:thesis_reader/features/library/data/library_repository.dart';
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';
import 'package:thesis_reader/features/settings/presentation/app_settings_screen.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';
import 'package:thesis_reader/shared/storage/app_database.dart';
import 'package:thesis_reader/shared/storage/document_file_store.dart';

const _converterBaseUri = 'https://thesis-reader-production.up.railway.app';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _LibraryHome()),
    GoRoute(
      path: '/import/:documentId',
      builder: (context, state) => ImportStatusScreen(
        documentId: state.pathParameters['documentId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/reader/:documentId',
      builder: (context, state) =>
          ReaderScreen(documentId: state.pathParameters['documentId'] ?? ''),
    ),
  ],
);

class ThesisReaderApp extends StatelessWidget {
  const ThesisReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Thesis Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      routerConfig: _router,
    );
  }
}

class _LibraryHome extends StatefulWidget {
  const _LibraryHome();

  @override
  State<_LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<_LibraryHome> {
  AppDatabase? _database;
  OpenAiKeyStore? _openAiKeyStore;
  OpenAiClient? _openAiClient;
  SimpleTranslationClient? _simpleTranslationClient;
  TranslationService? _translationService;
  SummaryService? _summaryService;
  VocabularyRepository? _vocabularyRepository;
  LibraryRepository? _libraryRepository;
  SharedPreferences? _preferences;
  final List<LibraryDocumentViewModel> _documents = [];
  final List<LibraryFolderViewModel> _folders = [];
  final Map<String, DocumentPackage> _packagesByDocumentId = {};
  final Map<String, String> _originalPdfPathsByDocumentId = {};
  final Map<String, int> _pageIndexByDocumentId = {};
  final Map<String, double> _scrollProgressByDocumentId = {};
  var _selectedFolderId = LibraryScreen.allFolderId;
  var _isImporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedDocuments());
  }

  @override
  void dispose() {
    _openAiClient?.close();
    _simpleTranslationClient?.close();
    _database?.close();
    super.dispose();
  }

  AppDatabase get _appDatabase => _database ??= AppDatabase();

  OpenAiKeyStore get _appOpenAiKeyStore => _openAiKeyStore ??= OpenAiKeyStore();

  OpenAiClient get _appOpenAiClient =>
      _openAiClient ??= OpenAiClient(keyStore: _appOpenAiKeyStore);

  SimpleTranslationClient get _appSimpleTranslationClient =>
      _simpleTranslationClient ??= SimpleTranslationClient();

  TranslationService get _appTranslationService => _translationService ??=
      TranslationService(openAiClient: _appOpenAiClient);

  SummaryService get _appSummaryService =>
      _summaryService ??= SummaryService(openAiClient: _appOpenAiClient);

  VocabularyRepository get _appVocabularyRepository =>
      _vocabularyRepository ??= DriftVocabularyRepository(_appDatabase);

  LibraryRepository get _appLibraryRepository =>
      _libraryRepository ??= DriftLibraryRepository(_appDatabase);

  Future<SharedPreferences> get _appPreferences async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Widget build(BuildContext context) {
    return LibraryScreen(
      documents: _documents,
      folders: _folders,
      selectedFolderId: _selectedFolderId,
      onImportPressed: _isImporting ? null : _importPdf,
      onDocumentSelected: _openDocument,
      onFolderSelected: (folderId) => setState(() {
        _selectedFolderId = folderId;
      }),
      onCreateFolderPressed: _createFolder,
      onRenameFolder: _renameFolder,
      onDeleteFolder: _deleteFolder,
      onRenameDocument: _renameDocument,
      onMoveDocument: _moveDocument,
      onReconvertDocument: _reconvertDocument,
      onDeleteDocument: _deleteDocument,
      onSettingsPressed: _openSettings,
    );
  }

  Future<void> _importPdf() async {
    setState(() => _isImporting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );
      final selectedPath = result?.files.single.path;
      if (selectedPath == null) {
        return;
      }

      final appDirectory = await getApplicationDocumentsDirectory();
      final repository = InMemoryDocumentRepository(
        fileStore: DocumentFileStore(rootDirectory: appDirectory),
      );
      final document = await repository.importPdf(File(selectedPath));
      await _saveImportedDocument(document);
      final package = _buildImportedPdfPackage(document);

      if (!mounted) {
        return;
      }
      setState(() {
        _packagesByDocumentId[document.id] = package;
        _originalPdfPathsByDocumentId[document.id] = document.localPdfPath;
        _documents.add(
          LibraryDocumentViewModel(
            id: document.id,
            title: document.sourceFilename,
            conversionStatus: '서버 변환 중',
            lastReadProgress: 0,
            folderId: null,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${document.sourceFilename} 가져오기 완료')),
      );

      await _convertWithRailway(document, appDirectory);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 가져오기에 실패했습니다: $error')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _openDocument(String documentId) {
    final package = _packagesByDocumentId[documentId];
    final readablePackage =
        package?.metadata.converterVersion == 'app-shell-import-placeholder'
        ? null
        : package;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          documentId: documentId,
          package: readablePackage,
          originalPdfPath: _originalPdfPathsByDocumentId[documentId],
          openAiKeyStore: _appOpenAiKeyStore,
          simpleTranslationClient: _appSimpleTranslationClient,
          translationService: _appTranslationService,
          summaryService: _appSummaryService,
          vocabularyRepository: _appVocabularyRepository,
          initialPageIndex: _pageIndexByDocumentId[documentId],
          initialScrollProgress: _scrollProgressByDocumentId[documentId],
          onProgressChanged: _handleReaderProgress,
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await _promptForText(title: '폴더 만들기', label: '폴더 이름');
    if (name == null) {
      return;
    }

    try {
      final folder = await _appLibraryRepository.createFolder(name);
      setState(() => _selectedFolderId = folder.id);
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('폴더를 만들 수 없습니다: $error');
    }
  }

  Future<void> _renameFolder(String folderId) async {
    final folder = _findFolder(folderId);
    final name = await _promptForText(
      title: '폴더 이름 변경',
      label: '폴더 이름',
      initialValue: folder?.name,
    );
    if (name == null) {
      return;
    }

    try {
      await _appLibraryRepository.renameFolder(folderId: folderId, name: name);
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('폴더 이름을 바꿀 수 없습니다: $error');
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final confirmed = await _confirm(
      title: '폴더 삭제',
      message: '폴더만 삭제하고 안의 논문은 미분류로 이동합니다.',
    );
    if (!confirmed) {
      return;
    }

    try {
      await _appLibraryRepository.deleteFolder(folderId);
      if (_selectedFolderId == folderId) {
        setState(() => _selectedFolderId = LibraryScreen.allFolderId);
      }
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('폴더를 삭제할 수 없습니다: $error');
    }
  }

  Future<void> _renameDocument(String documentId) async {
    final document = _findDocument(documentId);
    final title = await _promptForText(
      title: '논문 이름 변경',
      label: '논문 이름',
      initialValue: document?.title,
    );
    if (title == null) {
      return;
    }

    try {
      await _appLibraryRepository.renameDocument(
        documentId: documentId,
        title: title,
      );
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('논문 이름을 바꿀 수 없습니다: $error');
    }
  }

  Future<void> _moveDocument(String documentId) async {
    final folderId = await _selectTargetFolder();
    if (folderId == _cancelledFolderSelection) {
      return;
    }

    try {
      await _appLibraryRepository.moveDocument(
        documentId: documentId,
        folderId: folderId,
      );
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('논문을 이동할 수 없습니다: $error');
    }
  }

  Future<void> _reconvertDocument(String documentId) async {
    final row = await (_appDatabase.select(
      _appDatabase.documents,
    )..where((document) => document.id.equals(documentId))).getSingleOrNull();
    if (row == null) {
      _showSnackBar('변환할 논문을 찾을 수 없습니다.');
      return;
    }

    final localPdf = File(row.localPdfPath);
    if (!await localPdf.exists()) {
      _showSnackBar('저장된 원본 PDF를 찾을 수 없습니다.');
      return;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    _replaceDocumentStatus(documentId, '변환 중');
    if (mounted) {
      setState(() {});
    }
    _showSnackBar('${row.title} 변환을 다시 시작했습니다.');

    await _convertWithRailway(
      DocumentRecord(
        id: row.id,
        sourceFilename: row.sourceFilename,
        localPdfPath: row.localPdfPath,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      ),
      appDirectory,
    );
    await _loadSavedDocuments();
  }

  Future<void> _deleteDocument(String documentId) async {
    final document = _findDocument(documentId);
    final confirmed = await _confirm(
      title: '논문 삭제',
      message: '${document?.title ?? '이 논문'}을 앱에서 삭제합니다.',
    );
    if (!confirmed) {
      return;
    }

    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      await DocumentFileStore(
        rootDirectory: appDirectory,
      ).deleteDocumentFiles(documentId);
      await _deletePackageFiles(
        appDirectory: appDirectory,
        documentId: documentId,
      );
      await _appLibraryRepository.deleteDocument(documentId);
      final preferences = await _appPreferences;
      await preferences.remove(_progressKey(documentId));
      await preferences.remove(_pageIndexKey(documentId));
      await preferences.remove(_scrollProgressKey(documentId));
      _packagesByDocumentId.remove(documentId);
      _originalPdfPathsByDocumentId.remove(documentId);
      _pageIndexByDocumentId.remove(documentId);
      _scrollProgressByDocumentId.remove(documentId);
      await _loadSavedDocuments();
    } on Object catch (error) {
      _showSnackBar('논문을 삭제할 수 없습니다: $error');
    }
  }

  Future<void> _openSettings() async {
    final preferences = await _appPreferences;
    final key = await _appOpenAiKeyStore.readKey();
    final modeName =
        preferences.getString(_translationModePreferenceKey) ??
        TranslationModePreference.simple.name;
    final mode = TranslationModePreference.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => TranslationModePreference.simple,
    );

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AppSettingsScreen(
          initialOpenAiApiKey: key,
          initialTranslationMode: mode,
          onSaveOpenAiApiKey: _appOpenAiKeyStore.writeKey,
          onClearOpenAiApiKey: _appOpenAiKeyStore.clear,
          onTranslationModeChanged: (value) {
            unawaited(
              preferences.setString(_translationModePreferenceKey, value.name),
            );
          },
        ),
      ),
    );
  }

  LibraryFolderViewModel? _findFolder(String folderId) {
    for (final folder in _folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }

  LibraryDocumentViewModel? _findDocument(String documentId) {
    for (final document in _documents) {
      if (document.id == documentId) {
        return document;
      }
    }
    return null;
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    try {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.of(context).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ).then((value) {
        if (value == null || value.isEmpty) {
          return null;
        }
        return value;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _selectTargetFolder() async {
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleDialog(
        title: const Text('폴더 이동'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(null),
            child: const ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('미분류'),
            ),
          ),
          for (final folder in _folders)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(folder.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
              ),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_cancelledFolderSelection),
            child: const ListTile(
              leading: Icon(Icons.close),
              title: Text('취소'),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _deletePackageFiles({
    required Directory appDirectory,
    required String documentId,
  }) async {
    final packageDirectory = Directory(
      p.join(appDirectory.path, 'packages', documentId),
    );
    final rootPath = p.canonicalize(appDirectory.path);
    final packagePath = p.canonicalize(packageDirectory.path);
    if (!p.isWithin(rootPath, packagePath)) {
      throw StateError('Refusing to delete files outside the app directory.');
    }
    if (await packageDirectory.exists()) {
      await packageDirectory.delete(recursive: true);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _convertWithRailway(
    DocumentRecord document,
    Directory appDirectory,
  ) async {
    final client = HttpConverterClient(baseUri: Uri.parse(_converterBaseUri));
    try {
      final job = await client.createJob(File(document.localPdfPath));
      var status = job.status;

      while (status == ConverterJobStatus.queued ||
          status == ConverterJobStatus.processing) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        status = await client.getJob(job.jobId);
      }

      if (status == ConverterJobStatus.failed) {
        throw StateError('Railway converter job failed');
      }

      final packageFile = await client.downloadPackage(
        job.jobId,
        Directory(p.join(appDirectory.path, 'packages', document.id)),
      );
      final payload =
          jsonDecode(await packageFile.readAsString()) as Map<String, Object?>;
      final convertedPackage = _withPackageAssetPaths(
        DocumentPackage.fromJson(payload),
        packageFile.parent,
      );
      await _markDocumentConverted(document.id, packageFile.path);

      if (!mounted) {
        return;
      }
      setState(() {
        _packagesByDocumentId[document.id] = convertedPackage;
        _replaceDocumentStatus(document.id, '변환 완료');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${document.sourceFilename} 변환 완료')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceDocumentStatus(document.id, '서버 변환 실패 - 원본 보기');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('서버 변환 실패: $error')));
    } finally {
      client.close();
    }
  }

  void _replaceDocumentStatus(String documentId, String status) {
    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) {
      return;
    }

    final document = _documents[index];
    _documents[index] = LibraryDocumentViewModel(
      id: document.id,
      title: document.title,
      conversionStatus: status,
      lastReadProgress: document.lastReadProgress,
      folderId: document.folderId,
    );
  }

  void _handleReaderProgress(ReaderProgress progress) {
    final index = _documents.indexWhere(
      (document) => document.id == progress.documentId,
    );
    if (index == -1) {
      return;
    }

    final value = progress.pageIndex != null && progress.pageCount != null
        ? ((progress.pageIndex! + 1) / progress.pageCount!).clamp(0.0, 1.0)
        : progress.scrollProgress;
    if (value == null) {
      return;
    }

    if (progress.pageIndex != null) {
      _pageIndexByDocumentId[progress.documentId] = progress.pageIndex!;
    }
    if (progress.scrollProgress != null) {
      _scrollProgressByDocumentId[progress.documentId] =
          progress.scrollProgress!;
    }
    unawaited(_saveReaderProgress(progress, value));

    setState(() {
      final document = _documents[index];
      _documents[index] = LibraryDocumentViewModel(
        id: document.id,
        title: document.title,
        conversionStatus: document.conversionStatus,
        lastReadProgress: value,
        folderId: document.folderId,
      );
    });
  }

  Future<void> _saveReaderProgress(
    ReaderProgress progress,
    double readProgress,
  ) async {
    final preferences = await _appPreferences;
    await preferences.setDouble(
      _progressKey(progress.documentId),
      readProgress,
    );
    if (progress.pageIndex != null) {
      await preferences.setInt(
        _pageIndexKey(progress.documentId),
        progress.pageIndex!,
      );
    }
    if (progress.scrollProgress != null) {
      await preferences.setDouble(
        _scrollProgressKey(progress.documentId),
        progress.scrollProgress!,
      );
    }
  }

  Future<void> _loadSavedDocuments() async {
    final preferences = await _appPreferences;
    final appDirectory = await getApplicationDocumentsDirectory();
    final rows = await _appLibraryRepository.listDocuments();
    final folderRows = await _appLibraryRepository.listFolders();
    if (!mounted) {
      return;
    }

    final documents = <LibraryDocumentViewModel>[];
    final documentCountsByFolderId = <String, int>{};
    final packagesByDocumentId = <String, DocumentPackage>{};
    final originalPdfPathsByDocumentId = <String, String>{};
    final pageIndexByDocumentId = <String, int>{};
    final scrollProgressByDocumentId = <String, double>{};

    for (final row in rows) {
      final packageDirectory = Directory(
        p.join(appDirectory.path, 'packages', row.id),
      );
      final packageFile = File(p.join(packageDirectory.path, 'package.json'));
      final hasPackage = await packageFile.exists();
      if (hasPackage) {
        final payload =
            jsonDecode(await packageFile.readAsString())
                as Map<String, Object?>;
        packagesByDocumentId[row.id] = _withPackageAssetPaths(
          DocumentPackage.fromJson(payload),
          packageDirectory,
        );
      }

      originalPdfPathsByDocumentId[row.id] = row.localPdfPath;
      final progress = preferences.getDouble(_progressKey(row.id)) ?? 0;
      final pageIndex = preferences.getInt(_pageIndexKey(row.id));
      final scrollProgress = preferences.getDouble(_scrollProgressKey(row.id));
      if (pageIndex != null) {
        pageIndexByDocumentId[row.id] = pageIndex;
      }
      if (scrollProgress != null) {
        scrollProgressByDocumentId[row.id] = scrollProgress;
      }
      documents.add(
        LibraryDocumentViewModel(
          id: row.id,
          title: row.title,
          conversionStatus: packageFile.existsSync() ? '변환 완료' : '원본 PDF 보기',
          lastReadProgress: progress,
          folderId: row.folderId,
        ),
      );
      final folderId = row.folderId;
      if (folderId != null) {
        documentCountsByFolderId[folderId] =
            (documentCountsByFolderId[folderId] ?? 0) + 1;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _folders
        ..clear()
        ..addAll(
          folderRows.map(
            (folder) => LibraryFolderViewModel(
              id: folder.id,
              name: folder.name,
              documentCount: documentCountsByFolderId[folder.id] ?? 0,
            ),
          ),
        );
      _documents
        ..clear()
        ..addAll(documents);
      _packagesByDocumentId
        ..clear()
        ..addAll(packagesByDocumentId);
      _originalPdfPathsByDocumentId
        ..clear()
        ..addAll(originalPdfPathsByDocumentId);
      _pageIndexByDocumentId
        ..clear()
        ..addAll(pageIndexByDocumentId);
      _scrollProgressByDocumentId
        ..clear()
        ..addAll(scrollProgressByDocumentId);
    });
  }

  Future<void> _saveImportedDocument(DocumentRecord document) {
    return _appDatabase
        .into(_appDatabase.documents)
        .insertOnConflictUpdate(
          DocumentsCompanion.insert(
            id: document.id,
            title: document.sourceFilename,
            sourceFilename: document.sourceFilename,
            localPdfPath: document.localPdfPath,
            status: document.status,
            createdAt: document.createdAt,
            updatedAt: document.updatedAt,
            packagePath: const Value.absent(),
            lastReadBlockId: const Value.absent(),
            lastReadOffset: const Value.absent(),
          ),
        );
  }

  Future<void> _markDocumentConverted(String documentId, String packagePath) {
    return (_appDatabase.update(
      _appDatabase.documents,
    )..where((document) => document.id.equals(documentId))).write(
      DocumentsCompanion(
        packagePath: Value(packagePath),
        status: const Value('converted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  DocumentPackage _buildImportedPdfPackage(DocumentRecord document) {
    return DocumentPackage(
      packageVersion: 1,
      documentId: document.id,
      metadata: DocumentMetadata(
        title: document.sourceFilename,
        sourceFilename: document.sourceFilename,
        originalPdfSha256: document.id,
        importedAtIso8601: document.createdAt.toIso8601String(),
        converterVersion: 'app-shell-import-placeholder',
      ),
      sections: const [
        DocumentSection(
          id: 'import',
          title: '가져온 PDF',
          blockIds: ['import-message'],
        ),
      ],
      blocks: const [
        DocumentBlock.paragraph(
          id: 'import-message',
          sectionId: 'import',
          text: 'PDF를 앱에 가져왔습니다. 서버 변환이 끝나면 논문 본문이 리더 형식으로 표시됩니다.',
        ),
      ],
      assets: const [],
    );
  }

  DocumentPackage _withPackageAssetPaths(
    DocumentPackage package,
    Directory packageDirectory,
  ) {
    return DocumentPackage(
      packageVersion: package.packageVersion,
      documentId: package.documentId,
      metadata: package.metadata,
      sections: package.sections,
      blocks: package.blocks,
      assets: [
        for (final asset in package.assets)
          DocumentAsset(
            id: asset.id,
            kind: asset.kind,
            label: asset.label,
            relativePath: p.isAbsolute(asset.relativePath)
                ? asset.relativePath
                : p.join(packageDirectory.path, asset.relativePath),
            caption: asset.caption,
          ),
      ],
      anchors: package.anchors,
      vocabulary: package.vocabulary,
      summaries: package.summaries,
    );
  }
}

String _progressKey(String documentId) => 'reader_progress_$documentId';

String _pageIndexKey(String documentId) => 'reader_page_index_$documentId';

String _scrollProgressKey(String documentId) =>
    'reader_scroll_progress_$documentId';

const _translationModePreferenceKey = 'translation_mode_preference';

const _cancelledFolderSelection = '__cancelled_folder_selection__';
