import 'package:flutter/material.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';

final class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({
    super.key,
    required this.documentId,
    required this.repository,
  });

  final String documentId;
  final VocabularyRepository repository;

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

final class _VocabularyScreenState extends State<VocabularyScreen> {
  late Future<List<VocabularyEntryView>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  @override
  void didUpdateWidget(covariant VocabularyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId ||
        oldWidget.repository != widget.repository) {
      _entriesFuture = _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('단어장')),
      body: FutureBuilder<List<VocabularyEntryView>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('단어장을 불러올 수 없습니다'));
          }

          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return const _VocabularyEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (context, index) => _VocabularyEntryTile(
              entry: entries[index],
              onEdit: () => _editEntry(entries[index]),
              onDelete: () => _deleteEntry(entries[index]),
            ),
          );
        },
      ),
    );
  }

  Future<List<VocabularyEntryView>> _loadEntries() {
    return widget.repository.listForDocument(widget.documentId);
  }

  Future<void> _editEntry(VocabularyEntryView entry) async {
    final updated = await showDialog<_VocabularyEditResult>(
      context: context,
      builder: (context) => _VocabularyEditDialog(entry: entry),
    );
    if (updated == null) {
      return;
    }

    await widget.repository.updateUserMeaningAndMemo(
      entryId: entry.id,
      userMeaning: updated.userMeaning,
      userMemo: updated.userMemo,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entriesFuture = _loadEntries();
    });
  }

  Future<void> _deleteEntry(VocabularyEntryView entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.expression),
        content: const Text('이 단어를 단어장에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await widget.repository.delete(entry.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _entriesFuture = _loadEntries();
    });
  }
}

final class _VocabularyEmptyState extends StatelessWidget {
  const _VocabularyEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '아직 단어장이 비어 있습니다',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

final class _VocabularyEntryTile extends StatelessWidget {
  const _VocabularyEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final VocabularyEntryView entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(entry.expression),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.meaningKo case final meaningKo?)
              Text(meaningKo, style: Theme.of(context).textTheme.bodyLarge),
            if (entry.sourceSentence case final sourceSentence?) ...[
              const SizedBox(height: 8),
              InkWell(
                key: const Key('vocabulary-source-preview'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showVocabularyContext(context, entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          key: const Key('vocabulary-source-preview-text'),
                          sourceSentence,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_full,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (entry.userMeaning case final userMeaning?) ...[
              const SizedBox(height: 8),
              Text(userMeaning),
            ],
            if (entry.userMemo case final userMemo?) ...[
              const SizedBox(height: 4),
              Text(userMemo),
            ],
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '단어 수정',
            icon: const Icon(Icons.edit_note),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: '단어 삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

void _showVocabularyContext(BuildContext context, VocabularyEntryView entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _VocabularyContextSheet(entry: entry),
  );
}

final class _VocabularyContextSheet extends StatelessWidget {
  const _VocabularyContextSheet({required this.entry});

  final VocabularyEntryView entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      key: const Key('vocabulary-context-sheet'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.expression, style: textTheme.titleLarge),
            if (entry.meaningKo case final meaningKo?) ...[
              const SizedBox(height: 8),
              Text(meaningKo, style: textTheme.bodyLarge),
            ],
            if (entry.contextBefore case final contextBefore?) ...[
              const SizedBox(height: 20),
              Text('Before', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(contextBefore),
            ],
            if (entry.sourceSentence case final sourceSentence?) ...[
              const SizedBox(height: 20),
              Text('Source', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(sourceSentence),
            ],
            if (entry.contextAfter case final contextAfter?) ...[
              const SizedBox(height: 20),
              Text('After', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(contextAfter),
            ],
          ],
        ),
      ),
    );
  }
}

final class _VocabularyEditDialog extends StatefulWidget {
  const _VocabularyEditDialog({required this.entry});

  final VocabularyEntryView entry;

  @override
  State<_VocabularyEditDialog> createState() => _VocabularyEditDialogState();
}

final class _VocabularyEditDialogState extends State<_VocabularyEditDialog> {
  late final TextEditingController _userMeaningController;
  late final TextEditingController _userMemoController;

  @override
  void initState() {
    super.initState();
    _userMeaningController = TextEditingController(
      text: widget.entry.userMeaning,
    );
    _userMemoController = TextEditingController(text: widget.entry.userMemo);
  }

  @override
  void dispose() {
    _userMeaningController.dispose();
    _userMemoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry.expression),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userMeaningController,
            decoration: const InputDecoration(labelText: '내 뜻'),
          ),
          TextField(
            controller: _userMemoController,
            decoration: const InputDecoration(labelText: '메모'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _VocabularyEditResult(
                userMeaning: _emptyToNull(_userMeaningController.text),
                userMemo: _emptyToNull(_userMemoController.text),
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

final class _VocabularyEditResult {
  const _VocabularyEditResult({
    required this.userMeaning,
    required this.userMemo,
  });

  final String? userMeaning;
  final String? userMemo;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
