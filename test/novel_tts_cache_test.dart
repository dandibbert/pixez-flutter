import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/cache/tts_cache.dart';

void main() {
  test('cache key covers synthesis inputs but never API keys', () {
    const input = TtsCacheInput(
      spokenText: 'ゆくえ',
      ssml: '<speak>ゆくえ</speak>',
      provider: 'azure',
      endpoint: 'https://x',
      voice: 'voice',
      model: 'model',
      speed: 1.1,
      pitch: 0.2,
      format: 'mp3',
    );
    final key = input.key;
    expect(key, hasLength(64));
    expect(input.metadata.toString(), isNot(contains('secret-key')));
    expect(input.copyWithApiKeyForTest('secret-key').key, key);
  });
  test(
    'audio validation recognizes common formats and rejects partial garbage',
    () {
      expect(TtsAudioValidator.isValid([0x49, 0x44, 0x33, 0, 0, 0]), isTrue);
      expect(
        TtsAudioValidator.isValid([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x41,
          0x56,
          0x45,
        ]),
        isTrue,
      );
      expect(TtsAudioValidator.isValid([1, 2, 3]), isFalse);
    },
  );
}
