import 'dart:math' as math;

import 'package:document_contract/document_contract.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';

const _pageBottomGuardLines = 2;
const _headingFollowerReserveLines = 3;

final class ReaderViewport {
  const ReaderViewport({
    required this.width,
    required this.height,
    this.topReserve = 0,
    this.bottomReserve = 0,
  });

  final double width;
  final double height;
  final double topReserve;
  final double bottomReserve;
}

final class ReaderPage {
  const ReaderPage({
    required this.pageNumber,
    required this.blockIds,
    required this.items,
    required this.estimatedLineCount,
  });

  final int pageNumber;
  final List<String> blockIds;
  final List<ReaderPageItem> items;
  final int estimatedLineCount;
}

final class ReaderPageItem {
  const ReaderPageItem({
    required this.blockId,
    required this.estimatedLineCount,
    this.text,
    this.startOffset,
    this.endOffset,
    this.continuesFromPrevious = false,
    this.continuesAfter = false,
  });

  final String blockId;
  final int estimatedLineCount;
  final String? text;
  final int? startOffset;
  final int? endOffset;
  final bool continuesFromPrevious;
  final bool continuesAfter;
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
    var currentItems = <ReaderPageItem>[];
    var currentLineCount = 0;

    void flushPage() {
      if (currentItems.isEmpty) {
        return;
      }
      pages.add(
        ReaderPage(
          pageNumber: pages.length + 1,
          blockIds: List.unmodifiable(_uniqueBlockIds(currentItems)),
          items: List.unmodifiable(currentItems),
          estimatedLineCount: currentLineCount,
        ),
      );
      currentItems = <ReaderPageItem>[];
      currentLineCount = 0;
    }

    void addItem(ReaderPageItem item) {
      if (currentItems.isNotEmpty &&
          currentLineCount + item.estimatedLineCount > metrics.linesPerPage) {
        flushPage();
      }
      currentItems.add(item);
      currentLineCount += item.estimatedLineCount;
    }

    final blocks = package.blocks;
    for (var index = 0; index < blocks.length; index += 1) {
      final block = blocks[index];
      final isHeading = _looksLikeHeading(block.text);
      if (isHeading &&
          currentItems.isNotEmpty &&
          currentLineCount +
                  metrics.estimateBlockLines(block) +
                  _followerReserveLines(blocks, index, metrics) >
              metrics.linesPerPage) {
        flushPage();
      }

      if (block.text case final text?) {
        final lines = metrics.wrapText(text);
        var lineIndex = 0;
        while (lineIndex < lines.length) {
          var availableLines = metrics.linesPerPage - currentLineCount;
          if (availableLines <= 0) {
            flushPage();
            availableLines = metrics.linesPerPage;
          }

          final remainingLines = lines.length - lineIndex;
          var take = math.min(remainingLines, availableLines);
          final takesRest = take == remainingLines;
          if (takesRest &&
              take + 1 > availableLines &&
              currentItems.isNotEmpty) {
            flushPage();
            availableLines = metrics.linesPerPage;
            take = math.min(remainingLines, math.max(1, availableLines - 1));
          } else if (takesRest && take + 1 > availableLines) {
            take = math.max(1, availableLines - 1);
          }

          final chunkStart = lines[lineIndex].start;
          final chunkEnd = lines[lineIndex + take - 1].end;
          final isFinalChunk = lineIndex + take >= lines.length;
          addItem(
            ReaderPageItem(
              blockId: block.id,
              text: text.substring(chunkStart, chunkEnd),
              startOffset: chunkStart,
              endOffset: chunkEnd,
              estimatedLineCount: take + (isFinalChunk ? 1 : 0),
              continuesFromPrevious: lineIndex > 0,
              continuesAfter: !isFinalChunk,
            ),
          );
          lineIndex += take;
        }
      } else {
        addItem(
          ReaderPageItem(
            blockId: block.id,
            estimatedLineCount: metrics.estimateBlockLines(block),
          ),
        );
      }
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

List<String> _uniqueBlockIds(List<ReaderPageItem> items) {
  final ids = <String>[];
  for (final item in items) {
    if (!ids.contains(item.blockId)) {
      ids.add(item.blockId);
    }
  }
  return ids;
}

int _followerReserveLines(
  List<DocumentBlock> blocks,
  int headingIndex,
  _ReaderMetrics metrics,
) {
  for (var index = headingIndex + 1; index < blocks.length; index += 1) {
    final block = blocks[index];
    if (_looksLikeHeading(block.text)) {
      continue;
    }
    return math.min(
      metrics.estimateBlockLines(block),
      _headingFollowerReserveLines,
    );
  }
  return 0;
}

bool _looksLikeHeading(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.length > 80) {
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
    final effectiveLineHeight = math.max(1, fontSize * settings.lineHeight);
    final footerReserve = 56.0 * settings.bottomMarginScale;
    final contentHeight = math.max(
      fontSize,
      viewport.height -
          margin * 2 -
          viewport.topReserve -
          viewport.bottomReserve -
          footerReserve,
    );
    final averageCharWidth = fontSize * 0.55;

    final rawLinesPerPage = (contentHeight / effectiveLineHeight).floor();

    return _ReaderMetrics(
      charsPerLine: math.max(8, (contentWidth / averageCharWidth).floor()),
      linesPerPage: math.max(1, rawLinesPerPage - _pageBottomGuardLines),
    );
  }

  final int charsPerLine;
  final int linesPerPage;

  List<_TextLine> wrapText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const [_TextLine(0, 0)];
    }

    final lines = <_TextLine>[];
    int? lineStart;
    var lineEnd = 0;
    var lineLength = 0;
    for (final match in RegExp(r'\S+').allMatches(text)) {
      final wordLength = match.end - match.start;
      if (lineStart == null) {
        lineStart = match.start;
        lineEnd = match.end;
        lineLength = wordLength;
        continue;
      }

      if (lineLength + 1 + wordLength > charsPerLine) {
        lines.add(_TextLine(lineStart, lineEnd));
        lineStart = match.start;
        lineEnd = match.end;
        lineLength = wordLength;
      } else {
        lineEnd = match.end;
        lineLength += 1 + wordLength;
      }
    }

    if (lineStart != null) {
      lines.add(_TextLine(lineStart, lineEnd));
    }
    return lines.isEmpty ? const [_TextLine(0, 0)] : List.unmodifiable(lines);
  }

  int estimateBlockLines(DocumentBlock block) {
    if (block.text case final text?) {
      return math.max(1, wrapText(text).length) + 1;
    }

    return switch (block.kind) {
      BlockKind.figure || BlockKind.table || BlockKind.equation => 8,
      _ => 2,
    };
  }
}

final class _TextLine {
  const _TextLine(this.start, this.end);

  final int start;
  final int end;
}
