import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

void main() {
  test('style settings fall back when nothing was stored yet', () {
    // A first launch after updating has no stored index; that must not throw.
    expect(
      enumFromIndex(UiStyle.values, null, UiStyle.watercolor),
      UiStyle.watercolor,
    );
    expect(
      enumFromIndex(UiStyle.values, -1, UiStyle.watercolor),
      UiStyle.watercolor,
    );
    expect(
      enumFromIndex(UiStyle.values, 9, UiStyle.watercolor),
      UiStyle.watercolor,
    );
    expect(
      enumFromIndex(UiStyle.values, 1, UiStyle.watercolor),
      UiStyle.classic,
    );
  });

  test('multi palette uses the fixed pigments', () {
    final light = WatercolorTokens.resolve(
      brightness: Brightness.light,
      amoled: false,
      mode: WatercolorPaletteMode.multi,
    );
    expect(light.paper, const Color(0xFFFBF6EC));
    expect(light.pigment(0), const Color(0xFFE7A3A0));
    expect(light.accent, const Color(0xFF9A4F4C));
    final dark = WatercolorTokens.resolve(
      brightness: Brightness.dark,
      amoled: false,
      mode: WatercolorPaletteMode.multi,
    );
    expect(dark.paper, const Color(0xFF26221F));
    expect(dark.pigment(4), const Color(0xFFA492B8));
  });

  test('AMOLED only applies to dark and drops the grain', () {
    final amoled = WatercolorTokens.resolve(
      brightness: Brightness.dark,
      amoled: true,
      mode: WatercolorPaletteMode.multi,
    );
    expect(amoled.paper, const Color(0xFF000000));
    expect(amoled.grainOpacity, 0);
    final light = WatercolorTokens.resolve(
      brightness: Brightness.light,
      amoled: true,
      mode: WatercolorPaletteMode.multi,
    );
    expect(light.paper, const Color(0xFFFBF6EC));
  });

  test('seed palette spreads hues and softens saturation', () {
    const seed = Color(0xFFFF0066);
    final pigments = WatercolorTokens.pigmentsFromSeed(seed, false);
    final seedHue = HSLColor.fromColor(seed).hue;
    final hues = pigments.map((c) => HSLColor.fromColor(c).hue).toList();
    expect(hues[0], closeTo(seedHue, 1));
    expect(hues[1], closeTo((seedHue - 16) % 360, 1));
    expect(hues[4], closeTo((seedHue + 32) % 360, 1));
    for (final pigment in pigments) {
      final hsl = HSLColor.fromColor(pigment);
      expect(hsl.saturation, lessThanOrEqualTo(0.625));
      expect(hsl.lightness, closeTo(0.74, 0.01));
    }
    final accent = HSLColor.fromColor(
      WatercolorTokens.accentFromSeed(seed, false),
    );
    expect(accent.lightness, closeTo(0.36, 0.01));
  });

  final paper = find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).image?.image ==
            WatercolorPaper.grain,
  );

  testWidgets('paper is drawn only when watercolor tokens are present', (
    tester,
  ) async {
    final tokens = WatercolorTokens.resolve(
      brightness: Brightness.light,
      amoled: false,
      mode: WatercolorPaletteMode.multi,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWatercolorTheme(tokens),
        home: const WatercolorPaper(child: Scaffold(body: Text('a'))),
      ),
    );
    expect(paper, findsWidgets);
    final theme = Theme.of(tester.element(find.text('a')));
    expect(theme.extension<WatercolorTokens>(), isNotNull);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);

    await tester.pumpWidget(
      const MaterialApp(
        home: WatercolorPaper(child: Scaffold(body: Text('b'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(paper, findsNothing);
  });
}
