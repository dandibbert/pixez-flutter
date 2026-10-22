import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

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
    textTheme: _textTheme(tokens),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: tokens.ink,
      ),
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
      showCheckmark: false,
      secondaryLabelStyle: TextStyle(
        color: tokens.onPigment,
        fontWeight: FontWeight.w700,
      ),
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.pigment(0),
        foregroundColor: tokens.onPigment,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.pigment(0),
        foregroundColor: tokens.onPigment,
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.ink, width: 1.5),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.accent),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.card,
      foregroundColor: tokens.ink,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: tokens.ink, width: 1.5)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.ink,
      textColor: tokens.ink,
      minTileHeight: 50,
      titleTextStyle: TextStyle(fontSize: 15, color: tokens.ink),
      subtitleTextStyle: TextStyle(fontSize: 12, color: tokens.sub),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(tokens.ink),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? tokens.pigment(0)
            : Colors.transparent,
      ),
      trackOutlineColor: WidgetStatePropertyAll(tokens.ink),
      trackOutlineWidth: const WidgetStatePropertyAll(1.5),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: tokens.accent,
      inactiveTrackColor: tokens.line,
      thumbColor: tokens.accent,
      overlayColor: tokens.pigment(0).withValues(alpha: 0.3),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? tokens.accent : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(tokens.accent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.accent,
      linearTrackColor: tokens.line,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.ink,
      contentTextStyle: TextStyle(color: tokens.paper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WatercolorTokens.radiusSmall),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelColor: tokens.onPigment,
      unselectedLabelColor: tokens.sub,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 15),
      indicator: PigmentTabIndicator(tokens.pigment(0)),
      indicatorSize: TabBarIndicatorSize.label,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
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

/// System fonts in ink, with secondary sizes in the secondary ink.
TextTheme _textTheme(WatercolorTokens tokens) {
  final base = Typography.material2021(
    platform: defaultTargetPlatform,
  ).black.apply(bodyColor: tokens.ink, displayColor: tokens.ink);
  return base.copyWith(
    bodySmall: base.bodySmall?.copyWith(color: tokens.sub),
    labelSmall: base.labelSmall?.copyWith(color: tokens.sub),
  );
}
