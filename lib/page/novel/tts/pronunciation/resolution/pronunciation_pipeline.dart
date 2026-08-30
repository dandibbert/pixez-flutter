import 'package:pixez/page/novel/tts/pronunciation/matching/overlap_resolver.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/pronunciation_worker.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/japanese_name_disambiguator.dart';

class PronunciationPipeline {
  PronunciationPipeline({
    PronunciationWorker? worker,
    JapaneseNameDisambiguator disambiguator = const JapaneseNameDisambiguator(),
  }) : _worker = worker ?? PronunciationWorker(),
       _disambiguator = disambiguator;

  final PronunciationWorker _worker;
  final JapaneseNameDisambiguator _disambiguator;

  PronunciationWorker get worker => _worker;

  Future<ResolvedPronunciationText> resolve({
    required NovelTtsTextDocument document,
    required PronunciationSnapshot snapshot,
    String sessionId = 'session',
    int? generation,
  }) async {
    final source = document.displayText;
    final gen = generation ?? _worker.sessionGeneration;
    final decisions = <PronunciationDecision>[
      ..._rubyDecisions(document),
      ..._exactDecisions(source, snapshot),
    ];
    final protected = resolvePronunciationOverlaps(decisions);
    final appliedProtected = [
      for (final decision in protected)
        if (decision.isApplied) decision,
    ];
    final aliases = _aliasCandidates(source, snapshot, appliedProtected);
    if (aliases.isEmpty) {
      return ResolvedPronunciationText(
        displayText: source,
        appliedDecisions: appliedProtected,
        allDecisions: protected,
        snapshotFingerprint: snapshot.fingerprint,
        analyzerCapability: _worker.capability,
      );
    }
    final analyzerReady = await _worker.warmUp();
    if (generation != null && generation != _worker.sessionGeneration) {
      return ResolvedPronunciationText(
        displayText: source,
        appliedDecisions: appliedProtected,
        allDecisions: [
          ...protected,
          for (final candidate in aliases)
            _skipped(source, candidate, PronunciationReason.staleSession),
        ],
        snapshotFingerprint: snapshot.fingerprint,
        analyzerCapability: _worker.capability,
      );
    }
    for (final region in _analysisRegions(source, aliases)) {
      final regionText = source.substring(region.start, region.end);
      final morphology = analyzerReady
          ? await _worker.analyzeRegion(
              text: regionText,
              requestId: '$sessionId:${region.start}',
              generation: gen,
            )
          : null;
      for (final candidate in aliases) {
        if (candidate.start < region.start || candidate.end > region.end) {
          continue;
        }
        final local = PronunciationCandidate(
          start: candidate.start - region.start,
          end: candidate.end - region.start,
          rule: candidate.rule,
        );
        final decision = _disambiguator.decide(
          source: regionText,
          candidate: local,
          morphology: morphology,
          analyzerAvailable: analyzerReady && (morphology?.valid ?? false),
        );
        decisions.add(
          PronunciationDecision(
            start: decision.start + region.start,
            end: decision.end + region.start,
            surface: decision.surface,
            reading: decision.reading,
            ruleId: decision.ruleId,
            status: decision.status,
            reason: decision.reason,
            locked: decision.locked,
          ),
        );
      }
    }
    final resolved = resolvePronunciationOverlaps(decisions);
    return ResolvedPronunciationText(
      displayText: source,
      appliedDecisions: [
        for (final decision in resolved)
          if (decision.isApplied) decision,
      ]..sort((a, b) => a.start.compareTo(b.start)),
      allDecisions: resolved,
      snapshotFingerprint: snapshot.fingerprint,
      analyzerCapability: _worker.capability,
    );
  }

  List<PronunciationDecision> _rubyDecisions(NovelTtsTextDocument document) {
    return [
      for (final ruby in document.rubyAnnotations)
        if (ruby.surface.isNotEmpty &&
            ruby.reading.isNotEmpty &&
            ruby.start >= 0 &&
            ruby.end <= document.displayText.length &&
            document.displayText.substring(ruby.start, ruby.end) == ruby.surface)
          PronunciationDecision(
            start: ruby.start,
            end: ruby.end,
            surface: ruby.surface,
            reading: ruby.reading,
            ruleId: 'ruby:${ruby.start}:${ruby.end}',
            status: PronunciationDecisionStatus.applied,
            reason: PronunciationReason.explicitRuby,
            locked: true,
          ),
    ];
  }

