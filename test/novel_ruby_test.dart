import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';

void main() {
  test('parses pixiv fullwidth and halfwidth ruby separators', () {
    final fullwidth = parseNovelRubyMarkup('[[rb:漢字＞かんじ]]');
    expect(fullwidth, isNotNull);
    expect(fullwidth!.base, '漢字');
    expect(fullwidth.ruby, 'かんじ');
    expect(fullwidth.encoded, '漢字>かんじ');

    final halfwidth = parseNovelRubyPayload('走る>はしる');
    expect(halfwidth.base, '走る');
    expect(halfwidth.ruby, 'はしる');
  });

  testWidgets('ruby stays inline and does not take the full line width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const style = TextStyle(fontSize: 20, height: 1.8);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: '彼は'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: NovelRubyText(
                      base: '走',
                      ruby: 'はし',
                      baseStyle: style,
                      rubyStyle: TextStyle(fontSize: 11, height: 1.0),
                    ),
                  ),
                  TextSpan(text: 'った。続きの文章です。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(NovelRubyText), findsOneWidget);
    final rubyBox = tester.getRect(find.byType(NovelRubyText));
    expect(rubyBox.width, lessThan(80));
    expect(rubyBox.width, greaterThan(8));

    final paragraph = tester.getRect(find.byType(RichText).first);
    expect(paragraph.height, lessThan(80));
    // Prefix text sits on the same line, so ruby is not at the left edge.
    expect(rubyBox.left, greaterThan(paragraph.left + 10));
    expect(rubyBox.right, lessThan(paragraph.right - 10));
    expect(rubyBox.top, lessThan(paragraph.top + 40));

    final base = tester.getRect(find.text('走'));
    final reading = tester.getRect(find.text('はし'));
    expect(reading.bottom, lessThanOrEqualTo(base.top + 4));
  });
}
