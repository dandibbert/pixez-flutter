import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/app_keyboard_shortcuts.dart';

void main() {
  testWidgets('Esc and Command+I trigger only their registered actions', (
    tester,
  ) async {
    var backCount = 0;
    var fitWidthCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardShortcuts(
          onEscape: () => backCount++,
          onMetaI: () => fitWidthCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(backCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(fitWidthCount, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(fitWidthCount, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(fitWidthCount, 1);
  });

  testWidgets('arrow shortcuts remain available for multi-page viewers', (
    tester,
  ) async {
    var previousCount = 0;
    var nextCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardShortcuts(
          onArrowLeft: () => previousCount++,
          onArrowRight: () => nextCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(previousCount, 1);
    expect(nextCount, 1);
  });
}
