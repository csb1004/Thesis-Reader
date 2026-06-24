import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:document_contract/document_contract.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:thesis_reader/features/ai/data/openai_client.dart';
import 'package:thesis_reader/features/ai/data/openai_key_store.dart';
import 'package:thesis_reader/features/ai/data/simple_translation_client.dart';
import 'package:thesis_reader/features/ai/domain/summary_service.dart';
import 'package:thesis_reader/features/ai/domain/translation_service.dart';
import 'package:thesis_reader/features/reader/domain/reader_layout_engine.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';
import 'package:thesis_reader/features/vocabulary/data/vocabulary_repository.dart';
import 'package:thesis_reader/features/vocabulary/presentation/vocabulary_screen.dart';
import 'package:thesis_reader/shared/platform/volume_key_channel.dart';

final class ReaderProgress {
  const ReaderProgress({
    required this.documentId,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.scrollProgress,
  });

  final String documentId;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? scrollProgress;
}

final class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.documentId,
    this.displayTitle,
    this.package,
    this.originalPdfPath,
    this.openAiKeyStore,
    this.simpleTranslationClient,
    this.translationService,
    this.summaryService,
    this.vocabularyRepository,
    this.initialPageIndex,
    this.initialScrollProgress,
    this.initialSettings = const ReaderSettings(),
    this.onProgressChanged,
    this.onSettingsChanged,
    this.volumeKeyEvents,
  });

  final String documentId;
  final String? displayTitle;
  final DocumentPackage? package;
  final String? originalPdfPath;
  final OpenAiKeyStore? openAiKeyStore;
  final SimpleTranslationClient? simpleTranslationClient;
  final TranslationService? translationService;
  final SummaryService? summaryService;
  final VocabularyRepository? vocabularyRepository;
  final int? initialPageIndex;
  final double? initialScrollProgress;
  final ReaderSettings initialSettings;
  final ValueChanged<ReaderProgress>? onProgressChanged;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final Stream<VolumeKeyEvent>? volumeKeyEvents;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

