import 'dart:ui';

enum ReadingMode { page, scroll }

enum AssetOpenMode { bottomSheet, fullScreen }

const Object _unset = Object();

final class ReaderSettings {
  const ReaderSettings({
    this.themeId = 'paper',
    this.fontFamily,
    this.fontScale = 1.0,
    this.lineHeight = 1.5,
    this.marginScale = 1.0,
    this.bottomMarginScale = 1.0,
    this.readingMode = ReadingMode.page,
    this.assetOpenMode = AssetOpenMode.bottomSheet,
  });

  final String themeId;
  final String? fontFamily;
  final double fontScale;
  final double lineHeight;
  final double marginScale;
  final double bottomMarginScale;
  final ReadingMode readingMode;
  final AssetOpenMode assetOpenMode;

  ReaderSettings copyWith({
    String? themeId,
    Object? fontFamily = _unset,
    double? fontScale,
    double? lineHeight,
    double? marginScale,
    double? bottomMarginScale,
    ReadingMode? readingMode,
    AssetOpenMode? assetOpenMode,
  }) {
    return ReaderSettings(
      themeId: themeId ?? this.themeId,
      fontFamily: fontFamily == _unset
          ? this.fontFamily
          : fontFamily as String?,
      fontScale: fontScale ?? this.fontScale,
      lineHeight: lineHeight ?? this.lineHeight,
      marginScale: marginScale ?? this.marginScale,
      bottomMarginScale: bottomMarginScale ?? this.bottomMarginScale,
      readingMode: readingMode ?? this.readingMode,
      assetOpenMode: assetOpenMode ?? this.assetOpenMode,
    );
  }
}

final class ReaderThemeData {
  const ReaderThemeData({
    required this.id,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String id;
  final String label;
  final Color backgroundColor;
  final Color textColor;
}

abstract final class ReaderThemeCatalog {
  static const themes = [
    ReaderThemeData(
      id: 'white',
      label: '흰색',
      backgroundColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF171717),
    ),
    ReaderThemeData(
      id: 'paper',
      label: '종이',
      backgroundColor: Color(0xFFFFF8ED),
      textColor: Color(0xFF252018),
    ),
    ReaderThemeData(
      id: 'cream',
      label: '크림',
      backgroundColor: Color(0xFFF5ECD8),
      textColor: Color(0xFF31271D),
    ),
    ReaderThemeData(
      id: 'green',
      label: '초록',
      backgroundColor: Color(0xFFEAF2E3),
      textColor: Color(0xFF1D2A21),
    ),
    ReaderThemeData(
      id: 'dark',
      label: '어두움',
      backgroundColor: Color(0xFF171717),
      textColor: Color(0xFFECE6DA),
    ),
  ];

  static ReaderThemeData resolve(String themeId) {
    for (final theme in themes) {
      if (theme.id == themeId) {
        return theme;
      }
    }
    return themes.first;
  }
}

final class ReaderFontOption {
  const ReaderFontOption({
    required this.id,
    required this.label,
    required this.fontFamily,
  });

  final String id;
  final String label;
  final String? fontFamily;
}

abstract final class ReaderFontCatalog {
  static const fonts = [
    ReaderFontOption(id: 'system', label: '기본', fontFamily: null),
    ReaderFontOption(id: 'serif', label: '명조', fontFamily: 'serif'),
    ReaderFontOption(id: 'monospace', label: '고정폭', fontFamily: 'monospace'),
  ];

  static String idFor(String? fontFamily) {
    for (final font in fonts) {
      if (font.fontFamily == fontFamily) {
        return font.id;
      }
    }
    return fonts.first.id;
  }
}
