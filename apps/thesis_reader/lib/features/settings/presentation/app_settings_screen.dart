import 'package:flutter/material.dart';

enum TranslationModePreference { simple, openAi }

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    this.initialOpenAiApiKey,
    this.initialTranslationMode = TranslationModePreference.simple,
    this.onSaveOpenAiApiKey,
    this.onClearOpenAiApiKey,
    this.onTranslationModeChanged,
  });

  final String? initialOpenAiApiKey;
  final TranslationModePreference initialTranslationMode;
  final Future<void> Function(String apiKey)? onSaveOpenAiApiKey;
  final Future<void> Function()? onClearOpenAiApiKey;
  final ValueChanged<TranslationModePreference>? onTranslationModeChanged;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final TextEditingController _openAiApiKeyController;
  late TranslationModePreference _translationMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _openAiApiKeyController = TextEditingController(
      text: widget.initialOpenAiApiKey ?? '',
    );
    _translationMode = widget.initialTranslationMode;
  }

  @override
  void dispose() {
    _openAiApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('OpenAI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _openAiApiKeyController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'OpenAI API 키',
              hintText: 'sk-...',
              prefixIcon: Icon(Icons.key),
            ),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveOpenAiKey,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('저장'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _isSaving ? null : _clearOpenAiKey,
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('번역', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<TranslationModePreference>(
            segments: const [
              ButtonSegment(
                value: TranslationModePreference.simple,
                icon: Icon(Icons.translate),
                label: Text('단순 번역'),
              ),
              ButtonSegment(
                value: TranslationModePreference.openAi,
                icon: Icon(Icons.auto_awesome),
                label: Text('OpenAI'),
              ),
            ],
            selected: {_translationMode},
            onSelectionChanged: (selection) {
              final value = selection.single;
              setState(() => _translationMode = value);
              widget.onTranslationModeChanged?.call(value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            _translationMode == TranslationModePreference.simple
                ? '빠르게 기본 번역을 사용합니다.'
                : 'OpenAI 토큰으로 문맥 번역을 우선 사용합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _saveOpenAiKey() async {
    final key = _openAiApiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('키를 입력해 주세요');
      return;
    }

    await _runSavingAction(() async {
      await widget.onSaveOpenAiApiKey?.call(key);
      _showSnackBar('OpenAI 키를 저장했습니다');
    });
  }

  Future<void> _clearOpenAiKey() async {
    _openAiApiKeyController.clear();
    await _runSavingAction(() async {
      await widget.onClearOpenAiApiKey?.call();
      _showSnackBar('OpenAI 키를 삭제했습니다');
    });
  }

  Future<void> _runSavingAction(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
