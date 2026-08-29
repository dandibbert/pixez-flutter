import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';

const _cjkFamily = 'CJK';

Future<void> _loadCjkFont() async {
  final bytes = File(
    '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
  ).readAsBytesSync();
  final loader = FontLoader(_cjkFamily);
  loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

const _style = TextStyle(
  fontSize: 20,
  height: 1.8,
  fontFamily: _cjkFamily,
  color: Color(0xFF222222),
);

Widget _rubyApp({
  required InlineSpan paragraph,
  Key? captureKey,
}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text.rich(paragraph),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadCjkFont);

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

    await tester.pumpWidget(
      _rubyApp(
        paragraph: TextSpan(
          style: _style,
          children: [
            const TextSpan(text: '彼は'),
            novelRubySpan(base: '走', ruby: 'はし', style: _style),
            const TextSpan(text: 'った。続きの文章です。'),
          ],
        ),
      ),
    );

    expect(find.byType(NovelRubyText), findsOneWidget);
    final rubyBox = tester.getRect(find.byType(NovelRubyText));
    expect(rubyBox.width, lessThan(80));
    expect(rubyBox.width, greaterThan(8));

    final paragraph = tester.getRect(find.byType(RichText).first);
    expect(paragraph.height, lessThan(80));
    expect(rubyBox.left, greaterThan(paragraph.left + 10));
    expect(rubyBox.right, lessThan(paragraph.right - 10));
    expect(rubyBox.top, lessThan(paragraph.top + 40));
  });

  testWidgets('base stays on the body baseline; reading sits above it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const probeKey = Key('ruby-probe');
    const probeStyle = TextStyle(
      fontSize: 20,
      height: 1.0,
      fontFamily: _cjkFamily,
      color: Color(0xFF222222),
    );

    await tester.pumpWidget(
      _rubyApp(
        paragraph: TextSpan(
          style: _style,
          children: [
            const TextSpan(text: '彼は'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: NovelRubyText(
                key: probeKey,
                base: '標',
                ruby: '',
                baseStyle: probeStyle,
                rubyStyle: probeStyle,
              ),
            ),
            novelRubySpan(base: '走', ruby: 'はし', style: _style),
            const TextSpan(text: 'った。'),
          ],
        ),
      ),
    );

    final probeBox = tester.getRect(find.byKey(probeKey));
    final rubyFinder = find.byWidgetPredicate(
      (widget) => widget is NovelRubyText && widget.base == '走',
    );
    final rubyBox = tester.getRect(rubyFinder);
    final probeRo = tester.renderObject<RenderNovelRuby>(find.byKey(probeKey));
    final rubyRo = tester.renderObject<RenderNovelRuby>(rubyFinder);

    final probeBaseline = probeBox.top + probeRo.alphabeticBaseline;
    final rubyBaseline = rubyBox.top + rubyRo.alphabeticBaseline;

    // Same line as neighboring body text — the annotated kanji must not sink.
    expect(rubyBaseline, closeTo(probeBaseline, 1.5));
    expect(rubyBox.bottom, closeTo(probeBox.bottom, 2.0));

    // Reading occupies the extra space above the shared baseline.
    expect(rubyBox.top, lessThan(probeBox.top - 6));
    expect(rubyRo.alphabeticBaseline, greaterThan(probeRo.alphabeticBaseline + 6));

    // Descent matches a normal character, not (reading + base).
    final rubyDescent = rubyBox.height - rubyRo.alphabeticBaseline;
    final probeDescent = probeBox.height - probeRo.alphabeticBaseline;
    expect(rubyDescent, closeTo(probeDescent, 2.0));

    // Reported baseline is the base, not the furigana near the top.
    expect(rubyRo.alphabeticBaseline, greaterThan(rubyRo.size.height * 0.45));
  });

  testWidgets('captures HTML-style ruby on the body baseline', (tester) async {
    tester.view.physicalSize = const Size(390, 220);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const captureKey = Key('ruby-capture');
    const displayStyle = TextStyle(
      fontSize: 32,
      height: 1.8,
      fontFamily: _cjkFamily,
      color: Color(0xFF1A1A1A),
    );

    await tester.pumpWidget(
      _rubyApp(
        captureKey: captureKey,
        paragraph: TextSpan(
          style: displayStyle,
          children: [
            const TextSpan(text: '彼は'),
            novelRubySpan(base: '走', ruby: 'はし', style: displayStyle),
            const TextSpan(text: 'った。漢字'),
            novelRubySpan(base: '物語', ruby: 'ものがたり', style: displayStyle),
            const TextSpan(text: '。'),
          ],
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('/opt/cursor/artifacts/novel_ruby_baseline.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      expect(file.existsSync(), isTrue);
    });
  });
}
