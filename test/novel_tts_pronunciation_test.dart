import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';

PronunciationContext get ctx =>
    const PronunciationContext(novelId: 'n1', seriesId: 's1', authorId: 'a1');

void main() {
  test(
    'scope priority and longest match resolve original coordinates once',
    () {
      final result = PronunciationEngine().apply('今日中は人気', [
        const PronunciationRule(
          id: 'g',
          surface: '今日',
          reading: 'きょう',
          scope: PronunciationScope.global,
          priority: 100,
        ),
        const PronunciationRule(
          id: 'n',
          surface: '今日中',
          reading: 'きょうじゅう',
          scope: PronunciationScope.novel,
          scopeId: 'n1',
        ),
        const PronunciationRule(
          id: 'p',
          surface: '人気',
          reading: 'にんき',
          scope: PronunciationScope.global,
        ),
      ], ctx);
      expect(result.displayText, '今日中は人気');
      expect(result.spokenText, 'きょうじゅうはにんき');
      expect(result.ssml, contains('<sub alias="きょうじゅう">今日中</sub>'));
    },
  );

  test(
    'Pixiv ruby wins unless an overlapping rule explicitly overrides it',
    () {
      const ruby = [PronunciationRuby(start: 0, end: 2, reading: 'じんき')];
      final normal = PronunciationEngine().apply(
        '人気',
        [
          const PronunciationRule(
            id: 'r',
            surface: '人気',
            reading: 'にんき',
            scope: PronunciationScope.global,
          ),
        ],
        ctx,
        ruby: ruby,
      );
      expect(normal.spokenText, 'じんき');
      final overridden = PronunciationEngine().apply(
        '人気',
        [
          const PronunciationRule(
            id: 'r',
            surface: '人気',
            reading: 'にんき',
            scope: PronunciationScope.global,
            overridePixivRuby: true,
          ),
        ],
        ctx,
        ruby: ruby,
      );
      expect(overridden.spokenText, 'にんき');
    },
  );

  test('replacement output is never matched recursively', () {
    final result = PronunciationEngine().apply('神威', [
      const PronunciationRule(
        id: '1',
        surface: '神威',
        reading: '今日',
        scope: PronunciationScope.global,
      ),
      const PronunciationRule(
        id: '2',
        surface: '今日',
        reading: 'きょう',
        scope: PronunciationScope.global,
      ),
    ], ctx);
    expect(result.spokenText, '今日');
  });
}
