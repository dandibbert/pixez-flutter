import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

void main() {
  test('every mapped MingCute asset is bundled', () {
    for (final icon in [Icons.home, Icons.favorite, Icons.favorite_border]) {
      for (final filled in [true, false]) {
        final asset = MingCute.asset(icon, filled: filled)!;
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
    expect(MingCute.asset(Icons.favorite), endsWith('heart_fill.svg'));
    expect(MingCute.asset(Icons.favorite_border), endsWith('heart_line.svg'));
    expect(MingCute.asset(Icons.android), isNull);
  });

  testWidgets('WcIcon shows MingCute only in the watercolor style', (
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
        home: const Row(children: [WcIcon(Icons.home), WcIcon(Icons.android)]),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.android), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Row(children: [WcIcon(Icons.home)])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
