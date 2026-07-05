import 'dart:convert';
import 'dart:io';

import 'package:document_contract/document_contract.dart';
import 'package:path/path.dart' as p;

final class LoadedDocumentPackage {
  const LoadedDocumentPackage({
    required this.package,
    required this.packageFile,
  });

  final DocumentPackage package;
  final File packageFile;
}

abstract final class DocumentPackageLoader {
  static Future<LoadedDocumentPackage?> load({
    required String documentId,
    required Directory appDirectory,
    required String? storedPackagePath,
  }) async {
    final candidates = <File>[
      if (storedPackagePath != null && storedPackagePath.isNotEmpty)
        File(storedPackagePath),
      File(p.join(appDirectory.path, 'packages', documentId, 'package.json')),
    ];

    for (final candidate in candidates) {
      if (!await candidate.exists()) {
        continue;
      }

      final payload =
          jsonDecode(await candidate.readAsString()) as Map<String, Object?>;
      return LoadedDocumentPackage(
        package: _withPackageAssetPaths(
          _normalizePackageText(DocumentPackage.fromJson(payload)),
          candidate.parent,
        ),
        packageFile: candidate,
      );
    }

    return null;
  }

  static DocumentPackage _withPackageAssetPaths(
    DocumentPackage package,
    Directory packageDirectory,
  ) {
    return DocumentPackage(
      packageVersion: package.packageVersion,
      documentId: package.documentId,
      metadata: package.metadata,
      sections: package.sections,
      blocks: package.blocks,
      assets: [
        for (final asset in package.assets)
          DocumentAsset(
            id: asset.id,
            kind: asset.kind,
            label: asset.label,
            relativePath: p.isAbsolute(asset.relativePath)
                ? asset.relativePath
                : p.join(packageDirectory.path, asset.relativePath),
            caption: asset.caption,
          ),
      ],
      conversionMode: package.conversionMode,
      fallbackReason: package.fallbackReason,
      sourceInfo: package.sourceInfo,
      anchors: package.anchors,
      vocabulary: package.vocabulary,
      summaries: package.summaries,
    );
  }

  static DocumentPackage _normalizePackageText(DocumentPackage package) {
    return DocumentPackage(
      packageVersion: package.packageVersion,
      documentId: package.documentId,
      metadata: package.metadata,
      sections: package.sections,
      blocks: [for (final block in package.blocks) _normalizeBlockText(block)],
      assets: package.assets,
      conversionMode: package.conversionMode,
      fallbackReason: package.fallbackReason,
      sourceInfo: package.sourceInfo,
      anchors: package.anchors,
      vocabulary: package.vocabulary,
      summaries: package.summaries,
    );
  }

  static DocumentBlock _normalizeBlockText(DocumentBlock block) {
    final normalized = block.text == null
        ? null
        : _normalizeExtractedBlockText(block.text!);
    return DocumentBlock(
      id: block.id,
      sectionId: block.sectionId,
      kind: block.kind,
      text: normalized?.text,
      assetId: block.assetId,
      latex: block.latex,
      source: block.source,
      textSpans: block.textSpans,
      referenceSpans: normalized != null && normalized.referenceSpans.isNotEmpty
          ? normalized.referenceSpans
          : block.referenceSpans,
      anchor: block.anchor,
    );
  }

  static _NormalizedExtractedText _normalizeExtractedBlockText(String text) {
    final normalizedText = _normalizeExtractedText(text);
    return _normalizeLegacySectionReferences(normalizedText);
  }

  static String _normalizeExtractedText(String text) {
    final joinedWords = text
        .replaceAll('☆', '√')
        .replaceAllMapped(
          RegExp(r'([A-Za-z])-\s+([A-Za-z])'),
          (match) => '${match.group(1)}${match.group(2)}',
        );
    final collapsed = joinedWords.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _normalizeMathText(_normalizePunctuationSpacing(collapsed));
  }

  static _NormalizedExtractedText _normalizeLegacySectionReferences(
    String text,
  ) {
    final pattern = RegExp(r'(?:Section\s+)?Section areas:([A-Za-z0-9_]+)');
    final spans = <ReferenceSpan>[];
    final buffer = StringBuffer();
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      buffer.write(text.substring(cursor, match.start));
      final label = _humanizeReferenceLabel(match.group(1)!);
      final replacement = 'Section $label';
      final start = buffer.length;
      buffer.write(replacement);
      spans.add(
        ReferenceSpan(
          start: start,
          end: start + replacement.length,
          targetAssetId: '',
          kind: ReferenceKind.reference,
          label: 'Section: $label',
        ),
      );
      cursor = match.end;
    }

    if (spans.isEmpty) {
      return _NormalizedExtractedText(text: text);
    }

    buffer.write(text.substring(cursor));
    return _NormalizedExtractedText(
      text: buffer.toString(),
      referenceSpans: spans,
    );
  }

  static String _humanizeReferenceLabel(String value) {
    final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    final buffer = StringBuffer();

    for (var index = 0; index < normalized.length; index++) {
      final codeUnit = normalized.codeUnitAt(index);
      if (_shouldInsertReferenceLabelSpace(normalized, index)) {
        buffer.write(' ');
      }
      buffer.writeCharCode(codeUnit);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _shouldInsertReferenceLabelSpace(String value, int index) {
    if (index == 0 || value.codeUnitAt(index) == 0x20) {
      return false;
    }
    final current = value.codeUnitAt(index);
    if (!_isAsciiUpper(current)) {
      return false;
    }
    final previous = value.codeUnitAt(index - 1);
    if (_isAsciiLower(previous) || _isAsciiDigit(previous)) {
      return true;
    }
    if (!_isAsciiUpper(previous) || index + 2 >= value.length) {
      return false;
    }
    return _isAsciiLower(value.codeUnitAt(index + 1)) &&
        _isAsciiLower(value.codeUnitAt(index + 2));
  }

  static bool _isAsciiUpper(int codeUnit) =>
      codeUnit >= 0x41 && codeUnit <= 0x5A;

  static bool _isAsciiLower(int codeUnit) =>
      codeUnit >= 0x61 && codeUnit <= 0x7A;

  static bool _isAsciiDigit(int codeUnit) =>
      codeUnit >= 0x30 && codeUnit <= 0x39;

  static String _normalizeMathText(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'Attention\(\s*Q\s*,\s*K\s*,\s*V\s*\)\s*=\s*softmax\(\s*Q\s*K\s*T\s*/?\s*√\s*d\s*_?\s*k\s*\)\s*V',
      ),
      (_) => 'Attention(Q, K, V) = softmax(QK^T / √d_k) V',
    );
  }

  static String _normalizePunctuationSpacing(String text) {
    var normalized = text;
    normalized = normalized.replaceAllMapped(
      RegExp(r'\s+([,.;:])'),
      (match) => match.group(1)!,
    );
    normalized = normalized.replaceAllMapped(RegExp(r'\(\s+'), (_) => '(');
    normalized = normalized.replaceAllMapped(RegExp(r'\s+\)'), (_) => ')');
    normalized = normalized.replaceAllMapped(
      RegExp(r'\)([A-Za-z])'),
      (match) => ') ${match.group(1)}',
    );
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

final class _NormalizedExtractedText {
  const _NormalizedExtractedText({
    required this.text,
    this.referenceSpans = const [],
  });

  final String text;
  final List<ReferenceSpan> referenceSpans;
}
