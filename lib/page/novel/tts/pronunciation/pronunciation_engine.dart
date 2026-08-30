enum PronunciationScope { global, author, series, novel }

class PronunciationContext {
  const PronunciationContext({this.novelId, this.seriesId, this.authorId});
  final String? novelId;
  final String? seriesId;
  final String? authorId;
}

class PronunciationRule {
  const PronunciationRule({
    required this.id,
    required this.surface,
    required this.reading,
    required this.scope,
    this.scopeId,
    this.priority = 0,
    this.enabled = true,
    this.overridePixivRuby = false,
  });
  final String id;
  final String surface;
  final String reading;
  final PronunciationScope scope;
  final String? scopeId;
  final int priority;
  final bool enabled;
  final bool overridePixivRuby;
}

class PronunciationRuby {
  const PronunciationRuby({
    required this.start,
    required this.end,
    required this.reading,
  });
  final int start;
  final int end;
  final String reading;
}

class PronunciationRange {
  const PronunciationRange(this.start, this.end);
  final int start;
  final int end;
}

class PronunciationResult {
  const PronunciationResult({
    required this.displayText,
    required this.spokenText,
    required this.ssml,
    required this.protectedRanges,
  });
  final String displayText;
  final String spokenText;
  final String ssml;
  final List<PronunciationRange> protectedRanges;
}

class _Candidate {
  const _Candidate({
    required this.start,
    required this.end,
    required this.reading,
    required this.specificity,
    required this.overrideRuby,
    required this.priority,
    required this.order,
    required this.ruby,
  });
  final int start;
  final int end;
  final String reading;
  final int specificity;
  final bool overrideRuby;
  final int priority;
  final int order;
  final bool ruby;
  int get length => end - start;
}

class PronunciationEngine {
  PronunciationResult apply(
    String original,
    List<PronunciationRule> rules,
    PronunciationContext context, {
    List<PronunciationRuby> ruby = const [],
  }) {
    final rubyCandidates = <_Candidate>[
      for (var index = 0; index < ruby.length; index++)
        if (ruby[index].start >= 0 &&
            ruby[index].end <= original.length &&
            ruby[index].start < ruby[index].end)
          _Candidate(
            start: ruby[index].start,
            end: ruby[index].end,
            reading: ruby[index].reading,
            specificity: 5,
            overrideRuby: false,
            priority: 0,
            order: index,
            ruby: true,
          ),
    ];
    final candidates = <_Candidate>[];
    for (var order = 0; order < rules.length; order++) {
      final rule = rules[order];
      if (!_applies(rule, context) ||
          rule.surface.isEmpty ||
          rule.reading.isEmpty) {
        continue;
      }
      var start = 0;
      while (start <= original.length - rule.surface.length) {
        final found = original.indexOf(rule.surface, start);
        if (found < 0) break;
        final end = found + rule.surface.length;
        final overlapsRuby = rubyCandidates.any(
          (candidate) => found < candidate.end && end > candidate.start,
        );
        if (!overlapsRuby || rule.overridePixivRuby) {
          candidates.add(
            _Candidate(
              start: found,
              end: end,
              reading: rule.reading,
              specificity: _specificity(rule.scope),
              overrideRuby: rule.overridePixivRuby,
              priority: rule.priority,
              order: order,
              ruby: false,
            ),
          );
        }
        start = found + 1;
      }
    }
    candidates.addAll(
      rubyCandidates.where((rubyCandidate) {
        return !candidates.any(
          (candidate) =>
              candidate.overrideRuby &&
              candidate.start < rubyCandidate.end &&
              candidate.end > rubyCandidate.start,
        );
      }),
    );
    candidates.sort(_compare);
    final selected = <_Candidate>[];
    for (final candidate in candidates) {
      if (selected.any(
        (other) => candidate.start < other.end && candidate.end > other.start,
      )) {
        continue;
      }
      selected.add(candidate);
    }
    selected.sort((a, b) => a.start.compareTo(b.start));

    final spoken = StringBuffer();
    final ssml = StringBuffer('<speak>');
    final protected = <PronunciationRange>[];
    var cursor = 0;
    for (final candidate in selected) {
      final plain = original.substring(cursor, candidate.start);
      spoken.write(plain);
      ssml.write(_xml(plain));
      final surface = original.substring(candidate.start, candidate.end);
      spoken.write(candidate.reading);
      ssml
        ..write('<sub alias="')
        ..write(_xml(candidate.reading))
        ..write('">')
        ..write(_xml(surface))
        ..write('</sub>');
      protected.add(PronunciationRange(candidate.start, candidate.end));
      cursor = candidate.end;
    }
    final tail = original.substring(cursor);
    spoken.write(tail);
    ssml
      ..write(_xml(tail))
      ..write('</speak>');
    return PronunciationResult(
      displayText: original,
      spokenText: spoken.toString(),
      ssml: ssml.toString(),
      protectedRanges: List.unmodifiable(protected),
    );
  }

  bool _applies(PronunciationRule rule, PronunciationContext context) {
    if (!rule.enabled) return false;
    return switch (rule.scope) {
      PronunciationScope.global => true,
      PronunciationScope.author => rule.scopeId == context.authorId,
      PronunciationScope.series => rule.scopeId == context.seriesId,
      PronunciationScope.novel => rule.scopeId == context.novelId,
    };
  }

  int _specificity(PronunciationScope scope) => switch (scope) {
    PronunciationScope.global => 0,
    PronunciationScope.author => 1,
    PronunciationScope.series => 2,
    PronunciationScope.novel => 3,
  };

  int _compare(_Candidate a, _Candidate b) {
    if (a.ruby != b.ruby && !a.overrideRuby && !b.overrideRuby) {
      return a.ruby ? -1 : 1;
    }
    var result = b.specificity.compareTo(a.specificity);
    if (result != 0) return result;
    result = (b.overrideRuby ? 1 : 0).compareTo(a.overrideRuby ? 1 : 0);
    if (result != 0) return result;
    result = b.priority.compareTo(a.priority);
    if (result != 0) return result;
    result = b.length.compareTo(a.length);
    if (result != 0) return result;
    result = a.start.compareTo(b.start);
    if (result != 0) return result;
    return a.order.compareTo(b.order);
  }

  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
