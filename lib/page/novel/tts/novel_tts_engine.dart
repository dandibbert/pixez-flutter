import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pixez/component/perf_probe.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_endpoint.dart';
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

/// Optional lifecycle support for transports with outstanding network work.
abstract interface class NovelTtsCancellableSynthesizer {
  void cancelPending();

  void dispose();
}

NovelTtsTemplateVars novelTtsVarsFor(NovelTtsSettings settings, String text) {
  return NovelTtsTemplateVars(
    text: text,
    voice: settings.activeVoice,
    lang: settings.activeLanguage,
    speed: settings.provider == NovelTtsProvider.openai
        ? settings.openaiSpeed.toString()
        : settings.provider == NovelTtsProvider.custom
        ? settings.customSpeed
        : settings.microsoftRate,
    model: settings.provider == NovelTtsProvider.custom
        ? settings.customModel
        : settings.openaiModel,
    region: settings.microsoftRegion,
    variables: settings.provider == NovelTtsProvider.custom
        ? settings.customTemplateVariables
        : null,
  );
}

String resolveOpenAiSpeechUrl(String baseUrl) {
  if (baseUrl.trim().isEmpty) {
    throw const NovelTtsConfigException('OpenAI base URL is empty');
  }
  return resolveNovelTtsOpenaiEndpoint(baseUrl);
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

Uri _ttsUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    throw const NovelTtsConfigException('TTS URL must be an HTTP or HTTPS URL');
  }
  return uri;
}

NovelTtsRequest _microsoftRequest(NovelTtsSettings settings, String text) {
  if (!settings.isConfigured) {
    throw const NovelTtsConfigException('Microsoft TTS is not configured');
  }
  final region = settings.microsoftRegion.trim();
  final uri = _ttsUri(
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
    uri: _ttsUri(resolveOpenAiSpeechUrl(settings.openaiBaseUrl)),
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
  final method = settings.customMethod.trim().isEmpty
      ? 'GET'
      : settings.customMethod.trim().toUpperCase();
  if (!novelTtsTemplateHasTextPlaceholder(template) &&
      (method == 'GET' ||
          !novelTtsTemplateHasTextPlaceholder(settings.customBody))) {
    throw const NovelTtsConfigException(
      'Custom TTS URL or POST body must include {text} or %@',
    );
  }
  final vars = novelTtsVarsFor(settings, text);
  final url = applyNovelTtsTemplate(template, vars, encodeValues: true);
  final uri = _ttsUri(url);
  final headers = parseNovelTtsHeaderLines(
    applyNovelTtsTemplate(settings.customHeaders, vars, encodeValues: false),
  );
  List<int>? body;
  if (method != 'GET' && settings.customBody.trim().isNotEmpty) {
    var contentType = settings.customContentType;
    for (final header in headers.entries) {
      if (header.key.toLowerCase() == 'content-type')
        contentType = header.value;
    }
    final rendered = contentType.toLowerCase().contains('json')
        ? applyNovelTtsJsonTemplate(settings.customBody, vars)
        : applyNovelTtsTemplate(settings.customBody, vars, encodeValues: false);
    body = utf8.encode(rendered);
    if (!headers.keys.any((name) => name.toLowerCase() == 'content-type')) {
      headers['Content-Type'] = settings.customContentType.trim().isEmpty
          ? 'text/plain; charset=utf-8'
          : settings.customContentType.trim();
    }
  } else if (settings.customContentType.trim().isNotEmpty &&
      !headers.keys.any((name) => name.toLowerCase() == 'content-type')) {
    headers['Content-Type'] = settings.customContentType.trim();
  }
  return NovelTtsRequest(
    uri: uri,
    method: method,
    headers: headers,
    body: body,
  );
}

class NovelTtsHttpSynthesizer
    implements NovelTtsSynthesizer, NovelTtsCancellableSynthesizer {
  NovelTtsHttpSynthesizer({
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 45),
    this.idleTimeout = const Duration(seconds: 15),
  }) : _client = client;

  final HttpClient? _client;
  final Duration requestTimeout;
  final Duration idleTimeout;
  final Set<HttpClientRequest> _requests = {};
  final Set<HttpClient> _ownedClients = {};
  var _generation = 0;
  var _disposed = false;

  @override
  void cancelPending() {
    _generation++;
    for (final request in _requests.toList()) {
      request.abort(const NovelTtsSynthException('TTS request cancelled'));
    }
    for (final client in _ownedClients.toList()) {
      client.close(force: true);
    }
    _requests.clear();
    _ownedClients.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelPending();
  }

  @override
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text) async {
    if (_disposed) {
      throw const NovelTtsSynthException('TTS synthesizer is disposed');
    }
    final request = buildNovelTtsRequest(settings, text);
    final generation = _generation;
    PerfCounters.ttsRequests++;
    final client =
        _client ??
        (HttpClient()..connectionTimeout = const Duration(seconds: 10));
    final owned = _client == null;
    if (owned) _ownedClients.add(client);
    HttpClientRequest? activeRequest;
    var expired = false;
    try {
      return await (() async {
        final httpRequest = await client.openUrl(request.method, request.uri);
        activeRequest = httpRequest;
        if (_disposed || expired || generation != _generation) {
          httpRequest.abort();
          throw const NovelTtsSynthException('TTS request cancelled');
        }
        _requests.add(httpRequest);
        request.headers.forEach(httpRequest.headers.set);
        if (request.body != null) httpRequest.add(request.body!);
        final response = await httpRequest.close();
        final bytes = await consolidateHttpClientResponseBytes(
          response,
          idleTimeout: idleTimeout,
        );
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
        return bytes;
      })().timeout(
        requestTimeout,
        onTimeout: () {
          expired = true;
          activeRequest?.abort();
          throw const NovelTtsSynthException('TTS request timed out');
        },
      );
    } catch (_) {
      activeRequest?.abort();
      rethrow;
    } finally {
      _requests.remove(activeRequest);
      if (owned) {
        _ownedClients.remove(client);
        client.close(force: true);
      }
    }
  }
}

/// Ceiling on one clip's audio. A clip is at most a few hundred spoken
/// characters, so a few megabytes of MP3 is already generous; anything past it
/// is a misconfigured endpoint or a proxy error page, and buffering it whole is
/// how a custom URL gets the process killed for memory.
const novelTtsMaxResponseBytes = 16 * 1024 * 1024;

Future<Uint8List> consolidateHttpClientResponseBytes(
  HttpClientResponse response, {
  Duration idleTimeout = const Duration(seconds: 15),
}) async {
  final chunks = BytesBuilder(copy: false);
  await for (final element in response.timeout(idleTimeout)) {
    // Check before retaining a chunk. A List<int> stores machine words on the
    // VM and can use many times the memory of the compressed audio itself.
    if (chunks.length + element.length > novelTtsMaxResponseBytes) {
      throw NovelTtsSynthException(
        'TTS response exceeds ${novelTtsMaxResponseBytes ~/ (1024 * 1024)} MB',
      );
    }
    chunks.add(element);
  }
  return chunks.takeBytes();
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
  final text = utf8
      .decode(bytes.take(960).toList(), allowMalformed: true)
      .trim();
  if (text.length <= 240) {
    return text;
  }
  return text.substring(0, 240);
}
