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
}) {
  final rubyStyle = style.copyWith(
    fontSize: (style.fontSize ?? 16) * 0.55,
    height: 1.0,
  );
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: NovelRubyText(
      base: base,
      ruby: ruby,
      baseStyle: style,
      rubyStyle: rubyStyle,
    ),
  );
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
  });

  final String base;
  final String ruby;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;

  @override
  RenderNovelRuby createRenderObject(BuildContext context) {
    return RenderNovelRuby(
      base: base,
      ruby: ruby,
      baseStyle: baseStyle,
      rubyStyle: rubyStyle,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderNovelRuby renderObject) {
    renderObject
      ..base = base
      ..ruby = ruby
      ..baseStyle = baseStyle
      ..rubyStyle = rubyStyle
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr
      ..textScaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
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
  }) : _base = base,
       _ruby = ruby,
       _baseStyle = baseStyle,
       _rubyStyle = rubyStyle,
       _textDirection = textDirection,
       _textScaler = textScaler,
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
    return Size(
      math.max(_basePainter.width, _rubyPainter.width),
      _rubyBoxHeight + _basePainter.height,
    );
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
  double computeMinIntrinsicHeight(double width) => _intrinsicSize(width).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicSize(width).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(_intrinsicSize(constraints.maxWidth));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    _layoutPainters(
      hasSize ? constraints.maxWidth : double.infinity,
    );
    return _rubyBoxHeight + _basePainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final width = size.width;
    if (_ruby.isNotEmpty) {
      _rubyPainter.paint(
        canvas,
        offset + Offset((width - _rubyPainter.width) / 2, 0),
      );
    }
    _basePainter.paint(
      canvas,
      offset + Offset((width - _basePainter.width) / 2, _rubyBoxHeight),
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _ruby.isEmpty ? _base : '$_base $_ruby';
  }

  @override
  void dispose() {
    _basePainter.dispose();
    _rubyPainter.dispose();
    super.dispose();
  }
}
