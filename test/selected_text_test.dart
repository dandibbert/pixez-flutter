import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/selected_text.dart';

void main() {
  test(
    'keeps the last selection when iOS clears it before the menu action',
    () {
      final memory = SelectedTextMemory();
      memory.update(const SelectedContent(plainText: '彼は走った。'));
      memory.update(const SelectedContent(plainText: ''));
      memory.update(null);

      expect(memory.value, '彼は走った。');
    },
  );

  test('drops the object-replacement character widget spans leave behind', () {
    final memory = SelectedTextMemory();
    memory.update(const SelectedContent(plainText: '彼は\uFFFCった。'));

    expect(memory.value, '彼はった。');
    expect(
      selectedPlainText(const SelectedContent(plainText: '\uFFFC')),
      isEmpty,
    );
  });

  testWidgets('iOS copy keeps the text captured before the selection clears', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelectionArea(child: Text('彼は走った。'))),
    );
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll();
    await tester.pump();

    final buttons = selectionMenuButtons(
      context: tester.element(find.text('彼は走った。')),
      region: region,
      selectedText: '彼は走った。',
      offerTextAction: true,
      actionLabel: 'Translate',
      ios: true,
    );
    region.clearSelection();
    await tester.pump();

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    buttons
        .firstWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed
        ?.call();
    await tester.pump();
    expect(copied, '彼は走った。');
    expect(buttons.map((item) => item.label), contains('Translate'));
  });

  testWidgets('publishes the live selection for the Shortcuts action', (
    tester,
  ) async {
    SelectedTextChannel.enabled = true;
    SelectedTextChannel.reset();
    final published = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SelectedTextChannel.channel,
      (call) async {
        expect(call.method, 'setSelectedText');
        published.add(call.arguments as String?);
        return null;
      },
    );
    addTearDown(() {
      SelectedTextChannel.enabled = false;
      SelectedTextChannel.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SelectedTextChannel.channel,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ShortcutSelectionArea(child: Text('彼は走った。')),
      ),
    );
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll();
    await tester.pump();
    region.clearSelection();
    await tester.pump();

    expect(published, ['彼は走った。', '']);
  });

  testWidgets(
    'keeps the menu snapshot after the live selection is cleared',
    (tester) async {
      SelectedTextChannel.enabled = true;
      SelectedTextChannel.reset();
      final published = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SelectedTextChannel.channel,
        (call) async {
          published.add(call.arguments as String?);
          return null;
        },
      );
      addTearDown(() {
        SelectedTextChannel.enabled = false;
        SelectedTextChannel.reset();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SelectedTextChannel.channel,
          null,
        );
      });

      final memory = SelectedTextMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ShortcutSelectionArea(
            onSelectionChanged: memory.update,
            child: const Text('彼は走った。'),
          ),
        ),
      );
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.clearSelection();
      await tester.pump();

      expect(memory.value, '彼は走った。');
      expect(published, ['彼は走った。', '']);
    },
  );
}