final class _ReaderScreenState extends State<ReaderScreen> {
  late ReaderSettings _settings;
  late final PageController _pageController;
  final _scrollController = ScrollController();
  StreamSubscription<VolumeKeyEvent>? _volumeKeySubscription;
  var _isNativeVolumeKeyNavigationEnabled = false;
  var _pageCount = 0;
  var _currentPageIndex = 0;
  var _isChromeVisible = false;
  Offset? _chromePointerStart;
  ReaderLayoutResult? _currentLayout;
  DocumentPackage? _currentPackage;
  var _didRestoreScroll = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _currentPageIndex = widget.initialPageIndex ?? 0;
    _pageController = PageController(initialPage: _currentPageIndex);
    _subscribeToVolumeKeys();
    _syncNativeVolumeKeyNavigation();
  }

  @override
  void didUpdateWidget(covariant ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeKeyEvents != widget.volumeKeyEvents) {
      _volumeKeySubscription?.cancel();
      _subscribeToVolumeKeys();
    }
    if (oldWidget.package != widget.package) {
      _syncNativeVolumeKeyNavigation();
    }
  }

  @override
  void dispose() {
    if (_isNativeVolumeKeyNavigationEnabled) {
      unawaited(VolumeKeyChannel.instance.setVolumeKeyNavigationEnabled(false));
      _isNativeVolumeKeyNavigationEnabled = false;
    }
    _volumeKeySubscription?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;

    return Scaffold(
      appBar: package == null ? AppBar(
        title: Text(widget.displayTitle ?? package?.metadata.title ?? '리더'),
        actions: [
          if (package != null)
            IconButton(
              tooltip: '현재 페이지 요약',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: _summarizeCurrentPage,
            ),
          if (package != null)
            IconButton(
              tooltip: '단어장',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: _openVocabulary,
            ),
          if (package != null)
            IconButton(
              tooltip: '보기 설정',
              icon: const Icon(Icons.tune),
              onPressed: _showSettings,
            ),
        ],
      ) : null,
      body: package == null
          ? _OriginalPdfFallback(path: widget.originalPdfPath)
          : Stack(
              children: [
                Listener(
                  key: const Key('reader-menu-toggle-zone'),
                  onPointerDown: _handleChromePointerDown,
                  onPointerUp: _handleChromePointerUp,
                  child: _buildReader(package),
                ),
                if (_isChromeVisible)
                  _ReaderTopChrome(
                    title: widget.displayTitle ?? package.metadata.title,
                    onSummarize: _summarizeCurrentPage,
                    onVocabulary: _openVocabulary,
                    onSettings: _showSettings,
                  ),
                if (_isChromeVisible &&
                    _settings.readingMode == ReadingMode.page)
                  _ReaderPageSlider(
                    pageIndex: _currentPageIndex,
                    pageCount: _pageCount,
                    onChanged: _jumpToPage,
                  ),
              ],
            ),
    );
  }

  Widget _buildReader(DocumentPackage package) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ReaderLayoutEngine.paginate(
          package,
          _settings,
          ReaderViewport(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        );
        _pageCount = layout.pages.length;
        _currentLayout = layout;
        _currentPackage = package;
        _restoreScrollPositionIfNeeded();
        final readerTheme = ReaderThemeCatalog.resolve(_settings.themeId);

        return ColoredBox(
          key: const Key('reader-theme-background'),
          color: readerTheme.backgroundColor,
          child: switch (_settings.readingMode) {
            ReadingMode.page => _PageModeReader(
              package: package,
              layout: layout,
              settings: _settings,
              readerTheme: readerTheme,
              controller: _pageController,
              onAssetPressed: _openAsset,
              onSimpleTranslateSelection: _simpleTranslateSelection,
              onTranslateSelection: _translateSelection,
              onAddVocabulary: _addSelectedVocabulary,
              onPageChanged: _handlePageChanged,
            ),
            ReadingMode.scroll => _ScrollModeReader(
              package: package,
              settings: _settings,
              readerTheme: readerTheme,
              controller: _scrollController,
              onAssetPressed: _openAsset,
              onSimpleTranslateSelection: _simpleTranslateSelection,
              onTranslateSelection: _translateSelection,
              onAddVocabulary: _addSelectedVocabulary,
              onScrollEnded: _handleScrollEnd,
            ),
          },
        );
      },
    );
  }

  void _handleChromePointerDown(PointerDownEvent event) {
    _chromePointerStart = event.position;
  }

  void _handleChromePointerUp(PointerUpEvent event) {
    final start = _chromePointerStart;
    _chromePointerStart = null;
    if (start == null || (event.position - start).distance > 12) {
      return;
    }
    setState(() => _isChromeVisible = !_isChromeVisible);
  }

  void _handlePageChanged(int pageIndex) {
    setState(() => _currentPageIndex = pageIndex);
    widget.onProgressChanged?.call(
      ReaderProgress(
        documentId: widget.documentId,
        pageIndex: pageIndex,
        pageCount: _pageCount,
      ),
    );
  }

  void _jumpToPage(double value) {
    if (!_pageController.hasClients || _pageCount <= 0) {
      return;
    }
    final pageIndex = value.round().clamp(0, _pageCount - 1);
    if (pageIndex == _currentPageIndex) {
      return;
    }
    _pageController.jumpToPage(pageIndex);
    _handlePageChanged(pageIndex);
  }

  void _handleScrollEnd(ScrollMetrics metrics) {
    if (_settings.readingMode != ReadingMode.scroll) {
      return;
    }

    final scrollProgress = metrics.maxScrollExtent <= 0
        ? 0.0
        : (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);

    widget.onProgressChanged?.call(
      ReaderProgress(
        documentId: widget.documentId,
        scrollOffset: metrics.pixels,
        scrollProgress: scrollProgress,
      ),
    );
  }

  void _subscribeToVolumeKeys() {
    _volumeKeySubscription =
        (widget.volumeKeyEvents ?? VolumeKeyChannel.instance.events).listen(
          _handleVolumeKeyEvent,
        );
  }

  void _syncNativeVolumeKeyNavigation() {
    final shouldEnable =
        mounted &&
        widget.package != null &&
        _settings.readingMode == ReadingMode.page;
    if (shouldEnable == _isNativeVolumeKeyNavigationEnabled) {
      return;
    }

    _isNativeVolumeKeyNavigationEnabled = shouldEnable;
    unawaited(
      VolumeKeyChannel.instance.setVolumeKeyNavigationEnabled(shouldEnable),
    );
  }

  void _handleVolumeKeyEvent(VolumeKeyEvent event) {
    if (_settings.readingMode != ReadingMode.page ||
        !_pageController.hasClients ||
        _pageCount <= 0) {
      return;
    }

    final currentPage = (_pageController.page ?? 0).round();
    final pageDelta = switch (event) {
      VolumeKeyEvent.next => 1,
      VolumeKeyEvent.previous => -1,
    };
    final targetPage = (currentPage + pageDelta).clamp(0, _pageCount - 1);

    if (targetPage == currentPage) {
      return;
    }

    _pageController.jumpToPage(targetPage);
  }

  void _restoreScrollPositionIfNeeded() {
    if (_didRestoreScroll ||
        _settings.readingMode != ReadingMode.scroll ||
        widget.initialScrollProgress == null) {
      return;
    }

    _didRestoreScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final progress = widget.initialScrollProgress!.clamp(0.0, 1.0);
      _scrollController.jumpTo(position.maxScrollExtent * progress);
    });
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ViewerSettingsSheet(
              settings: _settings,
              onChanged: (settings) {
                setState(() => _settings = settings);
                widget.onSettingsChanged?.call(settings);
                _syncNativeVolumeKeyNavigation();
                setSheetState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _openAsset(DocumentAsset asset) {
    switch (_settings.assetOpenMode) {
      case AssetOpenMode.bottomSheet:
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => _AssetViewerSheet(asset: asset),
        );
      case AssetOpenMode.fullScreen:
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _AssetViewerPage(asset: asset),
          ),
        );
    }
  }

  void _openVocabulary() {
    final repository = widget.vocabularyRepository;
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('단어장을 아직 사용할 수 없습니다.')));
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => VocabularyScreen(
          documentId: widget.documentId,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _translateSelection(
    String selectedText,
    String sourceSentence,
  ) async {
    final expression = selectedText.trim();
    if (expression.isEmpty) {
      return;
    }

    final service = widget.translationService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI 토큰 설정 후 번역할 수 있습니다.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$expression 번역 중...')));
    final result = _isSingleExpression(expression)
        ? await service.explainWord(
            expression: expression,
            sourceSentence: sourceSentence,
          )
        : await service.translateSelection(selectedText: expression);

    if (!mounted) {
      return;
    }

    switch (result) {
      case AiSuccess(value: final action):
        if (action.shouldAutoSave) {
          await _saveVocabulary(action);
        }
        if (!mounted) {
          return;
        }
        await _showTranslationResult(action, sourceSentence: sourceSentence);
      case AiFailure(kind: AiFailureKind.missingKey):
        await _showOpenAiTokenDialog();
      case AiFailure(message: final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('번역 실패: $message')));
    }
  }

  Future<void> _simpleTranslateSelection(
    String selectedText,
    String sourceSentence,
  ) async {
    final expression = selectedText.trim();
    if (expression.isEmpty) {
      return;
    }

    final client = widget.simpleTranslationClient;
    if (client == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('간단 번역을 아직 사용할 수 없습니다.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$expression 간단 번역 중...')));
    try {
      final translated = await client.translateToKorean(expression);
      if (!mounted) {
        return;
      }
      await _showTranslationResult(
        TranslationAction(
          type: TranslationActionType.selectionTranslation,
          sourceText: expression,
          koreanText: translated,
          shouldAutoSave: false,
          canAddToVocabulary: true,
        ),
        sourceSentence: sourceSentence,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('간단 번역 실패: $error')));
    }
  }

  Future<void> _addSelectedVocabulary(
    String selectedText,
    String sourceSentence,
  ) async {
    final expression = selectedText.trim();
    if (expression.isEmpty) {
      return;
    }

    await _saveVocabulary(
      TranslationAction(
        type: TranslationActionType.selectionTranslation,
        sourceText: expression,
        koreanText: '',
        shouldAutoSave: false,
        canAddToVocabulary: true,
      ),
      sourceSentence: sourceSentence,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$expression 단어장에 저장됨')));
  }

  Future<void> _saveVocabulary(
    TranslationAction action, {
    String? sourceSentence,
  }) async {
    final repository = widget.vocabularyRepository;
    if (repository == null) {
      return;
    }

    await repository.upsert(
      VocabularyDraft(
        documentId: widget.documentId,
        expression: action.sourceText,
        meaningKo: action.koreanText.trim().isEmpty ? null : action.koreanText,
        sourceSentence: sourceSentence ?? action.sourceText,
        contextBefore: null,
        contextAfter: null,
      ),
    );
  }

  Future<void> _showTranslationResult(
    TranslationAction action, {
    String? sourceSentence,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.sourceText,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SelectableText(action.koreanText),
                if (!action.shouldAutoSave && action.canAddToVocabulary) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        unawaited(
                          _saveVocabulary(
                            action,
                            sourceSentence: sourceSentence,
                          ),
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${action.sourceText} 단어장에 저장됨'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('단어장에 추가'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOpenAiTokenDialog() async {
    final keyStore = widget.openAiKeyStore;
    if (keyStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI 토큰 설정 후 번역할 수 있습니다.')),
      );
      return;
    }

    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenAI 토큰 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API key',
            hintText: 'sk-...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (token == null || token.isEmpty) {
      return;
    }

    await keyStore.writeKey(token);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OpenAI 토큰을 저장했습니다. 다시 번역해 주세요.')),
    );
  }

  Future<void> _summarizeCurrentPage() async {
    final service = widget.summaryService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI 토큰 설정 후 요약할 수 있습니다.')),
      );
      return;
    }

    final package = _currentPackage;
    final layout = _currentLayout;
    if (package == null || layout == null || layout.pages.isEmpty) {
      return;
    }

    final blocksById = {for (final block in package.blocks) block.id: block};
    final page =
        layout.pages[_currentPageIndex.clamp(0, layout.pages.length - 1)];
    final pageText = page.blockIds
        .map((id) => blocksById[id]?.text)
        .whereType<String>()
        .join('\n\n')
        .trim();
    if (pageText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요약할 본문이 없습니다.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${page.pageNumber}페이지 요약 중...')));
    final result = await service.summarizeRange(
      paperText: pageText,
      sectionTitle: package.metadata.title,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case AiSuccess(value: final summary):
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${page.pageNumber}페이지 요약',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(summary.summary),
                ],
              ),
            ),
          ),
        );
      case AiFailure(kind: AiFailureKind.missingKey):
        await _showOpenAiTokenDialog();
      case AiFailure(message: final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('요약 실패: $message')));
    }
  }
}

