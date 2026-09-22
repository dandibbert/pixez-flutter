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
      customUrl:
          'https://speech.example/tts?text={text}&voice={voice}&speed={speed}',
      customHeaders: 'Authorization: secret',
      customVoice: 'voice-a',
      customLanguage: 'ja-JP',
      customSpeed: '1.0',
    ).saveVoicePreset('Narrator');
    settings = settings
        .copyWith(customVoice: 'voice-b', customSpeed: '0.8')
        .saveVoicePreset('Calm');
    settings = NovelTtsSettings.fromJson(settings.toJson());
    expect(settings.activeVoicePresets, hasLength(2));
    final selected = settings.selectVoicePreset(
      settings.activeVoicePresets.first,
    );
    expect(selected.customTemplateVariables['voice'], 'voice-a');
    expect(selected.customTemplateVariables['speed'], '1.0');
    expect(selected.customHeaders, 'Authorization: secret');
    expect(selected.customUrl, settings.customUrl);
    expect(
      selected.isVoicePresetSelected(settings.activeVoicePresets.first),
      isTrue,
    );
    expect(
      jsonEncode(settings.voicePresets.map((p) => p.toJson()).toList()),
      isNot(contains('secret')),
    );
  });

  test(
    'presets are isolated by endpoint and provider, but survive switching',
    () {
      final original = const NovelTtsSettings(
        customUrl: 'https://a/tts?t={text}',
      ).saveVoicePreset('A');
      final other = original.copyWith(customUrl: 'https://b/tts?t={text}');
      expect(other.activeVoicePresets, isEmpty);
      expect(
        other.selectVoicePreset(original.voicePresets.single),
        same(other),
      );
      expect(
        other.copyWith(customUrl: original.customUrl).activeVoicePresets,
        hasLength(1),
      );
      expect(
        original.copyWith(provider: NovelTtsProvider.openai).activeVoicePresets,
        isEmpty,
      );
    },
  );

  test(
    'equivalent OpenAI endpoint forms share presets without touching keys',
    () {
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
      expect(
        changed
            .selectVoicePreset(changed.activeVoicePresets.single)
            .openaiApiKey,
        'rotated-key',
      );
    },
  );

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

  test(
    'pending writes are immediately visible to another settings entry point',
    () async {
      final first = const NovelTtsSettings(
        customVoice: 'a',
      ).saveVoicePreset('A').copyWith(customVoice: 'b').saveVoicePreset('B');
      final firstWrite = first.save();
      // No await: the first write is still queued when the reading bar loads it.
      final pending = NovelTtsSettings.load();
      expect(pending.activeVoicePresets, hasLength(2));
      final next = pending.selectVoicePreset(pending.activeVoicePresets.first);
      final secondWrite = next.save();
      expect(NovelTtsSettings.load().customTemplateVariables['voice'], 'a');
      await Future.wait([firstWrite, secondWrite]);
      expect(NovelTtsSettings.load().customTemplateVariables['voice'], 'a');
      expect(NovelTtsSettings.load().activeVoicePresets, hasLength(2));
    },
  );

  test(
    'saving an existing name updates one voice; removal preserves others',
    () {
      var settings = const NovelTtsSettings(
        customVoice: 'a',
      ).saveVoicePreset('A');
      settings = settings.copyWith(customVoice: 'b').saveVoicePreset('B');
      settings = settings.copyWith(customVoice: 'a2').saveVoicePreset(' A ');
      expect(settings.activeVoicePresets, hasLength(2));
      final updated = settings.activeVoicePresets.firstWhere(
        (p) => p.name == 'A',
      );
      expect(updated.variables!['voice'], 'a2');
      expect(
        settings.removeVoicePreset(updated).activeVoicePresets.single.name,
        'B',
      );
    },
  );

  test(
    'numeric settings are bounded and malformed presets do not erase config',
    () {
      final settings = NovelTtsSettings.fromJson({
        'splitChars': 9999,
        'prefetchCount': -1,
        'openaiSpeed': double.nan,
        'customHeaders': 'Authorization: retained',
        'voicePresets': [
          null,
          42,
          {'name': 'broken'},
          {'name': 5, 'voice': 'bad'},
        ],
      });
      expect(settings.splitChars, 800);
      expect(settings.prefetchCount, 1);
      expect(settings.openaiSpeed, 1);
      expect(settings.voicePresets, isEmpty);
      expect(settings.customHeaders, 'Authorization: retained');
    },
  );

  test(
    'template substitutions never reinterpret placeholders in spoken text',
    () {
      const vars = NovelTtsTemplateVars(
        text: 'Read {voice} and %@ literally',
        voice: 'A',
      );
      expect(
        applyNovelTtsTemplate('{text} / {voice}', vars, encodeValues: false),
        'Read {voice} and %@ literally / A',
      );
      expect(
        applyNovelTtsTemplate('%@unknown', vars, encodeValues: false),
        '%@unknown',
      );
      expect(novelTtsTemplateHasTextPlaceholder('%@voice'), isFalse);
      expect(novelTtsTemplateHasTextPlaceholder('{TeXt}'), isTrue);
    },
  );

  test('JSON templates escape spoken quotes and retain nested value types', () {
    const vars = NovelTtsTemplateVars(
      text: '"hello"\n\\{voice}',
      voice: 'narrator',
    );
    final result = jsonDecode(
      applyNovelTtsJsonTemplate(
        '{"text":"{text}","nested":["{voice}",true,2]}',
        vars,
      ),
    );
    expect(result, {
      'text': '"hello"\n\\{voice}',
      'nested': ['narrator', true, 2],
    });
  });
  test(
    'JSON templates preserve legacy sequential and unquoted numeric tokens',
    () {
      const vars = NovelTtsTemplateVars(
        text: 'hello "world"',
        voice: 'narrator',
        speed: '1.25',
      );
      final result = jsonDecode(
        applyNovelTtsJsonTemplate(
          '{"text":"%@","voice":"%@","speed":{speed}}',
          vars,
        ),
      );
      expect(result, {
        'text': 'hello "world"',
        'voice': 'narrator',
        'speed': 1.25,
      });
    },
  );
  test(
    'custom variables are arbitrary, optional, and preserved in presets',
    () {
      var settings = const NovelTtsSettings(
        customVariables: {
          'speaker_id': 'Alice',
          'style': 'Calm',
          'pitch_2': '0.4',
        },
      ).saveVoicePreset('Alice');
      settings = settings
          .copyWith(customVariables: {'speaker_id': 'Bob'})
          .saveVoicePreset('Bob');
      settings = NovelTtsSettings.fromJson(settings.toJson());
      final selected = settings.selectVoicePreset(
        settings.activeVoicePresets.first,
      );
      expect(selected.customTemplateVariables, {
        'speaker_id': 'Alice',
        'style': 'Calm',
        'pitch_2': '0.4',
      });
      expect(selected.activeVoice, isEmpty);
      expect(
        selected.isVoicePresetSelected(settings.activeVoicePresets.first),
        isTrue,
      );
      final deleted = selected.copyWith(customVariables: {});
      expect(
        NovelTtsSettings.fromJson(deleted.toJson()).customTemplateVariables,
        isEmpty,
      );
      expect(deleted.voicePreset('Empty').variables, isEmpty);
    },
  );

  test(
    'legacy variable values and presets migrate without losing hidden values',
    () {
      const legacy = NovelTtsSettings(
        customUrl:
            'https://speech.example/tts?t={text}&v={voice}&alias={voicename}&l={lang}&language={language}&s={speed}&m={model}&r={region}',
        customVoice: 'Old',
        customLanguage: 'ja-JP',
        customSpeed: '1.1',
        customModel: 'remote-model',
        microsoftRegion: 'westus',
      );
      final raw = legacy.toJson()..remove('customVariables');
      raw['voicePresets'] = [
        {
          'name': 'Old preset',
          'endpointKey': legacy.voiceEndpointKey,
          'voice': 'Saved',
          'language': 'en-US',
          'speed': '0.7',
          'model': 'saved-model',
        },
      ];
      final migrated = NovelTtsSettings.fromJson(raw);
      expect(migrated.customTemplateVariables, {
        'voice': 'Old',
        'voicename': 'Old',
        'lang': 'ja-JP',
        'language': 'ja-JP',
        'speed': '1.1',
        'model': 'remote-model',
        'region': 'westus',
      });
      final selected = migrated.selectVoicePreset(migrated.voicePresets.single);
      expect(selected.customTemplateVariables, {
        'voice': 'Saved',
        'voicename': 'Saved',
        'lang': 'en-US',
        'language': 'en-US',
        'speed': '0.7',
        'model': 'saved-model',
        'region': 'westus',
      });
    },
  );

  test('legacy text and voice config does not invent unused variable rows', () {
    final migrated = NovelTtsSettings.fromJson({
      'customUrl': 'https://speech.example/tts?t={text}&v={voice}',
      'customVoice': 'Alice',
      'customLanguage': 'ja-JP',
      'customSpeed': '+20%',
      'customModel': 'unused-model',
      // GET never sends this body, so these references are not active variables.
      'customMethod': 'GET', 'customBody': '{model} {lang} {speed}',
    });
    expect(migrated.customVariables, {'voice': 'Alice'});
    expect(migrated.toJson()['customModel'], 'unused-model');
    expect(migrated.toJson()['customLanguage'], 'ja-JP');
    expect(migrated.toJson()['customSpeed'], '+20%');
    expect(migrated.voicePreset('Simple').variables, {'voice': 'Alice'});
  });

  test(
    'legacy headers and POST body retain referenced values and sequential voice',
    () {
      final migrated = NovelTtsSettings.fromJson({
        'customUrl': 'https://speech.example/tts?t=%@&v=%@',
        'customVoice': 'Alice',
        'customLanguage': 'ja-JP',
        'customSpeed': '+20%',
        'customModel': 'used-model',
        'microsoftRegion': 'westus',
        'customMethod': 'POST',
        'customBody': '{"model":"{model}","lang":"{lang}"}',
        'customHeaders': 'X-Speed: {speed}\nX-Region: {region}',
      });
      expect(migrated.customVariables, {
        'voice': 'Alice',
        'lang': 'ja-JP',
        'speed': '+20%',
        'model': 'used-model',
        'region': 'westus',
      });
      final userAdded = migrated.copyWith(
        customVariables: {
          ...migrated.customVariables,
          'unused_style': 'KeepMe',
        },
      );
      expect(
        NovelTtsSettings.fromJson(
          userAdded.toJson(),
        ).customVariables['unused_style'],
        'KeepMe',
      );
    },
  );

  test(
    'legacy presets for another endpoint keep values until that endpoint is selected',
    () {
      const endpointB = NovelTtsSettings(
        customUrl:
            'https://b.example/tts?t={text}&v={voice}&l={lang}&m={model}',
      );
      final endpointA = NovelTtsSettings.fromJson({
        'customUrl': 'https://a.example/tts?t={text}&v={voice}',
        'customVoice': 'A',
        'voicePresets': [
          {
            'name': 'B',
            'endpointKey': endpointB.voiceEndpointKey,
            'voice': 'B voice',
            'language': 'ja-JP',
            'model': 'B model',
          },
        ],
      });
      final reloaded = NovelTtsSettings.fromJson(endpointA.toJson());
      final switched = reloaded.copyWith(customUrl: endpointB.customUrl);
      final selected = switched.selectVoicePreset(
        switched.activeVoicePresets.single,
      );
      expect(selected.customTemplateVariables, {
        'voice': 'B voice',
        'lang': 'ja-JP',
        'model': 'B model',
      });
      expect(reloaded.voicePresets.single.variables, isNull);
    },
  );

  test(
    'custom tokens accept underscores and digits, preserve values, and reserve text',
    () {
      const vars = NovelTtsTemplateVars(
        text: 'Actual source',
        variables: {
          'speaker_id': 'AliceABC',
          'pitch_2': '0.75',
          'text': 'malicious replacement',
        },
      );
      expect(
        applyNovelTtsTemplate(
          '{speaker_id}/%@pitch_2/{TEXT}',
          vars,
          encodeValues: false,
        ),
        'AliceABC/0.75/Actual source',
      );
      expect(
        applyNovelTtsTemplate('{voice}', vars, encodeValues: false),
        '{voice}',
      );
      expect(novelTtsTemplateVariableNames('{speaker_id}/%@pitch_2/{TEXT}'), {
        'speaker_id',
        'pitch_2',
        'text',
      });
      final body = jsonDecode(
        applyNovelTtsJsonTemplate(
          '{"speaker":"{speaker_id}","pitch":{pitch_2},"input":"{text}"}',
          vars,
        ),
      );
      expect(body, {
        'speaker': 'AliceABC',
        'pitch': 0.75,
        'input': 'Actual source',
      });
    },
  );
}
