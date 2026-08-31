import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/phrase_trie.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

class CompiledPronunciationIndex {
  CompiledPronunciationIndex({
    required this.exactTrie,
    required this.aliasTrie,
    required this.activeRules,
  });

  final PhraseTrie exactTrie;
  final PhraseTrie aliasTrie;
  final List<PronunciationRule> activeRules;
}

class PronunciationSnapshot {
  const PronunciationSnapshot({
    required this.fingerprint,
    required this.schemaVersion,
    required this.pipelineVersion,
    required this.activeRules,
    required this.compiledIndex,
  });

  final String fingerprint;
  final int schemaVersion;
  final int pipelineVersion;
  final List<PronunciationRule> activeRules;
  final CompiledPronunciationIndex compiledIndex;
}

class PronunciationCompiler {
  PronunciationSnapshot compile(
    Iterable<PronunciationRule> rules, {
    String? workId,
    String? seriesId,
  }) {
    final active = [
      for (final rule in rules)
        if (rule.enabled &&
            rule.isValid &&
            rule.scope.appliesTo(workId: workId, seriesId: seriesId))
          rule,
    ]..sort(_compareRules);
    final exact = [
      for (final rule in active)
        if (rule.mode != PronunciationMatchMode.nameAlias) rule,
    ];
    final aliases = [
      for (final rule in active)
        if (rule.mode == PronunciationMatchMode.nameAlias) rule,
    ];
    return PronunciationSnapshot(
      fingerprint: fingerprintFor(active),
      schemaVersion: PronunciationLimits.schemaVersion,
      pipelineVersion: PronunciationLimits.pipelineVersion,
      activeRules: List.unmodifiable(active),
      compiledIndex: CompiledPronunciationIndex(
        exactTrie: PhraseTrie(exact),
        aliasTrie: PhraseTrie(aliases),
        activeRules: active,
      ),
    );
  }

  static String fingerprintFor(Iterable<PronunciationRule> rules) {
    final rows = [
      for (final rule in rules)
        [
          rule.id,
          rule.surface,
          rule.reading,
          rule.mode.name,
          rule.scope.type.name,
          rule.scope.scopeId ?? '',
          rule.priority,
          rule.enabled,
          rule.updatedAtEpochMs,
        ],
    ]..sort((a, b) => (a[0] as String).compareTo(b[0] as String));
    final material = jsonEncode({
      'schemaVersion': PronunciationLimits.schemaVersion,
      'pipelineVersion': PronunciationLimits.pipelineVersion,
      'rules': rows,
    });
    return sha256.convert(utf8.encode(material)).toString();
  }
}

int _compareRules(PronunciationRule a, PronunciationRule b) {
  final scope = b.scope.rank.compareTo(a.scope.rank);
  if (scope != 0) {
    return scope;
  }
  final priority = b.priority.compareTo(a.priority);
  if (priority != 0) {
    return priority;
  }
  final length = b.surface.length.compareTo(a.surface.length);
  if (length != 0) {
    return length;
  }
  return a.id.compareTo(b.id);
}

int comparePronunciationPriority(PronunciationRule a, PronunciationRule b) {
  return _compareRules(a, b);
}
