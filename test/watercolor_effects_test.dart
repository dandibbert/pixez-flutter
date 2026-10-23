import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/watercolor/watercolor_effects.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

ThemeData _watercolor(Brightness brightness) => buildWatercolorTheme(
  WatercolorTokens.resolve(
    brightness: brightness,
    amoled: false,
    mode: WatercolorPaletteMode.multi,
  ),
);

Future<void> _push(WidgetTester tester, ThemeData? theme) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: key, theme: theme, home: const Text('list')),
  );
  key.currentState!.push(
    WetPaperPageRoute<void>(builder: (_) => const Text('work')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  testWidgets('works open on wet paper only in the watercolor style', (
    tester,
  ) async {
    await _push(tester, null);
    expect(
      find.ancestor(
        of: find.text('work'),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    await _push(tester, _watercolor(Brightness.light));
    expect(
      find.ancestor(
        of: find.text('work'),
        matching: find.byType(ImageFiltered),
      ),
      findsOneWidget,
    );
    // The list beneath does not slide away.
    expect(
      find.ancestor(
        of: find.text('list'),
        matching: find.byType(SlideTransition),
      ),
      findsWidgets,
    );
    final list = tester.getTopLeft(find.text('list'));
    expect(list.dx, 0);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('work'),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
  });

  testWidgets('a long press swells the card and release settles it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: DropletPress(
            child: GestureDetector(
              onLongPress: () {},
              child: const ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DropletPress)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), 1);
    await tester.pump(kLongPressTimeout);
    await tester.pump();
    expect(scale(), greaterThan(1));
    await gesture.up();
    await tester.pump();
    expect(scale(), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('switching to dark drops ink over the app', (tester) async {
    userSetting.uiStyle = UiStyle.watercolor;
    userSetting.themeMode = ThemeMode.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: _watercolor(Brightness.light),
        darkTheme: _watercolor(Brightness.dark),
        builder: (context, child) => WatercolorEffectsHost(child: child!),
        home: const Text('page'),
      ),
    );
    Finder effect() => find.descendant(
      of: find.byType(WatercolorEffectsHost),
      matching: find.byType(CustomPaint),
    );
    final before = effect().evaluate().length;
    userSetting.themeMode = ThemeMode.dark;
    await tester.pump();
    await tester.pump();
    expect(effect().evaluate().length, greaterThan(before));
    await tester.pumpAndSettle();
    expect(effect().evaluate().length, before);
    userSetting.themeMode = ThemeMode.system;
  });

  testWidgets('nothing is painted in the classic style', (tester) async {
    userSetting.uiStyle = UiStyle.classic;
    userSetting.themeMode = ThemeMode.light;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => WatercolorEffectsHost(child: child!),
        home: const Text('page'),
      ),
    );
    final before = find.byType(CustomPaint).evaluate().length;
    userSetting.themeMode = ThemeMode.dark;
    await tester.pump();
    await tester.pump();
    expect(find.byType(CustomPaint).evaluate().length, before);
    userSetting.themeMode = ThemeMode.system;
    userSetting.uiStyle = UiStyle.watercolor;
  });
}
