import 'dart:io';

import 'package:document_contract/document_contract.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thesis_reader/features/library/data/document_repository.dart';
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';
import 'package:thesis_reader/shared/storage/document_file_store.dart';

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
  final List<LibraryDocumentViewModel> _documents = [];
  final Map<String, DocumentPackage> _packagesByDocumentId = {};
  var _isImporting = false;

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
      final package = _buildImportedPdfPackage(document);

      if (!mounted) {
        return;
      }
      setState(() {
        _packagesByDocumentId[document.id] = package;
        _documents.add(
          LibraryDocumentViewModel(
            id: document.id,
            title: document.sourceFilename,
            conversionStatus: 'PDF 가져오기 완료',
            lastReadProgress: 0,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${document.sourceFilename} 가져오기 완료')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 가져오기에 실패했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _openDocument(String documentId) {
    final package = _packagesByDocumentId[documentId];
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          documentId: documentId,
          package: package,
        ),
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
          text: 'PDF를 앱에 가져왔습니다. 논문 본문을 카카오페이지식 리더로 보려면 Railway 변환 서버 연결 또는 온디바이스 변환 연결이 필요합니다.',
        ),
      ],
      assets: const [],
    );
  }
}