  List<PronunciationDecision> _exactDecisions(
    String source,
    PronunciationSnapshot snapshot,
  ) {
    final hits = snapshot.compiledIndex.exactTrie.scan(source);
    final grouped = <String, List<PronunciationCandidate>>{};
    for (final hit in hits) {
      grouped.putIfAbsent('${hit.start}:${hit.end}', () => []).add(hit);
    }
    final decisions = <PronunciationDecision>[];
    for (final group in grouped.values) {
      final best = pickPreferredCandidate(group);
      if (best == null) {
        continue;
      }
      if (source.substring(best.start, best.end) != best.rule.surface) {
        decisions.add(
          _skipped(source, best, PronunciationReason.invalidSourceRange),
        );
        continue;
      }
      decisions.add(
        PronunciationDecision(
          start: best.start,
          end: best.end,
          surface: best.rule.surface,
          reading: best.rule.reading,
          ruleId: best.rule.id,
          status: PronunciationDecisionStatus.applied,
          reason: best.rule.mode == PronunciationMatchMode.force
              ? PronunciationReason.forcedRule
              : PronunciationReason.exactPhrase,
          locked: false,
        ),
      );
    }
    return decisions;
  }

  List<PronunciationCandidate> _aliasCandidates(
    String source,
    PronunciationSnapshot snapshot,
    List<PronunciationDecision> protected,
  ) {
    final hits = snapshot.compiledIndex.aliasTrie.scan(source);
    final kept = <PronunciationCandidate>[];
    for (final hit in hits) {
      if (protected.any((span) => span.overlaps(hit.start, hit.end))) {
        continue;
      }
      if (source.substring(hit.start, hit.end) != hit.rule.surface) {
        continue;
      }
      kept.add(hit);
    }
    final grouped = <String, List<PronunciationCandidate>>{};
    for (final hit in kept) {
      grouped.putIfAbsent('${hit.start}:${hit.end}', () => []).add(hit);
    }
    return [
      for (final group in grouped.values)
        if (pickPreferredCandidate(group) case final best?) best,
    ];
  }

  List<NovelTtsSourceRange> _analysisRegions(
    String source,
    List<PronunciationCandidate> aliases,
  ) {
    final windows = <NovelTtsSourceRange>[];
    for (final alias in aliases) {
      final sentence = _sentenceWindow(source, alias.start, alias.end);
      windows.add(sentence);
    }
    windows.sort((a, b) => a.start.compareTo(b.start));
    final merged = <NovelTtsSourceRange>[];
    for (final window in windows) {
      if (merged.isEmpty || window.start > merged.last.end + 8) {
        merged.add(window);
      } else {
        merged[merged.length - 1] = NovelTtsSourceRange(
          merged.last.start,
          window.end > merged.last.end ? window.end : merged.last.end,
        );
      }
    }
    return merged;
  }

  NovelTtsSourceRange _sentenceWindow(String source, int start, int end) {
    var from = start;
    while (from > 0 && !_isSentenceEnd(source[from - 1])) {
      from--;
    }
    var to = end;
    while (to < source.length && !_isSentenceEnd(source[to])) {
      to++;
    }
    if (to < source.length) {
      to++;
    }
    if (to - from > PronunciationLimits.maxRegionChars) {
      from = start;
      to = end;
    }
    return NovelTtsSourceRange(from, to);
  }

  bool _isSentenceEnd(String char) {
    return char == '。' || char == '！' || char == '？' || char == '\n' ||
        char == '!' || char == '?';
  }

  PronunciationDecision _skipped(
    String source,
    PronunciationCandidate candidate,
    PronunciationReason reason,
  ) {
    return PronunciationDecision(
      start: candidate.start,
      end: candidate.end,
      surface: source.substring(candidate.start, candidate.end),
      reading: candidate.rule.reading,
      ruleId: candidate.rule.id,
      status: PronunciationDecisionStatus.skipped,
      reason: reason,
      locked: false,
    );
  }
}
