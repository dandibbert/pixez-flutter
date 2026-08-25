import 'dart:io';

import 'package:material_ui/material_ui.dart';

class NovelReaderStyle {
  static const String defaultFamily = '';
  static const String serifAlias = 'serif';
  static const String sansAlias = 'sans';
  static const String systemAlias = 'system';

  static const double defaultFontSize = 16.0;
  static const double minFontSize = 12.0;
  static const double maxFontSize = 32.0;
  static const double defaultLineHeight = 1.8;
  static const double minLineHeight = 1.2;
  static const double maxLineHeight = 2.4;

  static const List<String> serifFallbacks = <String>[
    'Hiragino Mincho ProN',
    'Hiragino Mincho Pro',
    'YuMincho',
    'Yu Mincho',
    'Noto Serif CJK JP',
    'Noto Serif JP',
    'Songti SC',
    'STSong',
    'Noto Serif',
    'Georgia',
    'serif',
  ];

  static const List<String> sansFallbacks = <String>[
    'Hiragino Sans',
    'Hiragino Kaku Gothic ProN',
    'YuGothic',
    'Yu Gothic',
    'Noto Sans CJK JP',
    'Noto Sans JP',
    'PingFang SC',
    'Noto Sans',
    'Roboto',
    'sans-serif',
  ];

  static String get serifFamily {
    if (Platform.isIOS || Platform.isMacOS) {
      return 'Hiragino Mincho ProN';
    }
    if (Platform.isWindows) {
      return 'Yu Mincho';
    }
    if (Platform.isLinux) {
      return 'Noto Serif CJK JP';
    }
    return 'serif';
  }

  static String get sansFamily {
    if (Platform.isIOS || Platform.isMacOS) {
      return 'Hiragino Sans';
    }
    if (Platform.isWindows) {
      return 'Yu Gothic';
    }
    if (Platform.isLinux) {
      return 'Noto Sans CJK JP';
    }
    return 'sans-serif';
  }

  static bool isDefaultFamily(String? family) {
    return family == null ||
        family.isEmpty ||
        family == defaultFamily ||
        family == systemAlias ||
        family == serifAlias;
  }

  static double clampFontSize(double value) {
    return value.clamp(minFontSize, maxFontSize).toDouble();
  }

  static double clampLineHeight(double value) {
    return value.clamp(minLineHeight, maxLineHeight).toDouble();
  }

  static TextStyle resolve({
    required Color color,
    required double fontSize,
    required double lineHeight,
    required String fontFamily,
  }) {
    final size = clampFontSize(fontSize);
    final height = clampLineHeight(lineHeight);
    if (fontFamily == sansAlias) {
      return TextStyle(
        color: color,
        fontSize: size,
        height: height,
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallbacks,
      );
    }
    if (isDefaultFamily(fontFamily)) {
      return TextStyle(
        color: color,
        fontSize: size,
        height: height,
        fontFamily: serifFamily,
        fontFamilyFallback: serifFallbacks,
      );
    }
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontFamily: fontFamily,
      fontFamilyFallback: serifFallbacks,
    );
  }
}
