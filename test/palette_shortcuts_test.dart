import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/hello/tab_jump.dart';
import 'package:pixez/watercolor/palette_bar.dart';
import 'package:pixez/watercolor/pigment_scatter_menu.dart';
import 'package:pixez/watercolor/section_wash.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

ThemeData _watercolor() => buildWatercolorTheme(
  WatercolorTokens.resolve(
    brightness: Brightness.light,
    amoled: false,
    mode: WatercolorPaletteMode.multi,
  ),
);

class _Home extends StatefulWidget {
  const _Home({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _menu = GlobalKey<PigmentScatterMenuState>();

  static const _actions = [
    ScatterAction(icon: Icons.book, label: 'Novel', pigment: 3),
    ScatterAction(icon: Icons.library_books, label: 'Manga', pigment: 1),
    ScatterAction(
      icon: Icons.image,
      label: 'Illust',
      pigment: 0,
      current: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PigmentScatterMenu(
      key: _menu,
      barInset: PaletteBar.height + PaletteBar.bottomGap,
      currentLabel: 'Current',
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: PaletteBar(
          items: const [
            PaletteBarItem(icon: Icons.image, label: 'Illust'),
            PaletteBarItem(icon: Icons.leaderboard, label: 'Rank'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          onLongPressStart: (i, d) {
            final box = _menu.currentContext!.findRenderObject() as RenderBox;
            _menu.currentState!.open(
              anchor: box.globalToLocal(d.globalPosition),
              sourcePigment: i,
              actions: _actions,
              onSelected: widget.onSelected,
              pressPosition: d.globalPosition,
            );
          },
          onLongPressMoveUpdate: (_, d) =>
              _menu.currentState!.track(d.globalPosition),
          onLongPressEnd: (_, d) =>
              _menu.currentState!.release(d.globalPosition),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('sliding up from a long-pressed well picks a shortcut', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: _watercolor(),
        home: _Home(onSelected: (i) => picked = i),
      ),
    );
    final well = tester.getCenter(find.text('Illust'));
    final gesture = await tester.startGesture(well);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Manga'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);

    final second = PigmentScatterMenuState.layoutColumn(well, 3)[1];
    await gesture.moveTo(second);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.text('Manga'), findsNothing);
  });

  testWidgets('releasing in place keeps the menu open for a tap', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: _watercolor(),
        home: _Home(onSelected: (i) => picked = i),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Illust')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, isNull);
    await tester.tap(find.text('Novel'));
    await tester.pumpAndSettle();
    expect(picked, 0);
  });

  testWidgets('a tab jump asked before the page exists is applied on build', (
    tester,
  ) async {
    final request = TabJumpRequest()..request(2);
    int? jumped;
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 4,
          child: TabJumpListener(
            request: request,
            onJump: (i) => jumped = i,
            child: Builder(
              builder: (context) {
                controller = DefaultTabController.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.index, 2);
    expect(jumped, 2);
    expect(request.take(), isNull);

    request.request(1);
    await tester.pumpAndSettle();
    expect(controller.index, 1);

    request.request(9);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });

  testWidgets('the classic style switches section without a wash', (
    tester,
  ) async {
    var switched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => playSectionWash(
              context: context,
              origin: Offset.zero,
              color: Colors.blue,
              label: 'Novel',
              icon: Icons.book,
              onPeak: () => switched = true,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    expect(switched, isTrue);
  });
}
