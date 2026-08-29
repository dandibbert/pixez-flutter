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

/// Shrink-wrapped ruby so the inline box is only as wide as the longer of
/// the base or the reading. Top padding keeps the reading above the base
/// while the reported baseline stays on the base text.
class NovelRubyText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final rubySize = rubyStyle.fontSize ?? ((baseStyle.fontSize ?? 16) * 0.55);
    final rubyHeight = ruby.isEmpty ? 0.0 : rubySize * (rubyStyle.height ?? 1.0);
    return IntrinsicWidth(
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: rubyHeight),
            child: Text(
              base,
              style: baseStyle,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
          if (ruby.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Text(
                ruby,
                style: rubyStyle,
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
