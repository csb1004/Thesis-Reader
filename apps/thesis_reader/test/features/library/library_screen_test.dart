import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_reader/app.dart';
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';

void main() {
  testWidgets('library shows empty state and import action', (tester) async {
    var importTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(onImportPressed: () => importTapped = true),
      ),
    );

    expect(find.byIcon(Icons.upload_file), findsOneWidget);

    await tester.tap(find.byIcon(Icons.upload_file));
    expect(importTapped, isTrue);
  });

  testWidgets('library shows document rows with status and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryScreen(
          documents: [
            LibraryDocumentViewModel(
              id: 'doc-1',
              title: 'Attention Is All You Need',
              conversionStatus: 'converted',
              lastReadProgress: 0.42,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Attention Is All You Need'), findsOneWidget);
    expect(find.text('converted'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('library shows unread documents without a misleading percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryScreen(
          documents: [
            LibraryDocumentViewModel(
              id: 'doc-1',
              title: 'Attention Is All You Need',
              conversionStatus: '변환 완료',
              lastReadProgress: 0,
            ),
          ],
        ),
      ),
    );

    expect(find.text('읽기 전'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('library invokes document selection callbacks', (tester) async {
    String? selectedDocumentId;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          documents: const [
            LibraryDocumentViewModel(
              id: 'doc-1',
              title: 'Attention Is All You Need',
              conversionStatus: 'converted',
              lastReadProgress: 0.42,
            ),
          ],
          onDocumentSelected: (documentId) => selectedDocumentId = documentId,
        ),
      ),
    );

    await tester.tap(find.text('Attention Is All You Need'));
    expect(selectedDocumentId, 'doc-1');
  });

  testWidgets('import status screen exposes preview and retry actions', (
    tester,
  ) async {
    var previewTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportStatusScreen(
          documentId: 'doc-1',
          state: ImportStatusState.previewReady,
          onPreviewOriginalPdf: () => previewTapped = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.picture_as_pdf));
    expect(previewTapped, isTrue);

    var retryTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportStatusScreen(
          documentId: 'doc-1',
          state: ImportStatusState.failed,
          onRetry: () => retryTapped = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    expect(retryTapped, isTrue);
  });

  testWidgets('app routes library, import status, and empty reader state', (
    tester,
  ) async {
    await tester.pumpWidget(const ThesisReaderApp());

    expect(find.byType(LibraryScreen), findsOneWidget);

    final context = tester.element(find.byType(LibraryScreen));
    context.go('/reader/doc-1');
    await tester.pumpAndSettle();

    expect(find.byType(ReaderScreen), findsOneWidget);
  });
}
