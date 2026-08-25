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

  // Keep these short and avoid CSS generic families like "serif".
  // Flutter on macOS can beachball if it has to match every glyph against a
  // long list of missing CJK fonts.
  static List<String> get serifFallbacks {
    if (Platform.isIOS || Platform.isMacOS) {
      return const <String>[
        'Hiragino Mincho ProN',
        'Hiragino Mincho Pro',
        'Songti SC',
        'PingFang SC',
      ];
    }
    if (Platform.isWindows) {
      return const <String>['Yu Mincho', 'MS Mincho', 'Microsoft YaHei'];
    }
    if (Platform.isLinux) {
      return const <String>['Noto Serif CJK JP', 'Noto Serif', 'DejaVu Serif'];
    }
    return const <String>['serif'];
  }

  static List<String> get sansFallbacks {
    if (Platform.isIOS || Platform.isMacOS) {
      return const <String>['Hiragino Sans', 'PingFang SC'];
    }
    if (Platform.isWindows) {
      return const <String>['Yu Gothic', 'Microsoft YaHei'];
    }
    if (Platform.isLinux) {
      return const <String>['Noto Sans CJK JP', 'Noto Sans', 'DejaVu Sans'];
    }
    return const <String>['sans-serif'];
  }

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
      fontFamilyFallback: sansFallbacks,
    );
  }
}
