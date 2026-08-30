import 'package:characters/characters.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';

class NaturalTextSegment {
  const NaturalTextSegment({
    required this.start,
    required this.end,
    required this.text,
  });
  final int start;
  final int end;
  final String text;
}

class NaturalTextSegmenter {
  const NaturalTextSegmenter({
    required this.targetLength,
    required this.maxLength,
    this.minLength,
  });
  final int targetLength;
  final int maxLength;
  final int? minLength;

  List<NaturalTextSegment> split(
    String text, {
    List<PronunciationRange> protectedRanges = const [],
  }) {
    if (text.isEmpty) return const [];
    if (targetLength <= 0 || maxLength <= 0 || targetLength > maxLength)
      throw ArgumentError('Invalid segment lengths');
    final graphemes = text.characters.toList(growable: false);
    final offsets = <int>[0];
    var utf16 = 0;
    for (final grapheme in graphemes) {
      utf16 += grapheme.length;
      offsets.add(utf16);
    }
    final result = <NaturalTextSegment>[];
    var startIndex = 0;
    while (startIndex < graphemes.length) {
      final remaining = graphemes.length - startIndex;
      if (remaining <= targetLength) {
        final start = offsets[startIndex];
        result.add(
          NaturalTextSegment(
            start: start,
            end: text.length,
            text: text.substring(start),
          ),
        );
        break;
      }
      final target = (startIndex + targetLength).clamp(
        startIndex + 1,
        graphemes.length,
      );
      final max = (startIndex + maxLength).clamp(
        startIndex + 1,
        graphemes.length,
      );
      final minimum =
          startIndex +
          (minLength ?? (targetLength ~/ 2).clamp(1, targetLength));
      int? chosen;
      var chosenPriority = -1;
      var chosenDistance = 1 << 30;
      for (var index = minimum; index <= max; index++) {
        final boundary = offsets[index];
        if (_insideProtected(boundary, protectedRanges)) continue;
        final priority = _boundaryPriority(text, boundary);
        if (priority < 0) continue;
        final distance = (index - target).abs();
        if (priority > chosenPriority ||
            (priority == chosenPriority && distance < chosenDistance)) {
          chosen = index;
          chosenPriority = priority;
          chosenDistance = distance;
        }
      }
      chosen ??= max;
      var boundary = offsets[chosen];
      final containing = protectedRanges
          .where((range) => boundary > range.start && boundary < range.end)
          .toList();
      if (containing.isNotEmpty) {
        boundary = containing
            .map((range) => range.end)
            .reduce((a, b) => a > b ? a : b);
        chosen = offsets.indexWhere((offset) => offset >= boundary);
        if (chosen < 0) chosen = graphemes.length;
        boundary = offsets[chosen];
      }
      final start = offsets[startIndex];
      result.add(
        NaturalTextSegment(
          start: start,
          end: boundary,
          text: text.substring(start, boundary),
        ),
      );
      startIndex = chosen;
    }
    return List.unmodifiable(result);
  }

  bool _insideProtected(int boundary, List<PronunciationRange> ranges) =>
      ranges.any((range) => boundary > range.start && boundary < range.end);

  int _boundaryPriority(String text, int boundary) {
    if (boundary <= 0) return -1;
    final prefix = text.substring(0, boundary);
    if (prefix.endsWith(String.fromCharCodes(const [10, 10]))) return 6;
    final previous = prefix.characters.last;
    if ('。！？!?'.contains(previous)) return 5;
    if ('；;：:'.contains(previous)) return 4;
    if ('，,、'.contains(previous)) return 3;
    if (previous.codeUnitAt(0) == 10) return 2;
    if (RegExp(r'\s').hasMatch(previous)) return 1;
    return -1;
  }
}
