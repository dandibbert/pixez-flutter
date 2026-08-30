import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

class NovelTtsReading {
  const NovelTtsReading({
    required this.surface,
    required this.reading,
    this.mode,
  });

  final String surface;
  final String reading;
  final PronunciationMatchMode? mode;

  bool get isValid => surface.trim().isNotEmpty && reading.trim().isNotEmpty;

  NovelTtsReading trimmed() {
    return NovelTtsReading(
      surface: surface.trim(),
      reading: reading.trim(),
      mode: mode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surface': surface,
      'reading': reading,
      if (mode != null) 'mode': mode!.name,
    };
  }

  factory NovelTtsReading.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    return NovelTtsReading(
      surface: json['surface'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      mode: _modeNamed(modeName),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NovelTtsReading &&
        other.surface == surface &&
        other.reading == reading;
  }

  @override
  int get hashCode => Object.hash(surface, reading);
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

NovelTtsReading? parseNovelTtsReadingLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) {
    return null;
  }
  final eq = trimmed.indexOf('=');
  final tab = trimmed.indexOf('\t');
  var split = -1;
  if (eq > 0 && (tab < 0 || eq < tab)) {
    split = eq;
  } else if (tab > 0) {
    split = tab;
  } else {
    final slash = trimmed.indexOf('/');
    if (slash > 0) {
      split = slash;
    }
  }
  if (split <= 0) {
    return null;
  }
  final reading = NovelTtsReading(
    surface: trimmed.substring(0, split),
    reading: trimmed.substring(split + 1),
  ).trimmed();
  return reading.isValid ? reading : null;
}

List<NovelTtsReading> parseNovelTtsReadingLines(String raw) {
  return [
    for (final line in raw.split(RegExp(r'\r?\n')))
      if (parseNovelTtsReadingLine(line) case final reading?) reading,
  ];
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

List<NovelTtsReading> readingsFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map)
        NovelTtsReading.fromJson(Map<String, dynamic>.from(item)),
  ].where((reading) => reading.isValid).map((reading) => reading.trimmed()).toList();
}
