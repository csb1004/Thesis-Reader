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
        for (final block in package.blocks)
          DocumentBlock(
            id: block.id,
            sectionId: block.sectionId,
            kind: block.kind,
            text: block.text == null
                ? null
                : _normalizeExtractedText(block.text!),
            assetId: block.assetId,
            referenceSpans: block.referenceSpans,
            anchor: block.anchor,
          ),
      ],
      assets: package.assets,
      anchors: package.anchors,
      vocabulary: package.vocabulary,
      summaries: package.summaries,
    );
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
