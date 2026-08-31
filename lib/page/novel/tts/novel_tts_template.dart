class NovelTtsTemplateVars {
  const NovelTtsTemplateVars({
    required this.text,
    this.voice = '',
    this.lang = '',
    this.speed = '',
    this.model = '',
    this.region = '',
  });

  final String text;
  final String voice;
  final String lang;
  final String speed;
  final String model;
  final String region;

  Map<String, String> get named {
    return {
      'text': text,
      'voice': voice,
      'voicename': voice,
      'lang': lang,
      'language': lang,
      'speed': speed,
      'model': model,
      'region': region,
    };
  }
}

const _namedPlaceholderKeys = <String>[
  'voicename',
  'language',
  'voice',
  'text',
  'lang',
  'speed',
  'model',
  'region',
];

/// Fills `{name}` / `%@name` placeholders and leftover sequential `%@`
/// (text, then voice). [encodeValues] should be true for URLs.
String applyNovelTtsTemplate(
  String template,
  NovelTtsTemplateVars vars, {
  required bool encodeValues,
}) {
  if (template.isEmpty) {
    return template;
  }
  final values = vars.named.map(
    (key, value) => MapEntry(key, encodeValues ? Uri.encodeComponent(value) : value),
  );
  var result = template;
  result = result.replaceAllMapped(RegExp(r'\{([A-Za-z]+)\}'), (match) {
    final key = match.group(1)!.toLowerCase();
    return values[key] ?? match.group(0)!;
  });
  result = result.replaceAllMapped(RegExp(r'%@([A-Za-z]+)'), (match) {
    final key = match.group(1)!.toLowerCase();
    if (!_namedPlaceholderKeys.contains(key)) {
      return match.group(0)!;
    }
    return values[key] ?? match.group(0)!;
  });
  final sequential = <String>[
    values['text'] ?? '',
    values['voice'] ?? '',
  ];
  var sequentialIndex = 0;
  result = result.replaceAllMapped(RegExp(r'%@'), (match) {
    if (sequentialIndex >= sequential.length) {
      return '';
    }
    return sequential[sequentialIndex++];
  });
  return result;
}

bool novelTtsTemplateHasTextPlaceholder(String template) {
  if (template.contains('{text}') ||
      template.contains('{TEXT}') ||
      template.contains('%@text') ||
      template.contains('%@TEXT')) {
    return true;
  }
  return template.contains('%@');
}

Map<String, String> parseNovelTtsHeaderLines(String raw) {
  final headers = <String, String>{};
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    var index = trimmed.indexOf(':');
    if (index <= 0) {
      index = trimmed.indexOf('=');
    }
    if (index <= 0) {
      continue;
    }
    final name = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    if (name.isNotEmpty) {
      headers[name] = value;
    }
  }
  return headers;
}

String serializeNovelTtsHeaderLines(Map<String, String> headers) {
  return [
    for (final entry in headers.entries)
      if (entry.key.trim().isNotEmpty) '${entry.key.trim()}: ${entry.value}',
  ].join('\n');
}
