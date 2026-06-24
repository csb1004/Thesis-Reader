import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_reader/app.dart';
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('library shows empty state and import action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));

    expect(find.text('논문이 없습니다'), findsOneWidget);
    expect(find.text('PDF 가져오기'), findsOneWidget);
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
              conversionStatus: '변환 완료',
              lastReadProgress: 0.42,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Attention Is All You Need'), findsOneWidget);
    expect(find.text('변환 완료'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
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

    await tester.tap(find.text('원본 PDF 미리보기'));
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

    expect(find.text('가져오기에 실패했습니다'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retryTapped, isTrue);
  });

  testWidgets('app routes library, import status, and reader placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const ThesisReaderApp());

    expect(find.text('논문이 없습니다'), findsOneWidget);

    final context = tester.element(find.byType(LibraryScreen));
    context.go('/reader/doc-1');
    await tester.pumpAndSettle();

    expect(find.text('리더 준비 중'), findsOneWidget);
  });
}
