import 'dart:convert';

import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/provider/tts_template_engine.dart';

class TtsHttpRequest {
  const TtsHttpRequest({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
    required this.redactedDescription,
  });
  final String method;
  final String url;
  final Map<String, String> headers;
  final String? body;
  final String redactedDescription;
}

class TtsRequestBuilder {
  TtsRequestBuilder({TtsTemplateEngine? templates})
    : _templates = templates ?? TtsTemplateEngine();
  final TtsTemplateEngine _templates;

  TtsHttpRequest build(TtsProfile profile, TtsTemplateContext context) {
    if (profile.voice.trim().isEmpty)
      throw const TtsTemplateException('Profile voice is required');
    final request = switch (profile.provider) {
      AzureTtsProviderConfig provider => _azure(profile, provider, context),
      OpenAiTtsProviderConfig provider => _openAi(profile, provider, context),
      CustomTtsProviderConfig provider => _custom(provider, context),
    };
    final uri = Uri.tryParse(request.url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty)
      throw const TtsTemplateException('Provider endpoint must be an HTTP URL');
    return request;
  }

  TtsHttpRequest _azure(
    TtsProfile profile,
    AzureTtsProviderConfig provider,
    TtsTemplateContext context,
  ) {
    final key = _requiredSecret(context, 'api_key');
    final headers = <String, String>{
      'Ocp-Apim-Subscription-Key': key,
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': profile.format,
      'User-Agent': 'PixEz-Novel-TTS',
    };
    return _request('POST', provider.endpoint, headers, context.ssml, context);
  }

  TtsHttpRequest _openAi(
    TtsProfile profile,
    OpenAiTtsProviderConfig provider,
    TtsTemplateContext context,
  ) {
    final key = _requiredSecret(context, 'api_key');
    final model = profile.model?.trim();
    if (model == null || model.isEmpty)
      throw const TtsTemplateException('Profile model is required');
    final body = jsonEncode({
      'model': model,
      'input': context.spokenText,
      'voice': profile.voice,
      'response_format': profile.format,
      'speed': profile.speed,
    });
    return _request(
      'POST',
      provider.endpoint,
      {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
      body,
      context,
    );
  }

  TtsHttpRequest _custom(
    CustomTtsProviderConfig provider,
    TtsTemplateContext context,
  ) {
    final url = _templates.renderUrl(provider.endpointTemplate, context);
    final headers = <String, String>{
      for (final entry in provider.headerTemplates.entries)
        entry.key: _templates.render(entry.value, context),
    };
    final body = provider.bodyTemplate == null
        ? null
        : _templates.render(provider.bodyTemplate!, context);
    if (provider.bodyIsJson && body != null) jsonDecode(body);
    return _request(
      provider.method.name.toUpperCase(),
      url,
      headers,
      body,
      context,
    );
  }

  String _requiredSecret(TtsTemplateContext context, String name) {
    final value = context.secrets[name];
    if (value == null || value.isEmpty)
      throw TtsTemplateException('Required secret $name is missing');
    return value;
  }

  TtsHttpRequest _request(
    String method,
    String url,
    Map<String, String> headers,
    String? body,
    TtsTemplateContext context,
  ) {
    var safeUrl = url;
    var safeBody = body;
    for (final secret in context.secrets.values.where(
      (value) => value.isNotEmpty,
    )) {
      safeUrl = safeUrl.replaceAll(secret, '<redacted>');
      safeBody = safeBody?.replaceAll(secret, '<redacted>');
    }
    final safeHeaders = <String, String>{
      for (final entry in headers.entries)
        entry.key: _sensitiveHeader(entry.key) ? '<redacted>' : entry.value,
    };
    return TtsHttpRequest(
      method: method,
      url: url,
      headers: Map.unmodifiable(headers),
      body: body,
      redactedDescription:
          '$method $safeUrl headers=$safeHeaders body=${safeBody ?? ''}',
    );
  }

  bool _sensitiveHeader(String name) {
    final lower = name.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('api-key') ||
        lower.contains('subscription-key') ||
        lower.contains('secret');
  }
}
