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

Widget _rubyApp({required Widget child, Key? captureKey, Size? surface}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: Colors.white,
            child: SizedBox(
              width: surface?.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _globalBox(
  WidgetTester tester,
  RenderParagraph paragraph,
  TextSelection selection, {
  ui.BoxHeightStyle heightStyle = ui.BoxHeightStyle.tight,
}) {
  final local = paragraph
      .getBoxesForSelection(selection, boxHeightStyle: heightStyle)
      .single
      .toRect();
  return local.shift(tester.getTopLeft(find.byType(RichText).first));
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
        child: Text.rich(
          TextSpan(
            style: _style,
            children: [
              const TextSpan(text: '彼は'),
              novelRubySpan(base: '走', ruby: 'はし', style: _style),
              const TextSpan(text: 'った。続きの文章です。'),
            ],
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
    expect(rubyBox.left, greaterThan(paragraph.left + 10));
    expect(rubyBox.right, lessThan(paragraph.right - 10));
    expect(rubyBox.top, lessThan(paragraph.top + 40));
  });

  testWidgets('base shares the body TextSpan glyph box, not the 1.8 line box', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _rubyApp(
        surface: const Size(720, 0),
        child: Text.rich(
          TextSpan(
            style: _style,
            children: [
              const TextSpan(text: '彼は'),
              novelRubySpan(base: '走', ruby: 'はし', style: _style),
              const TextSpan(text: 'った。'),
            ],
          ),
        ),
      ),
    );

    final rubyBox = tester.getRect(find.byType(NovelRubyText));
    final rubyRo = tester.renderObject<RenderNovelRuby>(
      find.byType(NovelRubyText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).first,
    );
    // 彼は = 0-2, WidgetSpan placeholder = 2-3, った。 = 3-6
    final prefix = _globalBox(
      tester,
      paragraph,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    final suffix = _globalBox(
      tester,
      paragraph,
      const TextSelection(baseOffset: 3, extentOffset: 6),
    );
    final lineBox = _globalBox(
      tester,
      paragraph,
      const TextSelection(baseOffset: 0, extentOffset: 2),
      heightStyle: ui.BoxHeightStyle.max,
    );

    expect(rubyBox.bottom, closeTo(prefix.bottom, 2.0));
    expect(rubyBox.bottom, closeTo(suffix.bottom, 2.0));
    // Old Stack/bottom alignment sat on the line box and dropped the kanji.
    expect(lineBox.bottom - rubyBox.bottom, greaterThan(4));
    expect(rubyBox.top, lessThan(prefix.top - 6));
    expect(rubyRo.alphabeticBaseline, greaterThan(rubyRo.size.height * 0.45));
  });

  testWidgets('captures HTML-style ruby on the body baseline', (tester) async {
    tester.view.physicalSize = const Size(1800, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const captureKey = Key('ruby-capture');
    const displayStyle = TextStyle(
      fontSize: 40,
      height: 1.8,
      fontFamily: _cjkFamily,
      color: Color(0xFF1A1A1A),
    );
    const labelStyle = TextStyle(
      fontSize: 14,
      height: 1.2,
      fontFamily: _cjkFamily,
      color: Color(0xFF666666),
    );

    await tester.pumpWidget(
      _rubyApp(
        captureKey: captureKey,
        surface: const Size(800, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Flutter reader — HTML <ruby> layout',
              style: labelStyle,
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: displayStyle,
                children: [
                  const TextSpan(text: '彼は'),
                  novelRubySpan(base: '走', ruby: 'はし', style: displayStyle),
                  const TextSpan(text: 'った。'),
                  novelRubySpan(base: '物語', ruby: 'ものがたり', style: displayStyle),
                  const TextSpan(text: '。'),
                ],
              ),
            ),
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
      final file = File('/opt/cursor/artifacts/novel_ruby_html_style.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      expect(file.existsSync(), isTrue);
    });
  });
}
