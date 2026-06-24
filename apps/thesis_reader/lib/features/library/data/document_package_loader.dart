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
          DocumentPackage.fromJson(payload),
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
}
