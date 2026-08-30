import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';

class MorphologyOffsetMapper {
  const MorphologyOffsetMapper();

  MorphologyResult mapToRegion(String region, Iterable<MorphologyToken> raw) {
    final mapped = <MorphologyToken>[];
    var searchFrom = 0;
    for (final token in raw) {
      if (token.surface.isEmpty) {
        continue;
      }
      var start = token.start;
      var end = token.end;
      final inRange =
          start >= 0 &&
          end <= region.length &&
          start < end &&
          region.substring(start, end) == token.surface;
      if (!inRange) {
        final found = _nextSurface(region, token.surface, searchFrom);
        if (found == null) {
          return const MorphologyResult(
            tokens: [],
            valid: false,
            reason: 'invalidAnalyzerOffsets',
          );
        }
        start = found;
        end = found + token.surface.length;
      }
      if (start < searchFrom) {
        return const MorphologyResult(
          tokens: [],
          valid: false,
          reason: 'invalidAnalyzerOffsets',
        );
      }
      final gap = region.substring(searchFrom, start);
      if (gap.isNotEmpty && gap.trim().isNotEmpty) {
        return const MorphologyResult(
          tokens: [],
          valid: false,
          reason: 'invalidAnalyzerOffsets',
        );
      }
      mapped.add(
        MorphologyToken(
          start: start,
          end: end,
          surface: token.surface,
          basicForm: token.basicForm,
          reading: token.reading,
          partOfSpeech: token.partOfSpeech,
          conjugationType: token.conjugationType,
          conjugationForm: token.conjugationForm,
        ),
      );
      searchFrom = end;
    }
    return MorphologyResult(tokens: mapped);
  }

  int? _nextSurface(String region, String surface, int from) {
    var index = region.indexOf(surface, from);
    while (index >= 0) {
      final gap = region.substring(from, index);
      if (gap.trim().isEmpty) {
        return index;
      }
      index = region.indexOf(surface, index + surface.length);
    }
    return null;
  }
}
