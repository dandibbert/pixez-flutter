import 'package:material_ui/material_ui.dart';

/// Reading background, chosen independently of the app theme.
///
/// On the OLED panels these phones use, panel power tracks how much light the
/// pixels emit, and the reader is one flat sheet of [ColorScheme.surface] held
/// on screen for a long time. A light page is close to a full-white screen and
/// is the most expensive thing the display can show; a dark one costs almost
/// nothing. Low Power Mode does not touch display power, so this is the only
/// lever that reaches it.
enum NovelReaderBackground { system, paper, sepia, dark, black }

class _ReaderPalette {
  const _ReaderPalette({
    required this.brightness,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.container,
  });

  final Brightness brightness;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color container;
}

const Map<NovelReaderBackground, _ReaderPalette> _palettes = {
  NovelReaderBackground.paper: _ReaderPalette(
    brightness: Brightness.light,
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A),
    onSurfaceVariant: Color(0xFF55534F),
    outlineVariant: Color(0xFFDDDCD8),
    container: Color(0xFFF2F1EE),
  ),
  NovelReaderBackground.sepia: _ReaderPalette(
    brightness: Brightness.light,
    surface: Color(0xFFF4ECD8),
    onSurface: Color(0xFF43372A),
    onSurfaceVariant: Color(0xFF6B5A44),
    outlineVariant: Color(0xFFDFD3B8),
    container: Color(0xFFEBE1C8),
  ),
  NovelReaderBackground.dark: _ReaderPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF16181C),
    onSurface: Color(0xFFC8CBD0),
    onSurfaceVariant: Color(0xFF9AA0A8),
    outlineVariant: Color(0xFF2C3037),
    container: Color(0xFF202329),
  ),
  NovelReaderBackground.black: _ReaderPalette(
    brightness: Brightness.dark,
    // Pure black switches OLED pixels off rather than dimming them.
    surface: Color(0xFF000000),
    onSurface: Color(0xFFB7BBC0),
    onSurfaceVariant: Color(0xFF8A8F96),
    outlineVariant: Color(0xFF1C1F24),
    container: Color(0xFF0A0B0D),
  ),
};

ColorScheme? _cachedSeedScheme;
Color? _cachedSeed;
Brightness? _cachedBrightness;

/// Deriving an accent from the seed runs the Material colour science, which is
/// far too slow to repeat on every reader rebuild.
ColorScheme _accentScheme(Color seed, Brightness brightness) {
  if (_cachedSeedScheme != null &&
      _cachedSeed == seed &&
      _cachedBrightness == brightness) {
    return _cachedSeedScheme!;
  }
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  _cachedSeed = seed;
  _cachedBrightness = brightness;
  _cachedSeedScheme = scheme;
  return scheme;
}

@visibleForTesting
void resetNovelReaderSchemeCache() {
  _cachedSeedScheme = null;
  _cachedSeed = null;
  _cachedBrightness = null;
}

/// Recolours [base] for the reader. Keeps the user's accent colour, replaces
/// only the surfaces the reader paints.
ColorScheme resolveNovelReaderScheme(
  ColorScheme base,
  NovelReaderBackground background,
) {
  final palette = _palettes[background];
  if (palette == null) {
    return base;
  }
  final accent = base.brightness == palette.brightness
      ? base
      : _accentScheme(base.primary, palette.brightness);
  return accent.copyWith(
    surface: palette.surface,
    onSurface: palette.onSurface,
    onSurfaceVariant: palette.onSurfaceVariant,
    outlineVariant: palette.outlineVariant,
    surfaceContainer: palette.container,
    surfaceContainerHigh: palette.container,
    surfaceContainerHighest: palette.container,
  );
}

/// Recolours a whole [ThemeData] for the reader.
///
/// Overriding only the colour scheme is not enough: the text and icon themes
/// were derived from the app's brightness, so a light app on a black reading
/// page would draw a near-black title and near-black icons on black.
ThemeData applyNovelReaderTheme(
  ThemeData base,
  NovelReaderBackground background,
) {
  final scheme = resolveNovelReaderScheme(base.colorScheme, background);
  if (identical(scheme, base.colorScheme)) {
    return base;
  }
  return base.copyWith(
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surfaceContainer,
    dividerColor: scheme.outlineVariant,
    iconTheme: base.iconTheme.copyWith(color: scheme.onSurface),
    primaryIconTheme: base.primaryIconTheme.copyWith(color: scheme.onSurface),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

NovelReaderBackground novelReaderBackgroundFromName(String? name) {
  return NovelReaderBackground.values.firstWhere(
    (value) => value.name == name,
    orElse: () => NovelReaderBackground.system,
  );
}
