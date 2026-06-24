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
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';
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
  SharedPreferences? _preferences;
  final List<LibraryDocumentViewModel> _documents = [];
  final Map<String, DocumentPackage> _packagesByDocumentId = {};
  final Map<String, String> _originalPdfPathsByDocumentId = {};
  final Map<String, int> _pageIndexByDocumentId = {};
  final Map<String, double> _scrollProgressByDocumentId = {};
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

  Future<SharedPreferences> get _appPreferences async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Widget build(BuildContext context) {
    return LibraryScreen(
      documents: _documents,
      onImportPressed: _isImporting ? null : _importPdf,
      onDocumentSelected: _openDocument,
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
        _replaceDocumentStatus(document.id, '서버 변환 실패 - 임시 보기');
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
    final rows = await _appDatabase.select(_appDatabase.documents).get();
    if (!mounted || rows.isEmpty) {
      return;
    }

    final documents = <LibraryDocumentViewModel>[];
    final packagesByDocumentId = <String, DocumentPackage>{};
    final originalPdfPathsByDocumentId = <String, String>{};
    final pageIndexByDocumentId = <String, int>{};
    final scrollProgressByDocumentId = <String, double>{};

    for (final row in rows) {
      final packageDirectory = Directory(
        p.join(appDirectory.path, 'packages', row.id),
      );
      final packageFile = File(p.join(packageDirectory.path, 'package.json'));
      if (await packageFile.exists()) {
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
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
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
