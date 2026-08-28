import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_reader_keys.dart';

void main() {
  test('arrow and letter keys turn pages', () {
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.arrowLeft,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyA,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyH,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyK,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.bracketLeft,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.arrowRight,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyD,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyL,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyJ,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.bracketRight,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
  });

  test('space and vertical arrows scroll before turning the page', () {
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.space,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: true,
      ),
      NovelReaderKeyAction.scrollDown,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.space,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.nextPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.pageUp,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: true,
        canScrollDown: true,
      ),
      NovelReaderKeyAction.scrollUp,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.arrowDown,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: true,
      ),
      NovelReaderKeyAction.scrollDown,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.arrowUp,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.prevPage,
    );
  });

  test('ignores typing and modifier chords', () {
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.arrowRight,
        isEditingText: true,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      isNull,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyG,
        isEditingText: false,
        hasModifier: true,
        canScrollUp: false,
        canScrollDown: false,
      ),
      isNull,
    );
  });

  test('home end g and escape do not repeat', () {
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.home,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.firstPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.end,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.lastPage,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.keyG,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
        isRepeat: true,
      ),
      isNull,
    );
    expect(
      resolveNovelReaderKey(
        key: LogicalKeyboardKey.escape,
        isEditingText: false,
        hasModifier: false,
        canScrollUp: false,
        canScrollDown: false,
      ),
      NovelReaderKeyAction.goBack,
    );
  });

  test('modifier helper treats ctrl meta alt and shift', () {
    expect(novelReaderHasModifier({LogicalKeyboardKey.metaLeft}), isTrue);
    expect(novelReaderHasModifier({LogicalKeyboardKey.shiftRight}), isTrue);
    expect(novelReaderHasModifier({LogicalKeyboardKey.arrowLeft}), isFalse);
    expect(novelReaderCanScroll(null, 1), isFalse);
  });

  testWidgets('scroll metrics decide whether the article can move', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: ListView(
            controller: controller,
            children: const [SizedBox(height: 800, child: Text('long'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(novelReaderCanScroll(controller.position, 1), isTrue);
    expect(novelReaderCanScroll(controller.position, -1), isFalse);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(novelReaderCanScroll(controller.position, 1), isFalse);
    expect(novelReaderCanScroll(controller.position, -1), isTrue);
  });

  testWidgets('detects a focused text field as editing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField())),
    );
    expect(
      novelReaderIsEditingText(FocusManager.instance.primaryFocus),
      isFalse,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(
      novelReaderIsEditingText(FocusManager.instance.primaryFocus),
      isTrue,
    );
  });
}
