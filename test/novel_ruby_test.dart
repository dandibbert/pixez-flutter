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
    final paragraphBox = tester.getRect(find.byType(RichText).first);
    expect(paragraphBox.height, lessThan(80));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).first,
    );
    final plain = paragraph.text.toPlainText();
    final baseAt = plain.indexOf('走');
    expect(baseAt, greaterThan(0));
    final baseBox = _globalBox(
      tester,
      paragraph,
      TextSelection(baseOffset: baseAt, extentOffset: baseAt + 1),
    );
    expect(baseBox.width, lessThan(80));
    expect(baseBox.width, greaterThan(8));
    expect(baseBox.left, greaterThan(paragraphBox.left + 10));
    expect(baseBox.right, lessThan(paragraphBox.right - 10));
    final rubyBox = tester.getRect(find.byType(NovelRubyText));
    expect(rubyBox.top, lessThan(baseBox.top));
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
    final plain = paragraph.text.toPlainText();
    final baseAt = plain.indexOf('走');
    final suffixAt = plain.indexOf('った。');
    expect(baseAt, 3);
    expect(suffixAt, greaterThan(baseAt));
    final prefix = _globalBox(
      tester,
      paragraph,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    final base = _globalBox(
      tester,
      paragraph,
      TextSelection(baseOffset: baseAt, extentOffset: baseAt + 1),
    );
    final suffix = _globalBox(
      tester,
      paragraph,
      TextSelection(baseOffset: suffixAt, extentOffset: suffixAt + 3),
    );
    final lineBox = _globalBox(
      tester,
      paragraph,
      const TextSelection(baseOffset: 0, extentOffset: 2),
      heightStyle: ui.BoxHeightStyle.max,
    );

    expect(base.bottom, closeTo(prefix.bottom, 2.0));
    expect(base.bottom, closeTo(suffix.bottom, 2.0));
    // Old Stack/bottom alignment sat on the line box and dropped the kanji.
    expect(lineBox.bottom - base.bottom, greaterThan(4));
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

  testWidgets('selection includes the ruby base instead of skipping it', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          onSelectionChanged: (value) => selected = value?.plainText,
          child: Text.rich(
            TextSpan(
              style: _style,
              children: [
                const TextSpan(text: '彼は'),
                novelRubySpan(base: '走', ruby: 'はし', style: _style),
                const TextSpan(text: 'った'),
                novelRubySpan(base: '物語', ruby: 'ものがたり', style: _style),
                const TextSpan(text: '。'),
              ],
            ),
          ),
        ),
      ),
    );

    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll();
    await tester.pump();

    expect(selected, '彼は走った物語。');
    expect(selected, isNot(contains('\uFFFC')));
    expect(selected, isNot(contains('はし')));
    expect(selected, isNot(contains('ものがたり')));
  });
}
