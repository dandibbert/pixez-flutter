import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// Builds the Material theme for the watercolor style from [tokens].
ThemeData buildWatercolorTheme(WatercolorTokens tokens) {
  final base = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: tokens.brightness,
  );
  final scheme = base.copyWith(
    primary: tokens.accent,
    onPrimary: tokens.isDark ? tokens.onPigment : tokens.card,
    primaryContainer: tokens.pigment(0),
    onPrimaryContainer: tokens.onPigment,
    secondaryContainer: tokens.pigment(0),
    onSecondaryContainer: tokens.onPigment,
    tertiaryContainer: tokens.pigment(3),
    onTertiaryContainer: tokens.onPigment,
    surface: tokens.paper,
    onSurface: tokens.ink,
    onSurfaceVariant: tokens.sub,
    surfaceContainerLowest: tokens.card,
    surfaceContainerLow: tokens.card,
    surfaceContainer: tokens.card,
    surfaceContainerHigh: tokens.card,
    surfaceContainerHighest: Color.alphaBlend(
      tokens.line.withValues(alpha: 0.5),
      tokens.card,
    ),
    outline: tokens.sub,
    outlineVariant: tokens.line,
    shadow: tokens.shadow,
  );
  final edge = BorderSide(color: tokens.line);
  RoundedRectangleBorder rounded(double radius) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: edge,
  );
  return ThemeData(
    brightness: tokens.brightness,
    useMaterial3: true,
    colorScheme: scheme,
    primaryColor: scheme.primary,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tokens.card,
    cardColor: tokens.card,
    dividerColor: tokens.line,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: rounded(WatercolorTokens.radiusMedium),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.card,
      selectedColor: tokens.pigment(0),
      side: edge,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: tokens.ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      shape: rounded(WatercolorTokens.radiusLarge),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(WatercolorTokens.radiusLarge),
        ),
        side: edge,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      shape: rounded(WatercolorTokens.radiusSmall),
    ),
    dividerTheme: DividerThemeData(color: tokens.line, space: 1),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.sub,
      indicatorColor: tokens.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WatercolorTokens.radiusSmall),
        borderSide: edge,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WatercolorTokens.radiusSmall),
        borderSide: edge,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: WatercolorPageTransitionsBuilder(
          ZoomPageTransitionsBuilder(),
        ),
        TargetPlatform.iOS: WatercolorPageTransitionsBuilder(
          CupertinoPageTransitionsBuilder(),
        ),
        TargetPlatform.macOS: WatercolorPageTransitionsBuilder(
          CupertinoPageTransitionsBuilder(),
        ),
        TargetPlatform.linux: WatercolorPageTransitionsBuilder(
          ZoomPageTransitionsBuilder(),
        ),
        TargetPlatform.windows: WatercolorPageTransitionsBuilder(
          ZoomPageTransitionsBuilder(),
        ),
      },
    ),
  );
}
