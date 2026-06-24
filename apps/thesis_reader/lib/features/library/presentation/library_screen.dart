import 'package:flutter/material.dart';

class LibraryDocumentViewModel {
  const LibraryDocumentViewModel({
    required this.id,
    required this.title,
    required this.conversionStatus,
    required this.lastReadProgress,
  });

  final String id;
  final String title;
  final String conversionStatus;
  final double lastReadProgress;
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    this.documents = const [],
    this.onImportPressed,
    this.onDocumentSelected,
  });

  final List<LibraryDocumentViewModel> documents;
  final VoidCallback? onImportPressed;
  final ValueChanged<String>? onDocumentSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thesis Reader')),
      body: documents.isEmpty
          ? _LibraryEmptyState(onImportPressed: onImportPressed)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final document = documents[index];
                return _LibraryDocumentRow(
                  document: document,
                  onTap: onDocumentSelected == null
                      ? null
                      : () => onDocumentSelected!(document.id),
                );
              },
            ),
      floatingActionButton: documents.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: onImportPressed,
              icon: const Icon(Icons.upload_file),
              label: const Text('PDF 가져오기'),
            ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({this.onImportPressed});

  final VoidCallback? onImportPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('논문이 없습니다', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onImportPressed,
            icon: const Icon(Icons.upload_file),
            label: const Text('PDF 가져오기'),
          ),
        ],
      ),
    );
  }
}

class _LibraryDocumentRow extends StatelessWidget {
  const _LibraryDocumentRow({required this.document, this.onTap});

  final LibraryDocumentViewModel document;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = (document.lastReadProgress.clamp(0, 1) * 100).round();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      title: Text(document.title),
      subtitle: Text(document.conversionStatus),
      trailing: Text(progress == 0 ? '읽기 전' : '$progress%'),
      onTap: onTap,
    );
  }
}
