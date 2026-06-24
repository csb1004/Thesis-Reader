enum BlockKind {
  heading,
  paragraph,
  quote,
  figure,
  table,
  equation,
  footnote,
  reference,
}

enum AssetKind { figure, table, equation, pageRegion, thumbnail }

enum ReferenceKind { figure, table, equation, footnote, citation, reference }

final class DocumentPackage {
  const DocumentPackage({
    required this.packageVersion,
    required this.documentId,
    required this.metadata,
    required this.sections,
    required this.blocks,
    required this.assets,
    this.anchors = const [],
    this.vocabulary = const [],
    this.summaries = const [],
  });

  factory DocumentPackage.fromJson(Map<String, Object?> json) {
    return DocumentPackage(
      packageVersion: json['packageVersion']! as int,
      documentId: json['documentId']! as String,
      metadata: DocumentMetadata.fromJson(
        json['metadata']! as Map<String, Object?>,
      ),
      sections: _readRequiredList(
        json['sections'],
        'sections',
        DocumentSection.fromJson,
      ),
      blocks: _readRequiredList(
        json['blocks'],
        'blocks',
        DocumentBlock.fromJson,
      ),
      assets: _readRequiredList(
        json['assets'],
        'assets',
        DocumentAsset.fromJson,
      ),
      anchors: _readOptionalList(json['anchors'], ReadingAnchor.fromJson),
      vocabulary: _readOptionalList(
        json['vocabulary'],
        VocabularyEntry.fromJson,
      ),
      summaries: _readOptionalList(json['summaries'], SectionSummary.fromJson),
    );
  }

  final int packageVersion;
  final String documentId;
  final DocumentMetadata metadata;
  final List<DocumentSection> sections;
  final List<DocumentBlock> blocks;
  final List<DocumentAsset> assets;
  final List<ReadingAnchor> anchors;
  final List<VocabularyEntry> vocabulary;
  final List<SectionSummary> summaries;

  Map<String, Object?> toJson() => {
    'packageVersion': packageVersion,
    'documentId': documentId,
    'metadata': metadata.toJson(),
    'sections': sections.map((section) => section.toJson()).toList(),
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'anchors': anchors.map((anchor) => anchor.toJson()).toList(),
    'vocabulary': vocabulary.map((entry) => entry.toJson()).toList(),
    'summaries': summaries.map((summary) => summary.toJson()).toList(),
  };
}

final class DocumentMetadata {
  const DocumentMetadata({
    required this.title,
    required this.sourceFilename,
    this.authors = const [],
    required this.originalPdfSha256,
    this.importedAtIso8601,
    this.converterVersion,
  });

  factory DocumentMetadata.fromJson(Map<String, Object?> json) {
    return DocumentMetadata(
      title: json['title']! as String,
      sourceFilename: json['sourceFilename']! as String,
      authors: _readOptionalStringList(json['authors']),
      originalPdfSha256: json['originalPdfSha256']! as String,
      importedAtIso8601: json['importedAtIso8601'] as String?,
      converterVersion: json['converterVersion'] as String?,
    );
  }

  final String title;
  final String sourceFilename;
  final List<String> authors;
  final String originalPdfSha256;
  final String? importedAtIso8601;
  final String? converterVersion;

  Map<String, Object?> toJson() => {
    'title': title,
    'sourceFilename': sourceFilename,
    'authors': authors,
    'originalPdfSha256': originalPdfSha256,
    'importedAtIso8601': importedAtIso8601,
    'converterVersion': converterVersion,
  };
}

final class DocumentSection {
  const DocumentSection({
    required this.id,
    required this.title,
    required this.blockIds,
  });

  factory DocumentSection.fromJson(Map<String, Object?> json) {
    return DocumentSection(
      id: json['id']! as String,
      title: json['title']! as String,
      blockIds: _readRequiredStringList(json['blockIds'], 'blockIds'),
    );
  }

  final String id;
  final String title;
  final List<String> blockIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'blockIds': blockIds,
  };
}

final class DocumentBlock {
  const DocumentBlock({
    required this.id,
    required this.sectionId,
    required this.kind,
    this.text,
    this.assetId,
    this.referenceSpans = const [],
    this.anchor,
  });

  const DocumentBlock.paragraph({
    required String id,
    required String sectionId,
    required String text,
    List<ReferenceSpan> referenceSpans = const [],
    ReadingAnchor? anchor,
  }) : this(
         id: id,
         sectionId: sectionId,
         kind: BlockKind.paragraph,
         text: text,
         referenceSpans: referenceSpans,
         anchor: anchor,
       );

  factory DocumentBlock.fromJson(Map<String, Object?> json) {
    return DocumentBlock(
      id: json['id']! as String,
      sectionId: json['sectionId']! as String,
      kind: _enumFromName(BlockKind.values, json['kind']! as String),
      text: json['text'] as String?,
      assetId: json['assetId'] as String?,
      referenceSpans: _readOptionalList(
        json['referenceSpans'],
        ReferenceSpan.fromJson,
      ),
      anchor: _readObject(json['anchor'], ReadingAnchor.fromJson),
    );
  }

  final String id;
  final String sectionId;
  final BlockKind kind;
  final String? text;
  final String? assetId;
  final List<ReferenceSpan> referenceSpans;
  final ReadingAnchor? anchor;

  Map<String, Object?> toJson() => {
    'id': id,
    'sectionId': sectionId,
    'kind': kind.name,
    'text': text,
    'assetId': assetId,
    'referenceSpans': referenceSpans.map((span) => span.toJson()).toList(),
    'anchor': anchor?.toJson(),
  };
}

final class DocumentAsset {
  const DocumentAsset({
    required this.id,
    required this.kind,
    required this.label,
    required this.relativePath,
    this.caption,
  });

