import 'package:flutter/material.dart';

class LibraryFolderViewModel {
  const LibraryFolderViewModel({
    required this.id,
    required this.name,
    required this.documentCount,
  });

  final String id;
  final String name;
  final int documentCount;
}

class LibraryDocumentViewModel {
  const LibraryDocumentViewModel({
    required this.id,
    required this.title,
    required this.conversionStatus,
    required this.lastReadProgress,
    this.folderId,
  });

  final String id;
  final String title;
  final String conversionStatus;
  final double lastReadProgress;
  final String? folderId;
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    this.documents = const [],
    this.folders = const [],
    this.selectedFolderId = allFolderId,
    this.onImportPressed,
    this.onDocumentSelected,
    this.onFolderSelected,
    this.onCreateFolderPressed,
    this.onRenameFolder,
    this.onDeleteFolder,
    this.onRenameDocument,
    this.onMoveDocument,
    this.onReconvertDocument,
    this.onDeleteDocument,
    this.onSettingsPressed,
  });

  static const allFolderId = '__all__';
  static const unfiledFolderId = '__unfiled__';

  final List<LibraryDocumentViewModel> documents;
  final List<LibraryFolderViewModel> folders;
  final String selectedFolderId;
  final VoidCallback? onImportPressed;
  final ValueChanged<String>? onDocumentSelected;
  final ValueChanged<String>? onFolderSelected;
  final VoidCallback? onCreateFolderPressed;
  final ValueChanged<String>? onRenameFolder;
  final ValueChanged<String>? onDeleteFolder;
  final ValueChanged<String>? onRenameDocument;
  final ValueChanged<String>? onMoveDocument;
  final ValueChanged<String>? onReconvertDocument;
  final ValueChanged<String>? onDeleteDocument;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final visibleDocuments = _visibleDocuments;
    final allCount = documents.length;
    final unfiledCount = documents
        .where((document) => document.folderId == null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thesis Reader'),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: onSettingsPressed,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: documents.isEmpty
          ? _LibraryEmptyState(onImportPressed: onImportPressed)
          : LayoutBuilder(
              builder: (context, constraints) {
                final folderList = _FolderList(
                  folders: folders,
                  selectedFolderId: selectedFolderId,
                  allCount: allCount,
                  unfiledCount: unfiledCount,
                  onFolderSelected: onFolderSelected,
                  onCreateFolderPressed: onCreateFolderPressed,
                  onRenameFolder: onRenameFolder,
                  onDeleteFolder: onDeleteFolder,
                );
                final documentList = _DocumentList(
                  documents: visibleDocuments,
                  isFiltered: selectedFolderId != allFolderId,
                  onDocumentSelected: onDocumentSelected,
                  onRenameDocument: onRenameDocument,
                  onMoveDocument: onMoveDocument,
                  onReconvertDocument: onReconvertDocument,
                  onDeleteDocument: onDeleteDocument,
                );

                if (constraints.maxWidth >= 720) {
                  return Row(
                    children: [
                      SizedBox(width: 240, child: folderList),
                      const VerticalDivider(width: 1),
                      Expanded(child: documentList),
                    ],
                  );
                }

                return Column(
                  children: [
                    SizedBox(height: 72, child: folderList),
                    const Divider(height: 1),
                    Expanded(child: documentList),
                  ],
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

  List<LibraryDocumentViewModel> get _visibleDocuments {
    return switch (selectedFolderId) {
      allFolderId => documents,
      unfiledFolderId =>
        documents.where((document) => document.folderId == null).toList(),
      _ =>
        documents
            .where((document) => document.folderId == selectedFolderId)
            .toList(),
    };
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({
    required this.folders,
    required this.selectedFolderId,
    required this.allCount,
    required this.unfiledCount,
    this.onFolderSelected,
    this.onCreateFolderPressed,
    this.onRenameFolder,
    this.onDeleteFolder,
  });

  final List<LibraryFolderViewModel> folders;
  final String selectedFolderId;
  final int allCount;
  final int unfiledCount;
  final ValueChanged<String>? onFolderSelected;
  final VoidCallback? onCreateFolderPressed;
  final ValueChanged<String>? onRenameFolder;
  final ValueChanged<String>? onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _FolderEntry(
        id: LibraryScreen.allFolderId,
        name: '전체',
        count: allCount,
        canEdit: false,
      ),
      _FolderEntry(
        id: LibraryScreen.unfiledFolderId,
        name: '미분류',
        count: unfiledCount,
        canEdit: false,
      ),
      ...folders.map(
        (folder) => _FolderEntry(
          id: folder.id,
          name: folder.name,
          count: folder.documentCount,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 240) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return ActionChip(
                  avatar: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('폴더'),
                  onPressed: onCreateFolderPressed,
                );
              }
              final entry = entries[index];
              return ChoiceChip(
                label: Text('${entry.name} ${entry.count}'),
                selected: selectedFolderId == entry.id,
                onSelected: (_) => onFolderSelected?.call(entry.id),
              );
            },
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('폴더', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: '폴더 만들기',
                    onPressed: onCreateFolderPressed,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
            ),
            for (final entry in entries)
              _FolderTile(
                entry: entry,
                selected: selectedFolderId == entry.id,
                onSelected: () => onFolderSelected?.call(entry.id),
                onRename: entry.canEdit ? onRenameFolder : null,
                onDelete: entry.canEdit ? onDeleteFolder : null,
              ),
          ],
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.entry,
    required this.selected,
    this.onSelected,
    this.onRename,
    this.onDelete,
  });

  final _FolderEntry entry;
  final bool selected;
  final VoidCallback? onSelected;
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: Icon(selected ? Icons.folder : Icons.folder_outlined),
      title: Text(entry.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${entry.count}'),
          if (entry.canEdit)
            PopupMenuButton<_FolderAction>(
              tooltip: '폴더 메뉴',
              onSelected: (action) {
                switch (action) {
                  case _FolderAction.rename:
                    onRename?.call(entry.id);
                  case _FolderAction.delete:
                    onDelete?.call(entry.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _FolderAction.rename,
                  child: Text('이름 변경'),
                ),
                PopupMenuItem(value: _FolderAction.delete, child: Text('삭제')),
              ],
            ),
        ],
      ),
      onTap: onSelected,
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.isFiltered,
    this.onDocumentSelected,
    this.onRenameDocument,
    this.onMoveDocument,
    this.onReconvertDocument,
    this.onDeleteDocument,
  });

  final List<LibraryDocumentViewModel> documents;
  final bool isFiltered;
  final ValueChanged<String>? onDocumentSelected;
  final ValueChanged<String>? onRenameDocument;
  final ValueChanged<String>? onMoveDocument;
  final ValueChanged<String>? onReconvertDocument;
  final ValueChanged<String>? onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Center(
        child: Text(
          isFiltered ? '이 폴더에 논문이 없습니다' : '논문이 없습니다',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.separated(
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
          onRename: onRenameDocument,
          onMove: onMoveDocument,
          onReconvert: onReconvertDocument,
          onDelete: onDeleteDocument,
        );
      },
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
  const _LibraryDocumentRow({
    required this.document,
    this.onTap,
    this.onRename,
    this.onMove,
    this.onReconvert,
    this.onDelete,
  });

  final LibraryDocumentViewModel document;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onMove;
  final ValueChanged<String>? onReconvert;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (document.lastReadProgress.clamp(0, 1) * 100).round();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      title: Text(document.title),
      subtitle: Text(document.conversionStatus),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(progress == 0 ? '읽기 전' : '$progress%'),
          PopupMenuButton<_DocumentAction>(
            tooltip: '문서 메뉴',
            onSelected: (action) {
              switch (action) {
                case _DocumentAction.rename:
                  onRename?.call(document.id);
                case _DocumentAction.move:
                  onMove?.call(document.id);
                case _DocumentAction.reconvert:
                  onReconvert?.call(document.id);
                case _DocumentAction.delete:
                  onDelete?.call(document.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DocumentAction.rename,
                child: Text('이름 변경'),
              ),
              PopupMenuItem(value: _DocumentAction.move, child: Text('폴더 이동')),
              PopupMenuItem(
                value: _DocumentAction.reconvert,
                child: Text('PDF 다시 변환'),
              ),
              PopupMenuItem(value: _DocumentAction.delete, child: Text('삭제')),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FolderEntry {
  const _FolderEntry({
    required this.id,
    required this.name,
    required this.count,
    this.canEdit = true,
  });

  final String id;
  final String name;
  final int count;
  final bool canEdit;
}

enum _DocumentAction { rename, move, reconvert, delete }

enum _FolderAction { rename, delete }
