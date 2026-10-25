import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_ink_ring.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildWatercolorTheme(
    WatercolorTokens.resolve(
      brightness: Brightness.light,
      amoled: false,
      mode: WatercolorPaletteMode.multi,
    ),
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('ink ring button runs its action with a light haptic', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    var taps = 0;
    await tester.pumpWidget(
      _app(
        InkRingButton(
          icon: const Icon(Icons.stop),
          pigment: const Color(0xFFB5CBA7),
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(InkRingButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(taps, 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await tester.pumpAndSettle();
  });

  testWidgets('a disabled ink ring button ignores taps', (tester) async {
    await tester.pumpWidget(
      _app(
        const InkRingButton(
          icon: Icon(Icons.play_arrow),
          pigment: Color(0xFFE7A3A0),
          onPressed: null,
          main: true,
        ),
      ),
    );
    await tester.tap(find.byType(InkRingButton));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('wave bars only animate while playing', (tester) async {
    await tester.pumpWidget(
      _app(const InkWaveBars(color: Color(0xFFC26A6A), active: false)),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      _app(const InkWaveBars(color: Color(0xFFC26A6A), active: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });
}