  factory DocumentAsset.fromJson(Map<String, Object?> json) {
    return DocumentAsset(
      id: json['id']! as String,
      kind: _enumFromName(AssetKind.values, json['kind']! as String),
      label: json['label']! as String,
      relativePath: json['relativePath']! as String,
      caption: json['caption'] as String?,
    );
  }

  final String id;
  final AssetKind kind;
  final String label;
  final String relativePath;
  final String? caption;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'relativePath': relativePath,
    'caption': caption,
  };
}

final class ReferenceSpan {
  const ReferenceSpan({
    required this.start,
    required this.end,
    required this.targetAssetId,
    required this.kind,
    this.label,
  });

  factory ReferenceSpan.fromJson(Map<String, Object?> json) {
    return ReferenceSpan(
      start: json['start']! as int,
      end: json['end']! as int,
      targetAssetId: json['targetAssetId']! as String,
      kind: _enumFromName(ReferenceKind.values, json['kind']! as String),
      label: json['label'] as String?,
    );
  }

  final int start;
  final int end;
  final String targetAssetId;
  final ReferenceKind kind;
  final String? label;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'targetAssetId': targetAssetId,
    'kind': kind.name,
    'label': label,
  };
}

final class ReadingAnchor {
  const ReadingAnchor({
    required this.blockId,
    required this.textOffset,
    this.originalPdfPage,
    this.originalPdfRect,
  });

  factory ReadingAnchor.fromJson(Map<String, Object?> json) {
    return ReadingAnchor(
      blockId: json['blockId']! as String,
      textOffset: json['textOffset']! as int,
      originalPdfPage: json['originalPdfPage'] as int?,
      originalPdfRect: (json['originalPdfRect'] as List<Object?>?)
          ?.map((value) => (value! as num).toDouble())
          .toList(),
    );
  }

  final String blockId;
  final int textOffset;
  final int? originalPdfPage;
  final List<double>? originalPdfRect;

  Map<String, Object?> toJson() => {
    'blockId': blockId,
    'textOffset': textOffset,
    'originalPdfPage': originalPdfPage,
    'originalPdfRect': originalPdfRect,
  };
}

final class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.documentId,
    required this.expression,
    required this.expressionKey,
    required this.meaningKo,
    required this.sourceSentence,
    this.contextBefore,
    this.contextAfter,
    this.anchor,
    this.userMeaning,
    this.userMemo,
  });

  factory VocabularyEntry.fromJson(Map<String, Object?> json) {
    return VocabularyEntry(
      id: json['id']! as String,
      documentId: json['documentId']! as String,
      expression: json['expression']! as String,
      expressionKey: json['expressionKey']! as String,
      meaningKo: json['meaningKo']! as String,
      sourceSentence: json['sourceSentence']! as String,
      contextBefore: json['contextBefore'] as String?,
      contextAfter: json['contextAfter'] as String?,
      anchor: _readObject(json['anchor'], ReadingAnchor.fromJson),
      userMeaning: json['userMeaning'] as String?,
      userMemo: json['userMemo'] as String?,
    );
  }

  final String id;
  final String documentId;
  final String expression;
  final String expressionKey;
  final String meaningKo;
  final String sourceSentence;
  final String? contextBefore;
  final String? contextAfter;
  final ReadingAnchor? anchor;
  final String? userMeaning;
  final String? userMemo;

  Map<String, Object?> toJson() => {
    'id': id,
    'documentId': documentId,
    'expression': expression,
    'expressionKey': expressionKey,
    'meaningKo': meaningKo,
    'sourceSentence': sourceSentence,
    'contextBefore': contextBefore,
    'contextAfter': contextAfter,
    'anchor': anchor?.toJson(),
    'userMeaning': userMeaning,
    'userMemo': userMemo,
  };
}

final class SectionSummary {
  const SectionSummary({
    required this.sectionId,
    required this.summaryKo,
    required this.createdAtIso8601,
  });

  factory SectionSummary.fromJson(Map<String, Object?> json) {
    return SectionSummary(
      sectionId: json['sectionId']! as String,
      summaryKo: json['summaryKo']! as String,
      createdAtIso8601: json['createdAtIso8601']! as String,
    );
  }

  final String sectionId;
  final String summaryKo;
  final String createdAtIso8601;

  Map<String, Object?> toJson() => {
    'sectionId': sectionId,
    'summaryKo': summaryKo,
    'createdAtIso8601': createdAtIso8601,
  };
}

T _enumFromName<T extends Enum>(List<T> values, String name) {
  return values.singleWhere((value) => value.name == name);
}

T? _readObject<T>(
  Object? value,
  T Function(Map<String, Object?> json) fromJson,
) {
  if (value == null) {
    return null;
  }
  return fromJson(value as Map<String, Object?>);
}

List<T> _readRequiredList<T>(
  Object? value,
  String fieldName,
  T Function(Map<String, Object?> json) fromJson,
) {
  if (value == null) {
    throw FormatException('Missing required list field: $fieldName');
  }

  return (value as List<Object?>)
      .map((item) => fromJson(item! as Map<String, Object?>))
      .toList();
}

List<T> _readOptionalList<T>(
  Object? value,
  T Function(Map<String, Object?> json) fromJson,
) {
  return (value as List<Object?>? ?? const [])
      .map((item) => fromJson(item! as Map<String, Object?>))
      .toList();
}

List<String> _readRequiredStringList(Object? value, String fieldName) {
  if (value == null) {
    throw FormatException('Missing required list field: $fieldName');
  }

  return (value as List<Object?>).cast<String>();
}

List<String> _readOptionalStringList(Object? value) {
  return (value as List<Object?>? ?? const []).cast<String>();
}
