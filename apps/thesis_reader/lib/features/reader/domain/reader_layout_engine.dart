import 'dart:math' as math;

import 'package:document_contract/document_contract.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';

final class ReaderViewport {
  const ReaderViewport({required this.width, required this.height});

  final double width;
  final double height;
}

final class ReaderPage {
  const ReaderPage({
    required this.pageNumber,
    required this.blockIds,
    required this.estimatedLineCount,
  });

  final int pageNumber;
  final List<String> blockIds;
  final int estimatedLineCount;
}

final class ReaderLayoutResult {
  const ReaderLayoutResult({
    required this.orderedBlockIds,
    required this.pages,
    required this.charsPerLine,
    required this.linesPerPage,
  });

  final List<String> orderedBlockIds;
  final List<ReaderPage> pages;
  final int charsPerLine;
  final int linesPerPage;
}

final class ReaderLayoutEngine {
  const ReaderLayoutEngine._();

  static ReaderLayoutResult paginate(
    DocumentPackage package,
    ReaderSettings settings,
    ReaderViewport viewport,
  ) {
    final metrics = _ReaderMetrics.from(settings, viewport);
    final pages = <ReaderPage>[];
    var currentBlockIds = <String>[];
    var currentLineCount = 0;

    void flushPage() {
      if (currentBlockIds.isEmpty) {
        return;
      }
      pages.add(
        ReaderPage(
          pageNumber: pages.length + 1,
          blockIds: List.unmodifiable(currentBlockIds),
          estimatedLineCount: currentLineCount,
        ),
      );
      currentBlockIds = <String>[];
      currentLineCount = 0;
    }

    for (final block in package.blocks) {
      final blockLines = metrics.estimateBlockLines(block);
      if (currentBlockIds.isNotEmpty &&
          currentLineCount + blockLines > metrics.linesPerPage) {
        flushPage();
      }
      currentBlockIds.add(block.id);
      currentLineCount += blockLines;
    }
    flushPage();

    return ReaderLayoutResult(
      orderedBlockIds: List.unmodifiable(
        package.blocks.map((block) => block.id),
      ),
      pages: List.unmodifiable(pages),
      charsPerLine: metrics.charsPerLine,
      linesPerPage: metrics.linesPerPage,
    );
  }
}

final class _ReaderMetrics {
  const _ReaderMetrics({
    required this.charsPerLine,
    required this.linesPerPage,
  });

  factory _ReaderMetrics.from(
    ReaderSettings settings,
    ReaderViewport viewport,
  ) {
    final fontSize = 16 * settings.fontScale;
    final margin = 24 * settings.marginScale;
    final contentWidth = math.max(1, viewport.width - margin * 2);
    final contentHeight = math.max(fontSize, viewport.height - margin * 2);
    final averageCharWidth = fontSize * 0.25;
    final effectiveLineHeight = math.max(1, fontSize * settings.lineHeight);

    return _ReaderMetrics(
      charsPerLine: math.max(8, (contentWidth / averageCharWidth).floor()),
      linesPerPage: math.max(1, (contentHeight / effectiveLineHeight).floor()),
    );
  }

  final int charsPerLine;
  final int linesPerPage;

  int estimateBlockLines(DocumentBlock block) {
    if (block.text case final text?) {
      final normalized = text.trim();
      if (normalized.isEmpty) {
        return 1;
      }
      return math.max(1, (normalized.length / charsPerLine).ceil()) + 1;
    }

    return switch (block.kind) {
      BlockKind.figure || BlockKind.table || BlockKind.equation => 8,
      _ => 2,
    };
  }
}
