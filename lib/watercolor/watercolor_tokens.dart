import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// How the watercolor style picks its pigments.
enum WatercolorPaletteMode {
  /// One fixed pigment per entry: rose, apricot, sage, cerulean, wisteria.
  multi,

  /// Pigments derived from the user's seed color.
  seed,

  /// Pigments derived from the system wallpaper color (Android 12+).
  dynamic,
}

/// Design tokens for the watercolor style: paper, ink, pigments and shapes.
///
/// Read them with `WatercolorTokens.of(context)`; the value is null while the
/// classic Material style is active, so callers fall back to the original UI.
@immutable
class WatercolorTokens extends ThemeExtension<WatercolorTokens> {
  const WatercolorTokens({
    required this.brightness,
    required this.amoled,
    required this.paper,
    required this.card,
    required this.ink,
    required this.sub,
    required this.body,
    required this.line,
    required this.pigments,
    required this.accent,
    required this.onPigment,
    required this.liked,
    required this.shadow,
    required this.grainOpacity,
  });

  final Brightness brightness;
  final bool amoled;

  /// Page background.
  final Color paper;

  /// Cards, sheets, the palette bar.
  final Color card;

  /// Primary text and line icons.
  final Color ink;

  /// Secondary text and idle icons.
  final Color sub;

  /// Long-form secondary body text.
  final Color body;

  /// 1px paper edge around cards and inputs.
  final Color line;

  /// Five pigments, one per entry of the palette bar.
  final List<Color> pigments;

  /// Links, authors, episode numbers.
  final Color accent;

  /// Text and filled icons laid on a pigment.
  final Color onPigment;

  /// Favorited heart.
  final Color liked;

  final Color shadow;

  /// Opacity of the paper grain tile; zero disables it.
  final double grainOpacity;

  static const double radiusSmall = 14;
  static const double radiusMedium = 18;
  static const double radiusLarge = 28;

  static const List<Color> _multiLight = [
    Color(0xFFE7A3A0),
    Color(0xFFF2C7A5),
    Color(0xFFB5CBA7),
    Color(0xFFA8C8DE),
    Color(0xFFC9B8DA),
  ];

  static const List<Color> _multiDark = [
    Color(0xFFC98884),
    Color(0xFFD1A27F),
    Color(0xFF8FA882),
    Color(0xFF7FA3BD),
    Color(0xFFA492B8),
  ];

  static const List<double> _hueOffsets = [0, -16, 16, -32, 32];

  static WatercolorTokens? of(BuildContext context) =>
      Theme.of(context).extension<WatercolorTokens>();

  Color pigment(int index) => pigments[index % pigments.length];

  bool get isDark => brightness == Brightness.dark;

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 26, offset: const Offset(0, 10)),
  ];

  /// Builds tokens for [brightness]. [seed] is ignored for
  /// [WatercolorPaletteMode.multi]; for the other modes it is turned into
  /// soft pigments around its hue.
  factory WatercolorTokens.resolve({
    required Brightness brightness,
    required bool amoled,
    required WatercolorPaletteMode mode,
    Color? seed,
  }) {
    final dark = brightness == Brightness.dark;
    final black = dark && amoled;
    List<Color> pigments;
    Color accent;
    if (mode == WatercolorPaletteMode.multi || seed == null) {
      pigments = dark ? _multiDark : _multiLight;
      accent = dark ? const Color(0xFFE7A3A0) : const Color(0xFF9A4F4C);
    } else {
      pigments = pigmentsFromSeed(seed, dark);
      accent = accentFromSeed(seed, dark);
    }
    return WatercolorTokens(
      brightness: brightness,
      amoled: black,
      paper: black
          ? const Color(0xFF000000)
          : dark
          ? const Color(0xFF26221F)
          : const Color(0xFFFBF6EC),
      card: black
          ? const Color(0xFF15120F)
          : dark
          ? const Color(0xFF312B27)
          : const Color(0xFFFFFDF8),
      ink: dark ? const Color(0xFFEDE4D8) : const Color(0xFF3E3431),
      sub: dark ? const Color(0xFFB9AC9F) : const Color(0xFF6B5D57),
      body: dark ? const Color(0xFFCFC3B6) : const Color(0xFF5A4D48),
      line: black
          ? const Color(0xFF2E2925)
          : dark
          ? const Color(0xFF3F3732)
          : const Color(0xFFE6DACA),
      pigments: pigments,
      accent: accent,
      onPigment: const Color(0xFF2B2420),
      liked: const Color(0xFFC26A6A),
      shadow: dark ? const Color(0x66000000) : const Color(0x296E5646),
      grainOpacity: black ? 0 : 0.07,
    );
  }

  /// Five pigments around the seed hue: offsets 0, ∓16, ∓32 degrees,
  /// saturation capped at 62% and lightness 74% (light) or 56% (dark).
  static List<Color> pigmentsFromSeed(Color seed, bool dark) {
    final hsl = HSLColor.fromColor(seed);
    final saturation = math.min(hsl.saturation, 0.62);
    return [
      for (final offset in _hueOffsets)
        HSLColor.fromAHSL(
          1,
          (hsl.hue + offset) % 360,
          saturation,
          dark ? 0.56 : 0.74,
        ).toColor(),
    ];
  }

  static Color accentFromSeed(Color seed, bool dark) {
    final hsl = HSLColor.fromColor(seed);
    return HSLColor.fromAHSL(
      1,
      hsl.hue,
      math.min(hsl.saturation, 0.55),
      dark ? 0.74 : 0.36,
    ).toColor();
  }

  @override
  WatercolorTokens copyWith({
    Brightness? brightness,
    bool? amoled,
    Color? paper,
    Color? card,
    Color? ink,
    Color? sub,
    Color? body,
    Color? line,
    List<Color>? pigments,
    Color? accent,
    Color? onPigment,
    Color? liked,
    Color? shadow,
    double? grainOpacity,
  }) {
    return WatercolorTokens(
      brightness: brightness ?? this.brightness,
      amoled: amoled ?? this.amoled,
      paper: paper ?? this.paper,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      sub: sub ?? this.sub,
      body: body ?? this.body,
      line: line ?? this.line,
      pigments: pigments ?? this.pigments,
      accent: accent ?? this.accent,
      onPigment: onPigment ?? this.onPigment,
      liked: liked ?? this.liked,
      shadow: shadow ?? this.shadow,
      grainOpacity: grainOpacity ?? this.grainOpacity,
    );
  }

  @override
  WatercolorTokens lerp(WatercolorTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return WatercolorTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      amoled: t < 0.5 ? amoled : other.amoled,
      paper: c(paper, other.paper),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      sub: c(sub, other.sub),
      body: c(body, other.body),
      line: c(line, other.line),
      pigments: [
        for (var i = 0; i < pigments.length; i++)
          c(pigments[i], other.pigment(i)),
      ],
      accent: c(accent, other.accent),
      onPigment: c(onPigment, other.onPigment),
      liked: c(liked, other.liked),
      shadow: c(shadow, other.shadow),
      grainOpacity: grainOpacity + (other.grainOpacity - grainOpacity) * t,
    );
  }
}
