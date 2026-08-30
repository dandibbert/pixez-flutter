import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pixez/component/perf_probe.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

class NovelTtsRequest {
  const NovelTtsRequest({
    required this.uri,
    required this.method,
    required this.headers,
    this.body,
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final List<int>? body;
}

class NovelTtsConfigException implements Exception {
  const NovelTtsConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NovelTtsSynthException implements Exception {
  const NovelTtsSynthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class NovelTtsSynthesizer {
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text);
}

NovelTtsTemplateVars novelTtsVarsFor(NovelTtsSettings settings, String text) {
  return NovelTtsTemplateVars(
    text: text,
    voice: settings.activeVoice,
    lang: settings.activeLanguage,
    speed: settings.provider == NovelTtsProvider.openai
        ? settings.openaiSpeed.toString()
        : settings.microsoftRate,
    model: settings.openaiModel,
    region: settings.microsoftRegion,
  );
}

String resolveOpenAiSpeechUrl(String baseUrl) {
  var base = baseUrl.trim();
  if (base.isEmpty) {
    throw const NovelTtsConfigException('OpenAI base URL is empty');
  }
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (base.endsWith('/audio/speech')) {
    return base;
  }
  if (base.endsWith('/v1')) {
    return '$base/audio/speech';
  }
  return '$base/v1/audio/speech';
}

String escapeNovelTtsSsml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String buildMicrosoftSsml(NovelTtsSettings settings, String text) {
  final lang = settings.microsoftLanguage.trim().isEmpty
      ? 'zh-CN'
      : settings.microsoftLanguage.trim();
  final voice = settings.microsoftVoice.trim();
  final rate = settings.microsoftRate.trim().isEmpty
      ? '+0%'
      : settings.microsoftRate.trim();
  return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="$lang">'
      '<voice name="$voice"><prosody rate="$rate">${escapeNovelTtsSsml(text)}</prosody></voice>'
      '</speak>';
}

NovelTtsRequest buildNovelTtsRequest(NovelTtsSettings settings, String text) {
  final spoken = text.trim();
  if (spoken.isEmpty) {
    throw const NovelTtsConfigException('Nothing to synthesize');
  }
  switch (settings.provider) {
    case NovelTtsProvider.microsoft:
      return _microsoftRequest(settings, spoken);
    case NovelTtsProvider.openai:
      return _openaiRequest(settings, spoken);
    case NovelTtsProvider.custom:
      return _customRequest(settings, spoken);
  }
}

NovelTtsRequest _microsoftRequest(NovelTtsSettings settings, String text) {
  if (!settings.isConfigured) {
    throw const NovelTtsConfigException('Microsoft TTS is not configured');
  }
  final region = settings.microsoftRegion.trim();
  final uri = Uri.parse(
    'https://$region.tts.speech.microsoft.com/cognitiveservices/v1',
  );
  return NovelTtsRequest(
    uri: uri,
    method: 'POST',
    headers: {
      'Ocp-Apim-Subscription-Key': settings.microsoftKey.trim(),
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
      'User-Agent': 'pixez-novel-tts',
    },
    body: utf8.encode(buildMicrosoftSsml(settings, text)),
  );
}

NovelTtsRequest _openaiRequest(NovelTtsSettings settings, String text) {
  if (!settings.isConfigured) {
    throw const NovelTtsConfigException('OpenAI TTS is not configured');
  }
  final payload = <String, dynamic>{
    'model': settings.openaiModel.trim(),
    'input': text,
    'voice': settings.openaiVoice.trim(),
    'response_format': 'mp3',
  };
  if (settings.openaiSpeed != 1.0) {
    payload['speed'] = settings.openaiSpeed;
  }
  return NovelTtsRequest(
    uri: Uri.parse(resolveOpenAiSpeechUrl(settings.openaiBaseUrl)),
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ${settings.openaiApiKey.trim()}',
      'Content-Type': 'application/json',
    },
    body: utf8.encode(jsonEncode(payload)),
  );
}

NovelTtsRequest _customRequest(NovelTtsSettings settings, String text) {
  final template = settings.customUrl.trim();
  if (template.isEmpty) {
    throw const NovelTtsConfigException('Custom TTS URL is empty');
  }
  if (!novelTtsTemplateHasTextPlaceholder(template) &&
      !novelTtsTemplateHasTextPlaceholder(settings.customBody)) {
    throw const NovelTtsConfigException(
      'Custom TTS URL or body must include {text} or %@',
    );
  }
  final vars = novelTtsVarsFor(settings, text);
  final url = applyNovelTtsTemplate(template, vars, encodeValues: true);
  final uri = Uri.parse(url);
  final method = settings.customMethod.trim().isEmpty
      ? 'GET'
      : settings.customMethod.trim().toUpperCase();
  final headers = parseNovelTtsHeaderLines(
    applyNovelTtsTemplate(settings.customHeaders, vars, encodeValues: false),
  );
  List<int>? body;
  if (method != 'GET' && settings.customBody.trim().isNotEmpty) {
    final rendered = applyNovelTtsTemplate(
      settings.customBody,
      vars,
      encodeValues: false,
    );
    body = utf8.encode(rendered);
    headers.putIfAbsent(
      'Content-Type',
      () => settings.customContentType.trim().isEmpty
          ? 'text/plain; charset=utf-8'
          : settings.customContentType.trim(),
    );
  } else if (settings.customContentType.trim().isNotEmpty) {
    headers['Content-Type'] = settings.customContentType.trim();
  }
  return NovelTtsRequest(
    uri: uri,
    method: method,
    headers: headers,
    body: body,
  );
}

class NovelTtsHttpSynthesizer implements NovelTtsSynthesizer {
  NovelTtsHttpSynthesizer({HttpClient? client}) : _client = client;

  final HttpClient? _client;

  @override
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text) async {
    final request = buildNovelTtsRequest(settings, text);
    PerfCounters.ttsRequests++;
    final client = _client ?? HttpClient();
    final owned = _client == null;
    try {
      final httpRequest = await client.openUrl(request.method, request.uri);
      request.headers.forEach(httpRequest.headers.set);
      if (request.body != null) {
        httpRequest.add(request.body!);
      }
      final response = await httpRequest.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NovelTtsSynthException(
          'TTS HTTP ${response.statusCode}: ${_briefError(bytes)}',
        );
      }
      if (bytes.isEmpty) {
        throw const NovelTtsSynthException('TTS returned empty audio');
      }
      if (_looksLikeJsonError(bytes)) {
        throw NovelTtsSynthException('TTS error: ${_briefError(bytes)}');
      }
      return Uint8List.fromList(bytes);
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }
}

Future<List<int>> consolidateHttpClientResponseBytes(
  HttpClientResponse response,
) {
  final chunks = <int>[];
  return response.fold<List<int>>(chunks, (previous, element) {
    previous.addAll(element);
    return previous;
  });
}

bool _looksLikeJsonError(List<int> bytes) {
  if (bytes.isEmpty) {
    return false;
  }
  final start = String.fromCharCode(bytes.first);
  if (start != '{' && start != '[') {
    return false;
  }
  try {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is Map &&
        (decoded.containsKey('error') || decoded.containsKey('message'))) {
      return true;
    }
  } catch (_) {}
  return false;
}

String _briefError(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  if (text.length <= 240) {
    return text;
  }
  return text.substring(0, 240);
}
