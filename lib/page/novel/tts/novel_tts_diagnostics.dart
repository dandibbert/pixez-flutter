import 'dart:convert';

import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

const _hidden = '[redacted]';

bool _sensitiveName(String name) => RegExp(
  r'^key$|authorization|cookie|token|secret|password|passwd|api.?key|subscription.?key|signature|credential',
  caseSensitive: false,
).hasMatch(name);

String _redactUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null && uri.userInfo.isNotEmpty) {
    value = value.replaceFirst('${uri.userInfo}@', '$_hidden@');
  }
  // Preserve all other URL bytes, including their existing escaping and order.
  return value.replaceAllMapped(RegExp(r'([?&])([^=&]+)=([^&#]*)'), (match) {
    String key;
    try {
      key = Uri.decodeQueryComponent(match.group(2)!);
    } catch (_) {
      return match.group(0)!;
    }
    return _sensitiveName(key)
        ? '${match.group(1)}${match.group(2)}=$_hidden'
        : match.group(0)!;
  });
}

Object? _redactJson(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _sensitiveName('${entry.key}')
            ? _hidden
            : _redactJson(entry.value),
    };
  }
  if (value is List) return value.map(_redactJson).toList();
  return value;
}

void _collectJsonSecrets(Object? value, Set<String> secrets) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (_sensitiveName('${entry.key}') && entry.value is String) {
        secrets.add(entry.value as String);
      } else {
        _collectJsonSecrets(entry.value, secrets);
      }
    }
  } else if (value is List) {
    for (final entry in value) {
      _collectJsonSecrets(entry, secrets);
    }
  }
}

/// Formats the exact request used by synthesis, without changing that request.
/// Showing credentials is an explicit local UI choice, never a log side effect.
String describeNovelTtsRequest(
  NovelTtsRequest request, {
  bool revealSecrets = false,
}) {
  final result = StringBuffer()
    ..writeln(
      '${request.method} ${revealSecrets ? request.uri : _redactUrl(request.uri.toString())}',
    );
  for (final entry in request.headers.entries) {
    result.writeln(
      '${entry.key}: ${!revealSecrets && _sensitiveName(entry.key) ? _hidden : entry.value}',
    );
  }
  if (request.body != null) {
    var body = utf8.decode(request.body!, allowMalformed: true);
    if (!revealSecrets) {
      try {
        final decoded = jsonDecode(body);
        final scrubbed = _redactJson(decoded);
        if (jsonEncode(decoded) != jsonEncode(scrubbed)) {
          body = const JsonEncoder.withIndent('  ').convert(scrubbed);
        }
      } on FormatException {
        // Handles form data while preserving everything except secret values.
        body = _redactUrl('?$body').substring(1);
      }
    }
    result
      ..writeln()
      ..write(body);
  }
  return result.toString();
}

/// Keeps transport, server, filesystem and decoder details. Only credentials
/// are removed; the error is not replaced by a generic configuration hint.
String describeNovelTtsError(
  Object error,
  NovelTtsSettings settings, {
  bool revealSecrets = false,
}) {
  var message = error.toString();
  if (revealSecrets) return message;
  final secrets = <String>{settings.microsoftKey, settings.openaiApiKey};
  final variables = settings.customTemplateVariables;
  for (final entry in variables.entries) {
    if (_sensitiveName(entry.key)) secrets.add(entry.value);
  }
  final headers = parseNovelTtsHeaderLines(
    applyNovelTtsTemplate(
      settings.customHeaders,
      NovelTtsTemplateVars(text: '', variables: variables),
      encodeValues: false,
    ),
  );
  for (final header in headers.entries) {
    if (!_sensitiveName(header.key)) continue;
    secrets.add(header.value);
    if (header.value.toLowerCase().startsWith('bearer ')) {
      secrets.add(header.value.substring(7));
    }
  }
  final endpoint = Uri.tryParse(
    applyNovelTtsTemplate(
      settings.customUrl,
      NovelTtsTemplateVars(text: '', variables: variables),
      encodeValues: true,
    ),
  );
  if (endpoint != null) {
    if (endpoint.userInfo.isNotEmpty) secrets.add(endpoint.userInfo);
    for (final entry in endpoint.queryParameters.entries) {
      if (_sensitiveName(entry.key)) secrets.add(entry.value);
    }
  }
  try {
    // Resolve body placeholders using the production builder as well. A
    // credential may use an innocuous variable name such as {access}.
    final request = buildNovelTtsRequest(settings, '[text]');
    if (request.body != null) {
      final body = utf8.decode(request.body!, allowMalformed: true);
      try {
        _collectJsonSecrets(jsonDecode(body), secrets);
      } on FormatException {
        for (final entry in Uri.splitQueryString(body).entries) {
          if (_sensitiveName(entry.key)) secrets.add(entry.value);
        }
      }
    }
  } catch (_) {
    // An invalid request still needs its original configuration error shown.
  }
  final ordered =
      {
          for (final value in secrets) ...[value, value.trim()],
        }.where((value) => value.isNotEmpty).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  for (final secret in ordered) {
    for (final value in {
      secret,
      Uri.encodeComponent(secret),
      Uri.encodeQueryComponent(secret),
    }) {
      message = message.replaceAll(
        value.length < 4
            ? RegExp('(?<![A-Za-z0-9])${RegExp.escape(value)}(?![A-Za-z0-9])')
            : value,
        _hidden,
      );
    }
  }
  return message;
}
