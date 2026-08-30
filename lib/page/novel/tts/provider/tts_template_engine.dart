import 'dart:convert';

import 'package:pixez/page/novel/tts/model/tts_profile.dart';

class TtsTemplateException implements Exception {
  const TtsTemplateException(this.message);
  final String message;
  @override
  String toString() => 'TtsTemplateException: $message';
}

class TtsTemplateContext {
  const TtsTemplateContext({
    required this.displayText,
    required this.spokenText,
    required this.ssml,
    required this.profile,
    this.secrets = const {},
  });
  final String displayText;
  final String spokenText;
  final String ssml;
  final TtsProfile profile;
  final Map<String, String> secrets;
}

class TtsTemplateEngine {
  static final RegExp _modern = RegExp(r'{{\s*([^}|]+?)(?:\|([^}]+?))?\s*}}');

  String render(String template, TtsTemplateContext context) =>
      _render(template, context, urlDefault: false);
  String renderUrl(String template, TtsTemplateContext context) =>
      _render(template, context, urlDefault: true);

  String _render(
    String template,
    TtsTemplateContext context, {
    required bool urlDefault,
  }) {
    var output = template;
    const legacy = ['%@voiceName', '%@modelName', '%@'];
    for (final token in legacy) {
      if (!output.contains(token)) continue;
      final name = switch (token) {
        '%@voiceName' => 'voice',
        '%@modelName' => 'model',
        _ => 'text',
      };
      output = output.replaceAll(token, _encode(_value(name, context), 'url'));
    }
    output = output.replaceAllMapped(_modern, (match) {
      final name = match.group(1)!.trim();
      final filter = (match.group(2)?.trim().isNotEmpty == true
          ? match.group(2)!.trim()
          : (urlDefault ? 'url' : 'raw'));
      return _encode(_value(name, context), filter);
    });
    if (output.contains('{{'))
      throw const TtsTemplateException('Malformed template variable');
    return output;
  }

  String _value(String name, TtsTemplateContext context) {
    String? value;
    switch (name) {
      case 'text':
      case 'spoken_text':
        value = context.spokenText;
      case 'text_raw':
      case 'original_text':
        value = context.displayText;
      case 'ssml':
        if (!context.profile.provider.supportsSsml)
          throw const TtsTemplateException('Provider does not support SSML');
        value = context.ssml;
      case 'voice':
        value = context.profile.voice;
      case 'model':
        value = context.profile.model;
      case 'speed':
        value = context.profile.speed.toString();
      case 'pitch':
        value = context.profile.pitch.toString();
      case 'language':
        value = context.profile.language;
      case 'format':
        value = context.profile.format;
      case 'api_key':
        value = context.secrets['api_key'];
      default:
        if (name.startsWith('secret:'))
          value = context.secrets[name.substring(7)];
        else
          throw TtsTemplateException('Unknown variable {{$name}}');
    }
    if (value == null || value.trim().isEmpty)
      throw TtsTemplateException('Required variable {{$name}} is empty');
    return value;
  }

  String _encode(String value, String filter) {
    return switch (filter) {
      'raw' => value,
      'url' => Uri.encodeQueryComponent(value).replaceAll('+', '%20'),
      'json' => jsonEncode(value).substring(1, jsonEncode(value).length - 1),
      'base64' => base64Encode(utf8.encode(value)),
      _ => throw TtsTemplateException('Unknown template filter $filter'),
    };
  }
}
