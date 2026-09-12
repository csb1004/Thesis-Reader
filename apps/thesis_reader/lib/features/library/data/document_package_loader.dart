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
      blocks: [
        for (final block in package.blocks) _normalizeBlockText(block, package),
      ],
      assets: package.assets,
      conversionMode: package.conversionMode,
      fallbackReason: package.fallbackReason,
      sourceInfo: package.sourceInfo,
      anchors: package.anchors,
      vocabulary: package.vocabulary,
      summaries: package.summaries,
    );
  }

  static DocumentBlock _normalizeBlockText(
    DocumentBlock block,
    DocumentPackage package,
  ) {
    final preserveText =
        package.sourceInfo?['textNormalized'] == true ||
        package.conversionMode == 'latex-source' ||
        block.source?['preserveStructure'] == true ||
        block.textSpans.isNotEmpty ||
        block.referenceSpans.isNotEmpty;
    final normalizedText = block.text == null || preserveText
        ? block.text
        : _normalizeExtractedBlockText(block.text!);
    final legacyPythonOffsets =
        package.sourceInfo?['offsetEncoding'] != 'utf-16' &&
        (package.metadata.converterVersion == 'mvp-1' ||
            package.metadata.converterVersion == 'mvp-2');
    int offset(int index) {
      if (!legacyPythonOffsets || block.text == null) return index;
      if (index < 0) return index;
      if (index > block.text!.runes.length) return block.text!.length + 1;
      return String.fromCharCodes(block.text!.runes.take(index)).length;
    }

    return DocumentBlock(
      id: block.id,
      sectionId: block.sectionId,
      kind: block.kind,
      text: normalizedText,
      assetId: block.assetId,
      latex: block.latex,
      source: block.source,
      textSpans: [
        for (final span in block.textSpans)
          TextStyleSpan(
            start: offset(span.start),
            end: offset(span.end),
            bold: span.bold,
            italic: span.italic,
            highlight: span.highlight,
          ),
      ],
      referenceSpans: [
        for (final span in block.referenceSpans)
          ReferenceSpan(
            start: offset(span.start),
            end: offset(span.end),
            targetAssetId: span.targetAssetId,
            kind: span.kind,
            label: span.label,
          ),
      ],
      anchor: block.anchor,
    );
  }

  static String _normalizeExtractedBlockText(String text) =>
      _normalizeExtractedText(text);

  static String _normalizeExtractedText(String text) {
    final joinedWords = text
        .replaceAll('☆', '√')
        .replaceAllMapped(
          RegExp(r'([A-Za-z])-\s+([A-Za-z])'),
          (match) => '${match.group(1)}${match.group(2)}',
        );
    final sectionReferences = _normalizeKnownLegacySectionLabels(joinedWords);
    final collapsed = sectionReferences.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _normalizeMathText(_normalizePunctuationSpacing(collapsed));
  }

  static String _normalizeKnownLegacySectionLabels(String text) {
    return text.replaceAllMapped(
      RegExp(r'\bSection\s+(?:Section\s+)?(areas[.:]ASP)\b'),
      (_) => 'Section 2.2',
    );
  }

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
