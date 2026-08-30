import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixez/page/novel/tts/data/pronunciation_dictionary_repository.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';

void main() {
  test('dictionary persists editable scoped rules', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PronunciationDictionaryRepository();
    const rule = PronunciationRule(
      id: 'r',
      surface: '行方',
      reading: 'ゆくえ',
      scope: PronunciationScope.novel,
      scopeId: '42',
      priority: 7,
      overridePixivRuby: true,
    );
    await repo.upsert(rule);
    expect((await repo.load()).single.toJson(), rule.toJson());
    await repo.upsert(rule.copyWith(reading: 'ゆきかた', enabled: false));
    final edited = (await repo.load()).single;
    expect(edited.reading, 'ゆきかた');
    expect(edited.enabled, isFalse);
    await repo.delete('r');
    expect(await repo.load(), isEmpty);
  });
}
