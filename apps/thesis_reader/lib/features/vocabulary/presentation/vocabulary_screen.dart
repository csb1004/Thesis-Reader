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
      appBar: AppBar(title: const Text('Vocabulary')),
      body: FutureBuilder<List<VocabularyEntryView>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Vocabulary could not be loaded'));
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
}

final class _VocabularyEmptyState extends StatelessWidget {
  const _VocabularyEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No vocabulary yet',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

final class _VocabularyEntryTile extends StatelessWidget {
  const _VocabularyEntryTile({required this.entry, required this.onEdit});

  final VocabularyEntryView entry;
  final VoidCallback onEdit;

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
              Text(sourceSentence),
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
      trailing: IconButton(
        tooltip: 'Edit vocabulary note',
        icon: const Icon(Icons.edit_note),
        onPressed: onEdit,
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
            decoration: const InputDecoration(labelText: 'Your meaning'),
          ),
          TextField(
            controller: _userMemoController,
            decoration: const InputDecoration(labelText: 'Memo'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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
          child: const Text('Save'),
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
