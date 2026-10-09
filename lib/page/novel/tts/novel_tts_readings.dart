import 'package:pixez/page/novel/tts/pronunciation/matching/phrase_trie.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';

/// One user dictionary entry, as stored in the TTS settings.
///
/// The settings list is the only copy of the dictionary: it is what the
/// editor shows and what playback compiles, so the two cannot drift.
class NovelTtsReading {
  const NovelTtsReading({
    required this.surface,
    required this.reading,
    this.mode,
    this.id,
    this.enabled = true,
    this.scope = const PronunciationScope(type: PronunciationScopeType.global),
    this.scopeLabel,
    this.updatedAt = 0,
  });

  final String surface;
  final String reading;

  /// The match mode the user picked. Null for entries from the first format,
  /// whose mode is guessed from the written form.
  final PronunciationMatchMode? mode;

  /// Stable across edits and reordering. Null only before the first load.
  final String? id;
  final bool enabled;
  final PronunciationScope scope;

  /// Title of the work or series the entry is limited to, for display.
  final String? scopeLabel;

  /// Milliseconds since epoch of the last edit; 0 for entries that predate it.
  final int updatedAt;

  bool get isValid => surface.trim().isNotEmpty && reading.trim().isNotEmpty;

  /// Why the entry cannot be applied, or null when it can.
  String? get validationError {
    final written = surface.trim();
    final spoken = reading.trim();
    if (written.isEmpty) {
      return 'empty_surface';
    }
    if (spoken.isEmpty) {
      return 'empty_reading';
    }
    if (written.runes.length > PronunciationLimits.maxSurfaceScalars) {
      return 'surface_too_long';
    }
    if (spoken.runes.length > PronunciationLimits.maxReadingScalars) {
      return 'reading_too_long';
    }
    if (written.contains(RegExp(r'[\x00-\x1f]')) ||
        spoken.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'))) {
      return 'control_char';
    }
    return null;
  }

  /// The mode the matcher uses: the picked one, or the guess for old entries.
  PronunciationMatchMode get effectiveMode =>
      mode ??
      const PronunciationMigration().classifyV1Surface(surface.trim()).mode;

  /// Whether playback applies the entry. An old entry the guesser could not
  /// classify safely (a lone kana or ASCII character) stays off until the user
  /// confirms it.
  bool get isActive =>
      enabled &&
      (mode != null ||
          const PronunciationMigration()
              .classifyV1Surface(surface.trim())
              .enabled);

  /// Entries with the same key describe the same written form in the same
  /// scope; only one of them may exist.
  String get dedupeKey =>
      '${scope.type.name}:${scope.scopeId ?? ''}:'
      '${foldPronunciationText(surface.trim())}';

