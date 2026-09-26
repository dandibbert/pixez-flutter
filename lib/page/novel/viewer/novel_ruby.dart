import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

class NovelRubyParts {
  const NovelRubyParts({required this.base, required this.ruby});

  final String base;
  final String ruby;

  String get encoded => ruby.isEmpty ? base : '$base>$ruby';
}

/// Pixiv novels use `[[rb:漢字＞かな]]`. Some sources use halfwidth `>`.
NovelRubyParts parseNovelRubyPayload(String payload) {
  final fullwidth = payload.indexOf('＞');
  final halfwidth = payload.indexOf('>');
  var splitAt = -1;
  if (fullwidth >= 0 && (halfwidth < 0 || fullwidth <= halfwidth)) {
    splitAt = fullwidth;
  } else if (halfwidth >= 0) {
    splitAt = halfwidth;
  }
  if (splitAt < 0) {
    return NovelRubyParts(base: payload, ruby: '');
  }
  return NovelRubyParts(
    base: payload.substring(0, splitAt),
    ruby: payload.substring(splitAt + 1),
  );
}

NovelRubyParts? parseNovelRubyMarkup(String spanStr) {
  if (!spanStr.startsWith('[[rb:')) {
    return null;
  }
  final inner = spanStr.substring('[[rb:'.length).replaceAll(']', '');
  return parseNovelRubyPayload(inner);
}

InlineSpan novelRubySpan({
  required String base,
  required String ruby,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  if (ruby.isEmpty) {
    return TextSpan(text: base, style: style);
  }
  final rubyStyle = style.copyWith(
    fontSize: (style.fontSize ?? 16) * 0.55,
    height: 1.0,
  );
  // The base has to be a real [TextSpan]. A [WidgetSpan] is one placeholder
  // code unit, and selectable text skips that unit, so copying a ruby word
  // used to drop the kanji. Side pads keep a wider reading centered without
  // inserting extra characters into the selection.
  final baseWidth = _measureSpanWidth(base, style, textScaler, textDirection);
  final rubyWidth = _measureSpanWidth(
    ruby,
    rubyStyle,
    textScaler,
    textDirection,
  );
  final extra = math.max(0.0, rubyWidth - baseWidth);
  final leftPad = extra / 2;
  final rightPad = extra - leftPad;
  final groupWidth = leftPad + baseWidth + rightPad;
  return TextSpan(
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: NovelRubyText(
          base: base,
          ruby: ruby,
          baseStyle: style,
          rubyStyle: rubyStyle,
          layoutWidth: leftPad,
          groupWidth: groupWidth,
          textScaler: textScaler,
          textDirection: textDirection,
        ),
      ),
      TextSpan(text: base, style: style),
      if (rightPad >= 0.5)
        WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: SizedBox(width: rightPad, height: 1),
        ),
    ],
  );
}

