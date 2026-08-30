import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/provider/tts_template_engine.dart';

TtsProfile profile({
  String voice = 'ja-JP-NanamiNeural',
  String? model = 'tts-1',
}) => TtsProfile(
  id: 'p1',
  name: 'Test',
  enabled: true,
  provider: const CustomTtsProviderConfig(
    endpointTemplate: 'https://example.test',
    method: CustomHttpMethod.get,
    ssml: true,
  ),
  voice: voice,
  model: model,
  language: 'ja-JP',
  format: 'mp3',
  speed: 1.1,
  pitch: 0.2,
);

TtsTemplateContext context({String voice = 'ja-JP-NanamiNeural'}) =>
    TtsTemplateContext(
      displayText: '行方 & 原文',
      spokenText: 'ゆくえ & spoken',
      ssml: '<speak>ゆくえ</speak>',
      profile: profile(voice: voice),
      secrets: const {'api_key': 'secret-key', 'tenant': 'hidden'},
    );

void main() {
  group('TtsTemplateEngine', () {
    test('resolves voice from the current profile', () {
      expect(
        TtsTemplateEngine().render('{{voice}}', context()),
        'ja-JP-NanamiNeural',
      );
    });

    test('fails locally when a referenced required variable is empty', () {
      expect(
        () => TtsTemplateEngine().render('{{voice}}', context(voice: '')),
        throwsA(isA<TtsTemplateException>()),
      );
    });

    test('keeps text text_raw and ssml semantics stable', () {
      final engine = TtsTemplateEngine();
      expect(engine.render('{{text}}', context()), 'ゆくえ & spoken');
      expect(engine.render('{{text_raw}}', context()), '行方 & 原文');
      expect(engine.render('{{ssml}}', context()), '<speak>ゆくえ</speak>');
    });

    test('legacy longest token parsing preserves voiceName', () {
      final rendered = TtsTemplateEngine().renderUrl(
        'https://tts.773421.xyz/tts?t=%@&v=%@voiceName&',
        context(),
      );
      expect(
        rendered,
        'https://tts.773421.xyz/tts?t=%E3%82%86%E3%81%8F%E3%81%88%20%26%20spoken&v=ja-JP-NanamiNeural&',
      );
    });

    test(
      'custom URL variables are encoded without changing body semantics',
      () {
        final engine = TtsTemplateEngine();
        expect(
          engine.renderUrl('https://x.test?q={{text}}', context()),
          'https://x.test?q=%E3%82%86%E3%81%8F%E3%81%88%20%26%20spoken',
        );
        expect(engine.render('{{text}}', context()), 'ゆくえ & spoken');
      },
    );

    test('resolves named secrets and rejects missing ones', () {
      final engine = TtsTemplateEngine();
      expect(
        engine.render('{{api_key}}/{{secret:tenant}}', context()),
        'secret-key/hidden',
      );
      expect(
        () => engine.render('{{secret:missing}}', context()),
        throwsA(isA<TtsTemplateException>()),
      );
    });
  });
}
