import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/er/prefer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
  });

  test('legacy custom templates retain their language, speed and model', () {
    final migrated = NovelTtsSettings.fromJson({
      'customVoice': 'narrator',
      'microsoftLanguage': 'ja-JP',
      'microsoftRate': '+20%',
      'openaiModel': 'legacy-model',
    });
    expect(migrated.customLanguage, 'ja-JP');
    expect(migrated.customSpeed, '+20%');
    expect(migrated.customModel, 'legacy-model');
    final saved = NovelTtsSettings.fromJson(migrated.toJson());
    expect(saved.customLanguage, 'ja-JP');
    expect(saved.voicePresets, isEmpty);
  });

  test('voices share the endpoint and credentials across a JSON round trip', () {
    var settings = const NovelTtsSettings(
      customUrl: 'https://speech.example/tts?text={text}&voice={voice}',
      customHeaders: 'Authorization: secret',
      customVoice: 'voice-a',
      customLanguage: 'ja-JP',
      customSpeed: '1.0',
    ).saveVoicePreset('Narrator');
    settings = settings.copyWith(customVoice: 'voice-b', customSpeed: '0.8')
        .saveVoicePreset('Calm');
    settings = NovelTtsSettings.fromJson(settings.toJson());
    expect(settings.activeVoicePresets, hasLength(2));
    final selected = settings.selectVoicePreset(settings.activeVoicePresets.first);
    expect(selected.customVoice, 'voice-a');
    expect(selected.customSpeed, '1.0');
    expect(selected.customHeaders, 'Authorization: secret');
    expect(selected.customUrl, settings.customUrl);
    expect(selected.isVoicePresetSelected(settings.activeVoicePresets.first), isTrue);
    expect(jsonEncode(settings.voicePresets.map((p) => p.toJson()).toList()),
        isNot(contains('secret')));
  });

  test('presets are isolated by endpoint and provider, but survive switching', () {
    final original = const NovelTtsSettings(customUrl: 'https://a/tts?t={text}')
        .saveVoicePreset('A');
    final other = original.copyWith(customUrl: 'https://b/tts?t={text}');
    expect(other.activeVoicePresets, isEmpty);
    expect(other.selectVoicePreset(original.voicePresets.single), same(other));
    expect(other.copyWith(customUrl: original.customUrl).activeVoicePresets,
        hasLength(1));
    expect(original.copyWith(provider: NovelTtsProvider.openai).activeVoicePresets,
        isEmpty);
  });

  test('equivalent OpenAI endpoint forms share presets without touching keys', () {
    final settings = const NovelTtsSettings(
      provider: NovelTtsProvider.openai,
      openaiBaseUrl: 'https://speech.example',
      openaiApiKey: 'first-key',
    ).saveVoicePreset('A');
    final changed = settings.copyWith(
      openaiBaseUrl: 'https://speech.example/v1/audio/speech/',
      openaiApiKey: 'rotated-key',
    );
    expect(changed.activeVoicePresets, hasLength(1));
    expect(changed.selectVoicePreset(changed.activeVoicePresets.single).openaiApiKey,
        'rotated-key');
  });

  test('explicit OpenAI speech paths remain separate endpoints', () {
    final direct = const NovelTtsSettings(
      provider: NovelTtsProvider.openai,
      openaiBaseUrl: 'https://speech.example/audio/speech',
    ).saveVoicePreset('Direct');
    final versioned = direct.copyWith(
      openaiBaseUrl: 'https://speech.example/v1/audio/speech',
    );
    expect(versioned.activeVoicePresets, isEmpty);
    expect(direct.voiceEndpointKey, isNot(versioned.voiceEndpointKey));
  });

  test('pending writes are immediately visible to another settings entry point', () async {
    final first = const NovelTtsSettings(customVoice: 'a').saveVoicePreset('A')
        .copyWith(customVoice: 'b').saveVoicePreset('B');
    final firstWrite = first.save();
    // No await: the first write is still queued when the reading bar loads it.
    final pending = NovelTtsSettings.load();
    expect(pending.activeVoicePresets, hasLength(2));
    final next = pending.selectVoicePreset(pending.activeVoicePresets.first);
    final secondWrite = next.save();
    expect(NovelTtsSettings.load().customVoice, 'a');
    await Future.wait([firstWrite, secondWrite]);
    expect(NovelTtsSettings.load().customVoice, 'a');
    expect(NovelTtsSettings.load().activeVoicePresets, hasLength(2));
  });

  test('saving an existing name updates one voice; removal preserves others', () {
    var settings = const NovelTtsSettings(customVoice: 'a').saveVoicePreset('A');
    settings = settings.copyWith(customVoice: 'b').saveVoicePreset('B');
    settings = settings.copyWith(customVoice: 'a2').saveVoicePreset(' A ');
    expect(settings.activeVoicePresets, hasLength(2));
    final updated = settings.activeVoicePresets.firstWhere((p) => p.name == 'A');
    expect(updated.voice, 'a2');
    expect(settings.removeVoicePreset(updated).activeVoicePresets.single.name, 'B');
  });

  test('numeric settings are bounded and malformed presets do not erase config', () {
    final settings = NovelTtsSettings.fromJson({
      'splitChars': 9999,
      'prefetchCount': -1,
      'openaiSpeed': double.nan,
      'customHeaders': 'Authorization: retained',
      'voicePresets': [null, 42, {'name': 'broken'}, {'name': 5, 'voice': 'bad'}],
    });
    expect(settings.splitChars, 800);
    expect(settings.prefetchCount, 1);
    expect(settings.openaiSpeed, 1);
    expect(settings.voicePresets, isEmpty);
    expect(settings.customHeaders, 'Authorization: retained');
  });

  test('template substitutions never reinterpret placeholders in spoken text', () {
    const vars = NovelTtsTemplateVars(text: 'Read {voice} and %@ literally', voice: 'A');
    expect(applyNovelTtsTemplate('{text} / {voice}', vars, encodeValues: false),
        'Read {voice} and %@ literally / A');
    expect(applyNovelTtsTemplate('%@unknown', vars, encodeValues: false), '%@unknown');
    expect(novelTtsTemplateHasTextPlaceholder('%@voice'), isFalse);
    expect(novelTtsTemplateHasTextPlaceholder('{TeXt}'), isTrue);
  });

  test('JSON templates escape spoken quotes and retain nested value types', () {
    const vars = NovelTtsTemplateVars(text: '"hello"\n\\{voice}', voice: 'narrator');
    final result = jsonDecode(applyNovelTtsJsonTemplate(
      '{"text":"{text}","nested":["{voice}",true,2]}', vars,
    ));
    expect(result, {
      'text': '"hello"\n\\{voice}',
      'nested': ['narrator', true, 2],
    });
  });
  test('JSON templates preserve legacy sequential and unquoted numeric tokens', () {
    const vars = NovelTtsTemplateVars(text: 'hello "world"', voice: 'narrator', speed: '1.25');
    final result = jsonDecode(applyNovelTtsJsonTemplate(
      '{"text":"%@","voice":"%@","speed":{speed}}', vars,
    ));
    expect(result, {'text': 'hello "world"', 'voice': 'narrator', 'speed': 1.25});
  });

}