double _measureSpanWidth(
  String text,
  TextStyle style,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  if (text.isEmpty) {
    return 0;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// HTML `<ruby>` / pixvel / official Pixiv: the base stays on the surrounding
/// line, and the reading sits above it. The inline box reports the **base**
/// alphabetic baseline so [WidgetSpan] cannot pick the reading instead.
class NovelRubyText extends LeafRenderObjectWidget {
  const NovelRubyText({
    super.key,
    required this.base,
    required this.ruby,
    required this.baseStyle,
    required this.rubyStyle,
    this.layoutWidth = 0,
    this.groupWidth = 0,
    this.textScaler = TextScaler.noScaling,
    this.textDirection = TextDirection.ltr,
  });

  final String base;
  final String ruby;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;

  /// Inline advance of this placeholder. The base glyphs live in the following
  /// [TextSpan], so this is only the left padding that centers a wider reading.
  final double layoutWidth;

  /// Width of the left pad, the base, and the right pad. The reading is
  /// centered across that group.
  final double groupWidth;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  RenderNovelRuby createRenderObject(BuildContext context) {
    return RenderNovelRuby(
      base: base,
      ruby: ruby,
      baseStyle: baseStyle,
      rubyStyle: rubyStyle,
      textDirection: textDirection,
      textScaler: textScaler,
      layoutWidth: layoutWidth,
      groupWidth: groupWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderNovelRuby renderObject) {
    renderObject
      ..base = base
      ..ruby = ruby
      ..baseStyle = baseStyle
      ..rubyStyle = rubyStyle
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..layoutWidth = layoutWidth
      ..groupWidth = groupWidth;
  }
}

class RenderNovelRuby extends RenderBox {
  RenderNovelRuby({
    required String base,
    required String ruby,
    required TextStyle baseStyle,
    required TextStyle rubyStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double layoutWidth,
    required double groupWidth,
  }) : _base = base,
       _ruby = ruby,
       _baseStyle = baseStyle,
       _rubyStyle = rubyStyle,
       _textDirection = textDirection,
       _textScaler = textScaler,
       _layoutWidth = layoutWidth,
       _groupWidth = groupWidth,
       _basePainter = TextPainter(maxLines: 1, ellipsis: ''),
       _rubyPainter = TextPainter(maxLines: 1, ellipsis: '');

  final TextPainter _basePainter;
  final TextPainter _rubyPainter;

  String _base;
  String get base => _base;
  set base(String value) {
    if (_base == value) {
      return;
    }
    _base = value;
    markNeedsLayout();
  }

  String _ruby;
  String get ruby => _ruby;
  set ruby(String value) {
    if (_ruby == value) {
      return;
    }
    _ruby = value;
    markNeedsLayout();
  }

  TextStyle _baseStyle;
  TextStyle get baseStyle => _baseStyle;
  set baseStyle(TextStyle value) {
    if (_baseStyle == value) {
      return;
    }
    _baseStyle = value;
    markNeedsLayout();
  }

  TextStyle _rubyStyle;
  TextStyle get rubyStyle => _rubyStyle;
  set rubyStyle(TextStyle value) {
    if (_rubyStyle == value) {
      return;
    }
    _rubyStyle = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) {
      return;
    }
    _textScaler = value;
    markNeedsLayout();
  }

  double _layoutWidth;
  double get layoutWidth => _layoutWidth;
  set layoutWidth(double value) {
    if (_layoutWidth == value) {
      return;
    }
    _layoutWidth = value;
    markNeedsLayout();
  }

  double _groupWidth;
  double get groupWidth => _groupWidth;
  set groupWidth(double value) {
    if (_groupWidth == value) {
      return;
    }
    _groupWidth = value;
    markNeedsPaint();
  }

  /// Tight box like a browser `<ruby>`: reading flush above the base glyphs.
  TextStyle get _packedBaseStyle => _baseStyle.copyWith(height: 1.0);

  TextStyle get _packedRubyStyle => _rubyStyle.copyWith(height: 1.0);

  void _syncPainters() {
    _basePainter
      ..text = TextSpan(text: _base, style: _packedBaseStyle)
      ..textDirection = _textDirection
      ..textScaler = _textScaler;
    _rubyPainter
      ..text = TextSpan(text: _ruby, style: _packedRubyStyle)
      ..textDirection = _textDirection
      ..textScaler = _textScaler;
  }

  void _layoutPainters(double maxWidth) {
    _syncPainters();
    final width = maxWidth.isFinite ? math.max(maxWidth, 0.0) : double.infinity;
    _basePainter.layout(minWidth: 0, maxWidth: width);
    if (_ruby.isEmpty) {
      _rubyPainter.text = const TextSpan(text: '');
      _rubyPainter.layout(minWidth: 0, maxWidth: width);
      return;
    }
    _rubyPainter.layout(minWidth: 0, maxWidth: width);
  }

  Size _intrinsicSize(double maxWidth) {
    _layoutPainters(maxWidth);
    return Size(_layoutWidth, _rubyBoxHeight + _basePainter.height);
  }

  double get _rubyBoxHeight => _ruby.isEmpty ? 0.0 : _rubyPainter.height;

  /// Distance from the top of this box to the base text's alphabetic baseline.
  double get alphabeticBaseline =>
      computeDistanceToActualBaseline(TextBaseline.alphabetic)!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicSize(double.infinity).width;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicSize(double.infinity).width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicSize(width).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicSize(width).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(_intrinsicSize(constraints.maxWidth));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  double _baselineFor(double maxWidth, TextBaseline baseline) {
    _layoutPainters(maxWidth);
    return _rubyBoxHeight +
        _basePainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return _baselineFor(
      hasSize ? constraints.maxWidth : double.infinity,
      baseline,
    );
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return _baselineFor(constraints.maxWidth, baseline);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_ruby.isEmpty) {
      return;
    }
    final canvas = context.canvas;
    final group = _groupWidth > 0
        ? _groupWidth
        : math.max(_basePainter.width, _rubyPainter.width);
    _rubyPainter.paint(
      canvas,
      offset + Offset((group - _rubyPainter.width) / 2, 0),
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // The base is already in the following [TextSpan]. Labeling it here would
    // make VoiceOver speak the kanji twice.
    config
      ..isSemanticBoundary = true
      ..textDirection = _textDirection
      ..label = _ruby;
  }

  @override
  void dispose() {
    _basePainter.dispose();
    _rubyPainter.dispose();
    super.dispose();
  }
}