  NovelTtsReading copyWith({
    String? surface,
    String? reading,
    PronunciationMatchMode? mode,
    String? id,
    bool? enabled,
    PronunciationScope? scope,
    String? scopeLabel,
    int? updatedAt,
  }) {
    return NovelTtsReading(
      surface: surface ?? this.surface,
      reading: reading ?? this.reading,
      mode: mode ?? this.mode,
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      scope: scope ?? this.scope,
      scopeLabel: scope == null ? (scopeLabel ?? this.scopeLabel) : scopeLabel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  NovelTtsReading trimmed() {
    return copyWith(surface: surface.trim(), reading: reading.trim());
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'surface': surface,
      'reading': reading,
      if (mode != null) 'mode': mode!.name,
      if (!enabled) 'enabled': false,
      if (scope.type != PronunciationScopeType.global) 'scope': scope.toJson(),
      if (scopeLabel != null && scope.type != PronunciationScopeType.global)
        'scopeLabel': scopeLabel,
      if (updatedAt > 0) 'updatedAt': updatedAt,
    };
  }

  factory NovelTtsReading.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final rawScope = json['scope'];
    return NovelTtsReading(
      id: json['id'] as String?,
      surface: json['surface'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      mode: _modeNamed(modeName),
      enabled: json['enabled'] as bool? ?? true,
      scope: rawScope is Map
          ? PronunciationScope.fromJson(Map<String, dynamic>.from(rawScope))
          : const PronunciationScope(type: PronunciationScopeType.global),
      scopeLabel: json['scopeLabel'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NovelTtsReading &&
        other.surface == surface &&
        other.reading == reading &&
        other.mode == mode &&
        other.enabled == enabled &&
        other.scope == scope;
  }

  @override
  int get hashCode => Object.hash(surface, reading, mode, enabled, scope);
}

var _idCounter = 0;

/// A fresh entry id. Unique within one install, which is all the matcher needs.
String newNovelTtsReadingId([DateTime? now]) {
  final micros = (now ?? DateTime.now()).microsecondsSinceEpoch;
  _idCounter = (_idCounter + 1) & 0xffff;
  return 'r${micros.toRadixString(36)}${_idCounter.toRadixString(36)}';
}

/// Saves [entry] into [readings]: an entry with the same id is replaced in
/// place, a new one is appended. Any other entry for the same written form in
/// the same scope is dropped, so the reading the user just typed is the one
/// playback uses.
List<NovelTtsReading> upsertNovelTtsReading(
  List<NovelTtsReading> readings,
  NovelTtsReading entry,
) {
  final key = entry.dedupeKey;
  final own = entry.id == null
      ? -1
      : readings.indexWhere((existing) => existing.id == entry.id);
  final next = <NovelTtsReading>[];
  var placed = false;
  for (var i = 0; i < readings.length; i++) {
    final existing = readings[i];
    if (i == own) {
      next.add(entry);
      placed = true;
    } else if (existing.dedupeKey == key) {
      // A new entry takes the place of the one it replaces.
      if (own < 0 && !placed) {
        next.add(entry);
        placed = true;
      }
    } else {
      next.add(existing);
    }
  }
  if (!placed) {
    next.add(entry);
  }
  return next;
}

/// The entry in [readings] that [entry] would replace when saved, other than
/// itself.
NovelTtsReading? conflictingNovelTtsReading(
  List<NovelTtsReading> readings,
  NovelTtsReading entry,
) {
  final key = entry.dedupeKey;
  for (final existing in readings) {
    if (existing.id != null && existing.id == entry.id) {
      continue;
    }
    if (existing.dedupeKey == key) {
      return existing;
    }
  }
  return null;
}

class NovelTtsReadingMerge {
  const NovelTtsReadingMerge({
    required this.readings,
    required this.added,
    required this.updated,
    required this.unchanged,
  });

  final List<NovelTtsReading> readings;
  final int added;
  final int updated;
  final int unchanged;
}

/// Adds imported entries. An entry for a written form that already exists in
/// the same scope replaces that entry's reading instead of becoming a
/// duplicate; within [incoming], the last line wins.
NovelTtsReadingMerge mergeNovelTtsReadings(
  List<NovelTtsReading> existing,
  Iterable<NovelTtsReading> incoming, {
  int? nowMs,
}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final next = [...existing];
  final addedKeys = <String>{};
  var added = 0;
  var updated = 0;
  var unchanged = 0;
  for (final raw in incoming) {
    final entry = raw.trimmed();
    if (!entry.isValid) {
      continue;
    }
    final key = entry.dedupeKey;
    final index = next.indexWhere((item) => item.dedupeKey == key);
    if (index < 0) {
      next.add(
        entry.copyWith(
          id: entry.id ?? newNovelTtsReadingId(),
          mode: entry.mode ?? defaultNovelTtsReadingMode(entry.surface),
          updatedAt: now,
        ),
      );
      addedKeys.add(key);
      added++;
      continue;
    }
    final old = next[index];
    final mode =
        entry.mode ?? old.mode ?? defaultNovelTtsReadingMode(entry.surface);
    if (old.reading == entry.reading && old.mode == mode && old.enabled) {
      if (!addedKeys.contains(key)) {
        unchanged++;
      }
      continue;
    }
    next[index] = old.copyWith(
      surface: entry.surface,
      reading: entry.reading,
      mode: mode,
      enabled: true,
      updatedAt: now,
    );
    if (!addedKeys.contains(key)) {
      updated++;
    }
  }
  return NovelTtsReadingMerge(
    readings: next,
    added: added,
    updated: updated,
    unchanged: unchanged,
  );
}

/// The mode a new entry starts with: a longer written form is replaced
/// verbatim, a lone kanji goes through the name check, and a lone kana or
/// symbol can only be forced.
PronunciationMatchMode defaultNovelTtsReadingMode(String surface) {
  final trimmed = surface.trim();
  if (trimmed.isEmpty) {
    return PronunciationMatchMode.exactPhrase;
  }
  return const PronunciationMigration().classifyV1Surface(trimmed).mode;
}

/// Replaces written forms with readings. Longer surfaces win, and a match
/// consumes that span so a shorter rule cannot fire inside it.
String applyNovelTtsReadings(String text, Iterable<NovelTtsReading> readings) {
  final rules = [
    for (final reading in readings)
      if (reading.isValid) reading.trimmed(),
  ]..sort((a, b) => b.surface.length.compareTo(a.surface.length));
  if (rules.isEmpty || text.isEmpty) {
    return text;
  }
  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    NovelTtsReading? hit;
    for (final rule in rules) {
      if (text.startsWith(rule.surface, index)) {
        hit = rule;
        break;
      }
    }
    if (hit != null) {
      buffer.write(hit.reading);
      index += hit.surface.length;
    } else {
      buffer.write(text[index]);
      index++;
    }
  }
  return buffer.toString();
}

/// Tags a line may end with to pick the match mode, as in `悟=さとる|alias`.
const novelTtsReadingModeTags = <String, PronunciationMatchMode>{
  'exact': PronunciationMatchMode.exactPhrase,
  'alias': PronunciationMatchMode.nameAlias,
  'name': PronunciationMatchMode.nameAlias,
  'force': PronunciationMatchMode.force,
};

String _modeTag(PronunciationMatchMode mode) {
  switch (mode) {
    case PronunciationMatchMode.exactPhrase:
      return 'exact';
    case PronunciationMatchMode.nameAlias:
      return 'alias';
    case PronunciationMatchMode.force:
      return 'force';
  }
}

NovelTtsReading? parseNovelTtsReadingLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) {
    return null;
  }
  final eq = trimmed.indexOf('=');
  final tab = trimmed.indexOf('\t');
  final colon = trimmed.indexOf(':');
  var split = -1;
  if (eq > 0 && (tab < 0 || eq < tab)) {
    split = eq;
  } else if (tab > 0) {
    split = tab;
  } else if (colon > 0 && !trimmed.substring(colon + 1).startsWith('/')) {
    split = colon;
  } else {
    final slash = trimmed.indexOf('/');
    if (slash > 0) {
      split = slash;
    }
  }
  if (split <= 0) {
    return null;
  }
  var spoken = trimmed.substring(split + 1);
  PronunciationMatchMode? mode;
  final bar = spoken.lastIndexOf('|');
  if (bar >= 0) {
    final tag = spoken.substring(bar + 1).trim().toLowerCase();
    if (novelTtsReadingModeTags[tag] case final tagged?) {
      mode = tagged;
      spoken = spoken.substring(0, bar);
    }
  }
  final reading = NovelTtsReading(
    surface: trimmed.substring(0, split),
    reading: spoken,
    mode: mode,
  ).trimmed();
  return reading.isValid ? reading : null;
}

