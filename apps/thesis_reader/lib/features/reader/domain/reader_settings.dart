enum ReadingMode { page, scroll }

enum AssetOpenMode { bottomSheet, fullScreen }

final class ReaderSettings {
  const ReaderSettings({
    this.themeId = 'paper',
    this.fontFamily,
    this.fontScale = 1.0,
    this.lineHeight = 1.5,
    this.marginScale = 1.0,
    this.readingMode = ReadingMode.page,
    this.assetOpenMode = AssetOpenMode.bottomSheet,
  });

  final String themeId;
  final String? fontFamily;
  final double fontScale;
  final double lineHeight;
  final double marginScale;
  final ReadingMode readingMode;
  final AssetOpenMode assetOpenMode;

  ReaderSettings copyWith({
    String? themeId,
    String? fontFamily,
    double? fontScale,
    double? lineHeight,
    double? marginScale,
    ReadingMode? readingMode,
    AssetOpenMode? assetOpenMode,
  }) {
    return ReaderSettings(
      themeId: themeId ?? this.themeId,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      lineHeight: lineHeight ?? this.lineHeight,
      marginScale: marginScale ?? this.marginScale,
      readingMode: readingMode ?? this.readingMode,
      assetOpenMode: assetOpenMode ?? this.assetOpenMode,
    );
  }
}
