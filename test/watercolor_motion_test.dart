import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_routes.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

ThemeData _watercolor() => buildWatercolorTheme(
  WatercolorTokens.resolve(
    brightness: Brightness.light,
    amoled: false,
    mode: WatercolorPaletteMode.multi,
  ),
);

final _allowed = {WcMotion.short, WcMotion.medium, WcMotion.long};

void main() {
  test('pages move on the long duration', () {
    const builder = WatercolorPageTransitionsBuilder();
    expect(builder.transitionDuration, WcMotion.long);
    expect(builder.reverseTransitionDuration, WcMotion.long);
  });

  testWidgets('sheets use watercolor timing only in the watercolor style', (
    tester,
  ) async {
    late AnimationStyle? classic;
    late AnimationStyle? watercolor;
    late AnimationStyle? reduced;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            classic = WcMotion.sheet(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: _watercolor(),
        home: Builder(
          builder: (context) {
            watercolor = WcMotion.sheet(context);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reduced = WcMotion.sheet(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(classic, isNull);
    expect(watercolor!.duration, WcMotion.long);
    expect(watercolor!.reverseDuration, WcMotion.medium);
    expect(reduced!.duration, WcMotion.short);
    expect(reduced!.curve, Curves.linear);
  });

  testWidgets('watercolor dialogs scale in, classic dialogs stay Material', (
    tester,
  ) async {
    Future<void> open(ThemeData? theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWcDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('hi')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    await open(null);
    expect(ModalRoute.of(tester.element(find.text('hi'))), isA<DialogRoute>());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    await open(_watercolor());
    final route = ModalRoute.of(tester.element(find.text('hi')))!;
    expect(route, isNot(isA<DialogRoute>()));
    expect(_allowed, contains(route.transitionDuration));
    expect(_allowed, contains(route.reverseTransitionDuration));
    expect(
      find.ancestor(
        of: find.byType(AlertDialog),
        matching: find.byType(ScaleTransition),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion turns page slides into fades', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: _watercolor(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Text('home'),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('next')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final next = find.text('next');
    expect(
      find.ancestor(of: next, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    expect(
      find.ancestor(of: next, matching: find.byType(FadeTransition)),
      findsWidgets,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('list entrance plays once per item', (tester) async {
    final token = Object();
    Widget item() => MaterialApp(
      home: WcEntrance(token: token, index: 0, child: const Text('card')),
    );
    await tester.pumpWidget(item());
    expect(
      find.ancestor(
        of: find.text('card'),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: WcEntrance(token: token, index: 0, child: const Text('again')),
      ),
    );
    final entrance = tester.widget<WcEntrance>(find.byType(WcEntrance));
    expect(entrance.token, same(token));
    expect(
      find.descendant(
        of: find.byType(WcEntrance),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });
}