List<NovelTtsReading> parseNovelTtsReadingLines(String raw) {
  return parseNovelTtsReadingImport(raw).readings;
}

class NovelTtsReadingImport {
  const NovelTtsReadingImport({required this.readings, required this.skipped});

  final List<NovelTtsReading> readings;

  /// Non-empty, non-comment lines that could not be read as an entry.
  final List<String> skipped;
}

NovelTtsReadingImport parseNovelTtsReadingImport(String raw) {
  final readings = <NovelTtsReading>[];
  final skipped = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final reading = parseNovelTtsReadingLine(line);
    if (reading == null) {
      skipped.add(trimmed);
    } else {
      readings.add(reading);
    }
  }
  return NovelTtsReadingImport(readings: readings, skipped: skipped);
}

/// Writes entries in the format [parseNovelTtsReadingImport] reads back. The
/// mode is always written so a round trip cannot change how an entry matches.
String formatNovelTtsReadingLines(Iterable<NovelTtsReading> readings) {
  return [
    for (final reading in readings)
      '${reading.surface}=${reading.reading}|${_modeTag(reading.effectiveMode)}',
  ].join('\n');
}

PronunciationMatchMode? _modeNamed(String? name) {
  if (name == null) {
    return null;
  }
  for (final mode in PronunciationMatchMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return null;
}

/// Reads the stored list. Entries saved before ids existed get one derived
/// from their position, which then sticks because the next save writes it.
List<NovelTtsReading> readingsFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final out = <NovelTtsReading>[];
  final seen = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) {
      continue;
    }
    var reading = NovelTtsReading.fromJson(Map<String, dynamic>.from(item));
    if (!reading.isValid) {
      continue;
    }
    reading = reading.trimmed();
    if (reading.id == null || !seen.add(reading.id!)) {
      var id = 'legacy-$i';
      while (!seen.add(id)) {
        id = '$id-';
      }
      reading = reading.copyWith(id: id);
    }
    out.add(reading);
  }
  return out;
}
