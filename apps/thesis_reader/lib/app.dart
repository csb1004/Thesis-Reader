import 'dart:convert';
import 'dart:io';

import 'package:document_contract/document_contract.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
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
  TranslationService? _translationService;
  VocabularyRepository? _vocabularyRepository;
  final List<LibraryDocumentViewModel> _documents = [];
  final Map<String, DocumentPackage> _packagesByDocumentId = {};
  final Map<String, String> _originalPdfPathsByDocumentId = {};
  var _isImporting = false;

  @override
  void dispose() {
    _openAiClient?.close();
    _database?.close();
    super.dispose();
  }

  AppDatabase get _appDatabase => _database ??= AppDatabase();

  OpenAiKeyStore get _appOpenAiKeyStore => _openAiKeyStore ??= OpenAiKeyStore();

  OpenAiClient get _appOpenAiClient =>
      _openAiClient ??= OpenAiClient(keyStore: _appOpenAiKeyStore);

  TranslationService get _appTranslationService => _translationService ??=
      TranslationService(openAiClient: _appOpenAiClient);

  VocabularyRepository get _appVocabularyRepository =>
      _vocabularyRepository ??= DriftVocabularyRepository(_appDatabase);

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
          translationService: _appTranslationService,
          vocabularyRepository: _appVocabularyRepository,
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
