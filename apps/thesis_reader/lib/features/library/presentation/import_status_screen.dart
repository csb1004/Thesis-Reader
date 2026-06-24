import 'package:flutter/material.dart';

enum ImportStatusState { waitingForServer, converting, previewReady, failed }

class ImportStatusScreen extends StatelessWidget {
  const ImportStatusScreen({
    super.key,
    required this.documentId,
    this.state = ImportStatusState.waitingForServer,
    this.onPreviewOriginalPdf,
    this.onRetry,
  });

  final String documentId;
  final ImportStatusState state;
  final VoidCallback? onPreviewOriginalPdf;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF 가져오기')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ImportStatusContent(
            state: state,
            onPreviewOriginalPdf: onPreviewOriginalPdf,
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

class _ImportStatusContent extends StatelessWidget {
  const _ImportStatusContent({
    required this.state,
    this.onPreviewOriginalPdf,
    this.onRetry,
  });

  final ImportStatusState state;
  final VoidCallback? onPreviewOriginalPdf;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ImportStatusState.waitingForServer => const Text('서버 대기 중'),
      ImportStatusState.converting => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('변환 중'),
        ],
      ),
      ImportStatusState.previewReady => FilledButton.icon(
        onPressed: onPreviewOriginalPdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('원본 PDF 미리보기'),
      ),
      ImportStatusState.failed => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('가져오기에 실패했습니다'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    };
  }
}