final class _PageModeReader extends StatelessWidget {
  const _PageModeReader({
    required this.package,
    required this.layout,
    required this.settings,
    required this.readerTheme,
    required this.controller,
    required this.onAssetPressed,
    required this.onSimpleTranslateSelection,
    required this.onTranslateSelection,
    required this.onAddVocabulary,
    required this.onPageChanged,
  });

  final DocumentPackage package;
  final ReaderLayoutResult layout;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final PageController controller;
  final ValueChanged<DocumentAsset> onAssetPressed;
  final _SelectionAction onSimpleTranslateSelection;
  final _SelectionAction onTranslateSelection;
  final _SelectionAction onAddVocabulary;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final blocksById = {for (final block in package.blocks) block.id: block};
    final assetsById = {for (final asset in package.assets) asset.id: asset};
    final footerHeight = 56.0 * settings.bottomMarginScale;

    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: layout.pages.length,
      itemBuilder: (context, index) {
        final page = layout.pages[index];
        final margin = 24 * settings.marginScale;
        return Padding(
          padding: EdgeInsets.fromLTRB(margin, margin, margin, margin),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final blockId in page.blockIds)
                          if (blocksById[blockId] case final block?)
                            _ReaderBlock(
                              block: block,
                              settings: settings,
                              readerTheme: readerTheme,
                              assetsById: assetsById,
                              onAssetPressed: onAssetPressed,
                              onSimpleTranslateSelection:
                                  onSimpleTranslateSelection,
                              onTranslateSelection: onTranslateSelection,
                              onAddVocabulary: onAddVocabulary,
                            ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: footerHeight),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _ReaderPageSlider extends StatelessWidget {
  const _ReaderPageSlider({
    required this.pageIndex,
    required this.pageCount,
    required this.onChanged,
  });

  final int pageIndex;
  final int pageCount;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxPage = (pageCount - 1).clamp(0, pageCount);

    return Positioned(
      left: 24,
      right: 24,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Slider(
              key: const Key('reader-page-slider'),
              value: pageIndex.clamp(0, maxPage).toDouble(),
              min: 0,
              max: maxPage.toDouble(),
              divisions: maxPage == 0 ? null : maxPage,
              onChanged: pageCount <= 1 ? null : onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

final class _ReaderTopChrome extends StatelessWidget {
  const _ReaderTopChrome({
    required this.title,
    required this.onSummarize,
    required this.onVocabulary,
    required this.onSettings,
  });

  final String title;
  final VoidCallback onSummarize;
  final VoidCallback onVocabulary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: NavigationToolbar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              middle: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '현재 페이지 요약',
                    icon: const Icon(Icons.summarize_outlined),
                    onPressed: onSummarize,
                  ),
                  IconButton(
                    tooltip: '단어장',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: onVocabulary,
                  ),
                  IconButton(
                    tooltip: '보기 설정',
                    icon: const Icon(Icons.tune),
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ScrollModeReader extends StatelessWidget {
  const _ScrollModeReader({
    required this.package,
    required this.settings,
    required this.readerTheme,
    required this.controller,
    required this.onAssetPressed,
    required this.onSimpleTranslateSelection,
    required this.onTranslateSelection,
    required this.onAddVocabulary,
    required this.onScrollEnded,
  });

  final DocumentPackage package;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final ScrollController controller;
  final ValueChanged<DocumentAsset> onAssetPressed;
  final _SelectionAction onSimpleTranslateSelection;
  final _SelectionAction onTranslateSelection;
  final _SelectionAction onAddVocabulary;
  final ValueChanged<ScrollMetrics> onScrollEnded;

  @override
  Widget build(BuildContext context) {
    final assetsById = {for (final asset in package.assets) asset.id: asset};

    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        onScrollEnded(notification.metrics);
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(24 * settings.marginScale),
            sliver: SliverList.builder(
              itemCount: package.blocks.length,
              itemBuilder: (context, index) {
                return _ReaderBlock(
                  block: package.blocks[index],
                  settings: settings,
                  readerTheme: readerTheme,
                  assetsById: assetsById,
                  onAssetPressed: onAssetPressed,
                  onSimpleTranslateSelection: onSimpleTranslateSelection,
                  onTranslateSelection: onTranslateSelection,
                  onAddVocabulary: onAddVocabulary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _ReaderBlock extends StatelessWidget {
  const _ReaderBlock({
    required this.block,
    required this.settings,
    required this.readerTheme,
    required this.assetsById,
    required this.onAssetPressed,
    required this.onSimpleTranslateSelection,
    required this.onTranslateSelection,
    required this.onAddVocabulary,
  });

  final DocumentBlock block;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final Map<String, DocumentAsset> assetsById;
  final ValueChanged<DocumentAsset> onAssetPressed;
  final _SelectionAction onSimpleTranslateSelection;
  final _SelectionAction onTranslateSelection;
  final _SelectionAction onAddVocabulary;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: 16 * settings.fontScale,
      height: settings.lineHeight,
      color: readerTheme.textColor,
    );

    if (block.text case final text?) {
      final isHeading = _looksLikeHeading(text);
      return Padding(
        padding: EdgeInsets.only(bottom: isHeading ? 12 : 16),
        child: _ReferenceSelectableText(
          text: text,
          referenceSpans: block.referenceSpans,
          assetsById: assetsById,
          style: isHeading
              ? textStyle.copyWith(
                  fontSize: (textStyle.fontSize ?? 16) * 1.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                )
              : textStyle,
          onAssetPressed: onAssetPressed,
          onSimpleTranslateSelection: onSimpleTranslateSelection,
          onTranslateSelection: onTranslateSelection,
          onAddVocabulary: onAddVocabulary,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.image_outlined),
        iconColor: readerTheme.textColor,
        title: Text(
          block.assetId ?? block.kind.name,
          style: TextStyle(color: readerTheme.textColor),
        ),
      ),
    );
  }
}

bool _looksLikeHeading(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > 80) {
    return false;
  }
  if (RegExp(r'^\d+(\.\d+)*$').hasMatch(trimmed)) {
    return true;
  }
  if (trimmed.contains(RegExp(r'[.!?]'))) {
    return false;
  }
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length == 1) {
    return trimmed[0] == trimmed[0].toUpperCase();
  }
  return words.length <= 8 &&
      words.every((word) => word.isEmpty || word[0] == word[0].toUpperCase());
}

final class _ReferenceSelectableText extends StatefulWidget {
  const _ReferenceSelectableText({
    required this.text,
    required this.referenceSpans,
    required this.assetsById,
    required this.style,
    required this.onAssetPressed,
    required this.onSimpleTranslateSelection,
    required this.onTranslateSelection,
    required this.onAddVocabulary,
  });

  final String text;
  final List<ReferenceSpan> referenceSpans;
  final Map<String, DocumentAsset> assetsById;
  final TextStyle style;
  final ValueChanged<DocumentAsset> onAssetPressed;
  final _SelectionAction onSimpleTranslateSelection;
  final _SelectionAction onTranslateSelection;
  final _SelectionAction onAddVocabulary;

  @override
  State<_ReferenceSelectableText> createState() =>
      _ReferenceSelectableTextState();
}

final class _ReferenceSelectableTextState
    extends State<_ReferenceSelectableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final existingTargetSpans = [
      for (final span in widget.referenceSpans)
        if (widget.assetsById.containsKey(span.targetAssetId)) span,
    ];
    final validSpans = _validReferenceSpans(widget.text, existingTargetSpans);

    if (validSpans.isEmpty) {
      return SelectableText(
        widget.text,
        style: widget.style,
        contextMenuBuilder: _buildContextMenu,
      );
    }

    var offset = 0;
    final children = <InlineSpan>[];
    final accentColor = Theme.of(context).colorScheme.primary;

    for (final span in validSpans) {
      final asset = widget.assetsById[span.targetAssetId]!;
      if (offset < span.start) {
        children.add(TextSpan(text: widget.text.substring(offset, span.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onAssetPressed(asset);
      _recognizers.add(recognizer);

      children.add(
        TextSpan(
          text: widget.text.substring(span.start, span.end),
          style: TextStyle(
            color: accentColor,
            decoration: TextDecoration.underline,
            decorationColor: accentColor,
            decorationThickness: 1.5,
          ),
          recognizer: recognizer,
        ),
      );
      offset = span.end;
    }

    if (offset < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(offset)));
    }

    return SelectableText.rich(
      TextSpan(style: widget.style, children: children),
      contextMenuBuilder: _buildContextMenu,
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final value = editableTextState.textEditingValue;
    final selectedText = value.selection.textInside(value.text).trim();
    final buttonItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: '간단 번역',
        onPressed: selectedText.isEmpty
            ? null
            : () {
                editableTextState.hideToolbar();
                unawaited(
                  widget.onSimpleTranslateSelection(selectedText, widget.text),
                );
              },
      ),
      ContextMenuButtonItem(
        label: 'OpenAI 번역',
        onPressed: selectedText.isEmpty
            ? null
            : () {
                editableTextState.hideToolbar();
                unawaited(
                  widget.onTranslateSelection(selectedText, widget.text),
                );
              },
      ),
      ContextMenuButtonItem(
        label: '단어장에 추가',
        onPressed: selectedText.isEmpty
            ? null
            : () {
                editableTextState.hideToolbar();
                unawaited(widget.onAddVocabulary(selectedText, widget.text));
              },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

List<ReferenceSpan> _validReferenceSpans(
  String text,
  List<ReferenceSpan> referenceSpans,
) {
  var cursor = 0;
  final validSpans = <ReferenceSpan>[];
  final sortedSpans = [...referenceSpans]
    ..sort((a, b) {
      final startComparison = a.start.compareTo(b.start);
      if (startComparison != 0) {
        return startComparison;
      }
      return a.end.compareTo(b.end);
    });

  for (final span in sortedSpans) {
    if (span.start < cursor ||
        span.start < 0 ||
        span.end <= span.start ||
        span.end > text.length) {
      continue;
    }

    validSpans.add(span);
    cursor = span.end;
  }

  return validSpans;
}

final class _AssetViewerSheet extends StatelessWidget {
  const _AssetViewerSheet({required this.asset});

  final DocumentAsset asset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('reader-asset-bottom-sheet'),
      child: _AssetDetailPanel(asset: asset),
    );
  }
}

final class _AssetViewerPage extends StatelessWidget {
  const _AssetViewerPage({required this.asset});

  final DocumentAsset asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('reader-asset-fullscreen'),
      appBar: AppBar(title: Text(asset.label)),
      body: SafeArea(child: _AssetDetailPanel(asset: asset)),
    );
  }
}

final class _AssetDetailPanel extends StatelessWidget {
  const _AssetDetailPanel({required this.asset});

  final DocumentAsset asset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.label, style: textTheme.titleLarge),
                    Text(
                      _assetKindLabel(asset.kind),
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AssetPreview(asset: asset),
          if (asset.caption case final caption?) ...[
            const SizedBox(height: 16),
            Text(caption, style: textTheme.bodyLarge),
          ],
          const SizedBox(height: 12),
          SelectableText(asset.relativePath, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

final class _AssetPreview extends StatelessWidget {
  const _AssetPreview({required this.asset});

  final DocumentAsset asset;

  @override
  Widget build(BuildContext context) {
    final path = asset.relativePath;
    final extension = _fileExtension(path);
    final isImage = const {
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
    }.contains(extension);
    final file = File(path);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 280,
        child: isImage && file.existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '그림 미리보기를 사용할 수 없습니다.\n$path',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      ),
    );
  }
}

final class _OriginalPdfFallback extends StatefulWidget {
  const _OriginalPdfFallback({required this.path});

  final String? path;

  @override
  State<_OriginalPdfFallback> createState() => _OriginalPdfFallbackState();
}

final class _OriginalPdfFallbackState extends State<_OriginalPdfFallback> {
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    final path = widget.path;
    if (path != null && File(path).existsSync()) {
      _controller = PdfControllerPinch(document: PdfDocument.openFile(path));
    }
  }

  @override
  void didUpdateWidget(covariant _OriginalPdfFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      final path = widget.path;
      _controller = path != null && File(path).existsSync()
          ? PdfControllerPinch(document: PdfDocument.openFile(path))
          : null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: Text('읽을 문서가 없습니다'));
    }

    return PdfViewPinch(controller: controller);
  }
}

String _fileExtension(String path) {
  final index = path.lastIndexOf('.');
  return index == -1 ? '' : path.substring(index).toLowerCase();
}

String _assetKindLabel(AssetKind kind) {
  return switch (kind) {
    AssetKind.figure => '그림',
    AssetKind.table => '표',
    AssetKind.equation => '수식',
    AssetKind.pageRegion => '페이지 영역',
    AssetKind.thumbnail => '미리보기',
  };
}

bool _isSingleExpression(String expression) {
  return expression.trim().split(RegExp(r'\s+')).length == 1;
}

typedef _SelectionAction =
    Future<void> Function(String selectedText, String sourceSentence);
