import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:document_contract/document_contract.dart';
import 'package:flutter/material.dart';
import 'package:thesis_reader/features/reader/domain/reader_layout_engine.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';
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
    this.package,
    this.initialSettings = const ReaderSettings(),
    this.onProgressChanged,
    this.volumeKeyEvents,
  });

  final String documentId;
  final DocumentPackage? package;
  final ReaderSettings initialSettings;
  final ValueChanged<ReaderProgress>? onProgressChanged;
  final Stream<VolumeKeyEvent>? volumeKeyEvents;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

final class _ReaderScreenState extends State<ReaderScreen> {
  late ReaderSettings _settings;
  final _pageController = PageController();
  final _scrollController = ScrollController();
  StreamSubscription<VolumeKeyEvent>? _volumeKeySubscription;
  var _isNativeVolumeKeyNavigationEnabled = false;
  var _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
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
      appBar: AppBar(
        title: Text(package?.metadata.title ?? 'Reader'),
        actions: [
          IconButton(
            tooltip: '리더 설정',
            icon: const Icon(Icons.tune),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: package == null ? const _EmptyReader() : _buildReader(package),
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
              onPageChanged: (pageIndex) {
                widget.onProgressChanged?.call(
                  ReaderProgress(
                    documentId: widget.documentId,
                    pageIndex: pageIndex,
                    pageCount: layout.pages.length,
                  ),
                );
              },
            ),
            ReadingMode.scroll => _ScrollModeReader(
              package: package,
              settings: _settings,
              readerTheme: readerTheme,
              controller: _scrollController,
              onAssetPressed: _openAsset,
              onScrollEnded: _handleScrollEnd,
            ),
          },
        );
      },
    );
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
}

final class _PageModeReader extends StatelessWidget {
  const _PageModeReader({
    required this.package,
    required this.layout,
    required this.settings,
    required this.readerTheme,
    required this.controller,
    required this.onAssetPressed,
    required this.onPageChanged,
  });

  final DocumentPackage package;
  final ReaderLayoutResult layout;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final PageController controller;
  final ValueChanged<DocumentAsset> onAssetPressed;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final blocksById = {for (final block in package.blocks) block.id: block};
    final assetsById = {for (final asset in package.assets) asset.id: asset};

    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: layout.pages.length,
      itemBuilder: (context, index) {
        final page = layout.pages[index];
        return ListView(
          padding: EdgeInsets.all(24 * settings.marginScale),
          children: [
            for (final blockId in page.blockIds)
              if (blocksById[blockId] case final block?)
                _ReaderBlock(
                  block: block,
                  settings: settings,
                  readerTheme: readerTheme,
                  assetsById: assetsById,
                  onAssetPressed: onAssetPressed,
                ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${page.pageNumber} / ${layout.pages.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: readerTheme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
      },
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
    required this.onScrollEnded,
  });

  final DocumentPackage package;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final ScrollController controller;
  final ValueChanged<DocumentAsset> onAssetPressed;
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
  });

  final DocumentBlock block;
  final ReaderSettings settings;
  final ReaderThemeData readerTheme;
  final Map<String, DocumentAsset> assetsById;
  final ValueChanged<DocumentAsset> onAssetPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: 16 * settings.fontScale,
      height: settings.lineHeight,
      color: readerTheme.textColor,
    );

    if (block.text case final text?) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _ReferenceSelectableText(
          text: text,
          referenceSpans: block.referenceSpans,
          assetsById: assetsById,
          style: textStyle,
          onAssetPressed: onAssetPressed,
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

final class _ReferenceSelectableText extends StatefulWidget {
  const _ReferenceSelectableText({
    required this.text,
    required this.referenceSpans,
    required this.assetsById,
    required this.style,
    required this.onAssetPressed,
  });

  final String text;
  final List<ReferenceSpan> referenceSpans;
  final Map<String, DocumentAsset> assetsById;
  final TextStyle style;
  final ValueChanged<DocumentAsset> onAssetPressed;

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
      return SelectableText(widget.text, style: widget.style);
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
                    Text(asset.kind.name, style: textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '자산 미리보기를 사용할 수 없습니다.\n${asset.relativePath}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
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

final class _EmptyReader extends StatelessWidget {
  const _EmptyReader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('읽을 문서가 없습니다'));
  }
}
