import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/provider/tts_request_builder.dart';
import 'package:pixez/page/novel/tts/provider/tts_template_engine.dart';

void main() {
  test('Azure sends SSML with required voice and redacted diagnostics', () {
    const profile = TtsProfile(
      id: 'a',
      name: 'Azure',
      enabled: true,
      provider: AzureTtsProviderConfig(region: 'japaneast'),
      voice: 'ja-JP-NanamiNeural',
      format: 'riff-24khz-16bit-mono-pcm',
    );
    final request = TtsRequestBuilder().build(
      profile,
      TtsTemplateContext(
        displayText: '行方',
        spokenText: 'ゆくえ',
        ssml: '<speak>ゆくえ</speak>',
        profile: profile,
        secrets: const {'api_key': 'top-secret'},
      ),
    );
    expect(request.body, contains('<voice name="ja-JP-NanamiNeural">'));
    expect(request.body, contains('<prosody rate="0%" pitch="0st">'));
    expect(request.body, contains('ゆくえ'));
    expect(request.headers['Ocp-Apim-Subscription-Key'], 'top-secret');
    expect(request.redactedDescription, isNot(contains('top-secret')));
  });
  test(
    'OpenAI-compatible request uses spokenText and model profile fields',
    () {
      const profile = TtsProfile(
        id: 'o',
        name: 'OpenAI',
        enabled: true,
        provider: OpenAiTtsProviderConfig(baseUrl: 'https://api.example'),
        voice: 'alloy',
        model: 'tts-1',
        format: 'mp3',
      );
      final request = TtsRequestBuilder().build(
        profile,
        TtsTemplateContext(
          displayText: '行方',
          spokenText: 'ゆくえ',
          ssml: '',
          profile: profile,
          secrets: const {'api_key': 'key'},
        ),
      );
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['input'], 'ゆくえ');
      expect(body['model'], 'tts-1');
      expect(body['voice'], 'alloy');
    },
  );
  test('Custom supports PUT templates and strict variable validation', () {
    const profile = TtsProfile(
      id: 'c',
      name: 'Custom',
      enabled: true,
      provider: CustomTtsProviderConfig(
        endpointTemplate: 'https://x.test/{{voice}}',
        method: CustomHttpMethod.put,
        bodyTemplate: '{"text":"{{text|json}}"}',
      ),
      voice: 'v',
    );
    final request = TtsRequestBuilder().build(
      profile,
      TtsTemplateContext(
        displayText: 'raw',
        spokenText: 'a "quote"',
        ssml: '',
        profile: profile,
      ),
    );
    expect(request.method, 'PUT');
    expect(request.url, 'https://x.test/v');
    expect(jsonDecode(request.body!)['text'], 'a "quote"');
  });
}
