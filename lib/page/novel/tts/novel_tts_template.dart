import 'dart:convert';

class NovelTtsTemplateVars {
  const NovelTtsTemplateVars({
    required this.text,
    this.voice = '',
    this.lang = '',
    this.speed = '',
    this.model = '',
    this.region = '',
    this.variables,
  });

  final String text;
  final String voice;
  final String lang;
  final String speed;
  final String model;
  final String region;
  final Map<String, String>? variables;

  Map<String, String> get named {
    final supplied = variables;
    return {
      if (supplied == null) ...{
        'voice': voice,
        'voicename': voice,
        'lang': lang,
        'language': lang,
        'speed': speed,
        'model': model,
        'region': region,
      } else ...{
        for (final entry in supplied.entries)
          entry.key.toLowerCase(): entry.value,
      },
      // The source text can never be replaced by a user-supplied variable.
      'text': text,
    };
  }
}

final novelTtsVariableNamePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final _placeholderPattern =
    RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}|%@([A-Za-z_][A-Za-z0-9_]*)?');
final _jsonTemplatePartPattern = RegExp(
  r'"(?:[^"\\]|\\.)*"|\{([A-Za-z_][A-Za-z0-9_]*)\}|%@([A-Za-z_][A-Za-z0-9_]*)?',
);

Set<String> novelTtsTemplateVariableNames(String template) {
  final names = <String>{};
  var sequential = 0;
  for (final match in _placeholderPattern.allMatches(template)) {
    final name = match.group(1) ?? match.group(2);
    if (name != null) {
      names.add(name.toLowerCase());
    } else if (sequential++ == 0) {
      names.add('text');
    } else if (sequential == 2) {
      names.add('voice');
    }
  }
  return names;
}

class _NovelTtsTemplateRenderer {
  _NovelTtsTemplateRenderer(this.vars);
  final NovelTtsTemplateVars vars;
  int _sequentialIndex = 0;

  String? value(String? name) {
    if (name != null) return vars.named[name.toLowerCase()];
    return switch (_sequentialIndex++) {
      0 => vars.text,
      1 => vars.named['voice'] ?? '',
      _ => '',
    };
  }

  String render(String template, {required bool encodeValues}) =>
      template.replaceAllMapped(_placeholderPattern, (match) {
        final replacement = value(match.group(1) ?? match.group(2));
        if (replacement == null) return match.group(0)!;
        return encodeValues ? Uri.encodeComponent(replacement) : replacement;
      });
}

/// Fills named placeholders and legacy sequential `%@` (text, then voice).
/// One pass prevents template-looking text from being interpreted a second time.
String applyNovelTtsTemplate(
  String template,
  NovelTtsTemplateVars vars, {
  required bool encodeValues,
}) => _NovelTtsTemplateRenderer(
  vars,
).render(template, encodeValues: encodeValues);

bool novelTtsTemplateHasTextPlaceholder(String template) =>
    _placeholderPattern.allMatches(template).any((match) {
      final name = match.group(1) ?? match.group(2);
      return name == null || name.toLowerCase() == 'text';
    });

/// Encodes substituted JSON strings safely, preserving legacy sequential tokens
/// across values and unquoted scalar tokens such as `"speed": {speed}`.
String applyNovelTtsJsonTemplate(String template, NovelTtsTemplateVars vars) {
  final renderer = _NovelTtsTemplateRenderer(vars);
  final rendered = template.replaceAllMapped(_jsonTemplatePartPattern, (match) {
    final token = match.group(0)!;
    if (token.startsWith('"')) {
      return jsonEncode(
        renderer.render(jsonDecode(token) as String, encodeValues: false),
      );
    }
    final replacement = renderer.value(match.group(1) ?? match.group(2));
    if (replacement == null) return token;
    dynamic scalar;
    try {
      scalar = jsonDecode(replacement);
    } on FormatException {
      scalar = replacement;
    }
    // Unquoted values may be JSON primitives, but cannot inject object members.
    if (scalar is Map || scalar is List) scalar = replacement;
    return jsonEncode(scalar);
  });
  return jsonEncode(jsonDecode(rendered));
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
