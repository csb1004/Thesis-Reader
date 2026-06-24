import 'package:document_contract/document_contract.dart';
import 'package:flutter/material.dart';
import 'package:thesis_reader/features/reader/domain/reader_layout_engine.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';
import 'package:thesis_reader/features/reader/presentation/viewer_settings_sheet.dart';

final class ReaderProgress {
  const ReaderProgress({
    required this.documentId,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
  });

  final String documentId;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
}

final class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.documentId,
    this.package,
    this.initialSettings = const ReaderSettings(),
    this.onProgressChanged,
  });

  final String documentId;
  final DocumentPackage? package;
  final ReaderSettings initialSettings;
  final ValueChanged<ReaderProgress>? onProgressChanged;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

final class _ReaderScreenState extends State<ReaderScreen> {
  late ReaderSettings _settings;
  final _pageController = PageController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _scrollController.addListener(_handleScrollProgress);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScrollProgress)
      ..dispose();
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
            tooltip: '뷰어 설정',
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

        return switch (_settings.readingMode) {
          ReadingMode.page => _PageModeReader(
            package: package,
            layout: layout,
            settings: _settings,
            controller: _pageController,
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
            controller: _scrollController,
          ),
        };
      },
    );
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
                setSheetState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _handleScrollProgress() {
    if (_settings.readingMode != ReadingMode.scroll ||
        !_scrollController.hasClients) {
      return;
    }
    widget.onProgressChanged?.call(
      ReaderProgress(
        documentId: widget.documentId,
        scrollOffset: _scrollController.offset,
      ),
    );
  }
}

final class _PageModeReader extends StatelessWidget {
  const _PageModeReader({
    required this.package,
    required this.layout,
    required this.settings,
    required this.controller,
    required this.onPageChanged,
  });

  final DocumentPackage package;
  final ReaderLayoutResult layout;
  final ReaderSettings settings;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final blocksById = {for (final block in package.blocks) block.id: block};

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
                _ReaderBlock(block: block, settings: settings),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${page.pageNumber} / ${layout.pages.length}',
                style: Theme.of(context).textTheme.labelSmall,
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
    required this.controller,
  });

  final DocumentPackage package;
  final ReaderSettings settings;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
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
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ReaderBlock extends StatelessWidget {
  const _ReaderBlock({required this.block, required this.settings});

  final DocumentBlock block;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: 16 * settings.fontScale,
      height: settings.lineHeight,
    );

    if (block.text case final text?) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: textStyle),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.image_outlined),
        title: Text(block.assetId ?? block.kind.name),
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
