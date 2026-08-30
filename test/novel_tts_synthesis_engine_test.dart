import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/domain/novel_tts_document.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';
import 'package:pixez/page/novel/tts/provider/tts_request_builder.dart';
import 'package:pixez/page/novel/tts/synthesis/novel_tts_synthesis_engine.dart';

class FakeExecutor implements TtsHttpExecutor {
  final requests = <TtsHttpRequest>[];
  @override
  Future<List<int>> execute(TtsHttpRequest request) async {
    requests.add(request);
    return [0x49, 0x44, 0x33, 0, 0, 0];
  }
}

void main() {
  test(
    'projects stable display/spoken text and reuses validated cache',
    () async {
      final directory = await Directory.systemTemp.createTemp('pixez-tts-test');
      addTearDown(() => directory.delete(recursive: true));
      final executor = FakeExecutor();
      final engine = NovelTtsSynthesisEngine(
        executor: executor,
        cacheDirectory: directory,
        targetLength: 20,
        maxLength: 30,
      );
      const profile = TtsProfile(
        id: 'c',
        name: 'Custom',
        enabled: true,
        provider: CustomTtsProviderConfig(
          endpointTemplate: 'https://x.test/tts',
          method: CustomHttpMethod.post,
          bodyTemplate: '{{text}}',
          bodyIsJson: false,
        ),
        voice: 'v',
      );
      const document = NovelTtsDocument(
        novelId: '1',
        pages: [
          NovelTtsPageDocument(pageNumber: 1, displayText: '行方です。', ruby: []),
        ],
      );
      final first = await engine.synthesize(
        document: document,
        profile: profile,
        rules: const [
          PronunciationRule(
            id: 'r',
            surface: '行方',
            reading: 'ゆくえ',
            scope: PronunciationScope.global,
          ),
        ],
        context: const PronunciationContext(novelId: '1'),
        title: '題',
        author: '著者',
      );
      expect(first.single.displayText, '行方です。');
      expect(first.single.spokenText, 'ゆくえです。');
      expect(executor.requests.single.body, 'ゆくえです。');
      expect(await File(first.single.filePath).exists(), isTrue);
      final second = await engine.synthesize(
        document: document,
        profile: profile,
        rules: const [
          PronunciationRule(
            id: 'r',
            surface: '行方',
            reading: 'ゆくえ',
            scope: PronunciationScope.global,
          ),
        ],
        context: const PronunciationContext(novelId: '1'),
        title: '題',
        author: '著者',
      );
      expect(second.single.filePath, first.single.filePath);
      expect(executor.requests, hasLength(1));
    },
  );

  test(
    'current-position start skips earlier display text on the first page',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pixez-tts-position',
      );
      addTearDown(() => directory.delete(recursive: true));
      final executor = FakeExecutor();
      final engine = NovelTtsSynthesisEngine(
        executor: executor,
        cacheDirectory: directory,
        targetLength: 20,
        maxLength: 30,
      );
      const profile = TtsProfile(
        id: 'c',
        name: 'Custom',
        enabled: true,
        provider: CustomTtsProviderConfig(
          endpointTemplate: 'https://x.test/tts',
          method: CustomHttpMethod.post,
          bodyTemplate: '{{text}}',
          bodyIsJson: false,
        ),
        voice: 'v',
      );
      const document = NovelTtsDocument(
        novelId: '1',
        pages: [
          NovelTtsPageDocument(
            pageNumber: 1,
            displayText: '前半です。後半です。',
            ruby: [],
          ),
        ],
      );
      final items = await engine.synthesize(
        document: document,
        profile: profile,
        rules: const [],
        context: const PronunciationContext(novelId: '1'),
        title: '題',
        author: '著者',
        startTextOffset: 5,
      );
      expect(items.map((item) => item.displayText).join(), '後半です。');
    },
  );

  test('rendered secret values never affect cache paths', () async {
    final directory = await Directory.systemTemp.createTemp('pixez-tts-secret');
    addTearDown(() => directory.delete(recursive: true));
    final executor = FakeExecutor();
    final engine = NovelTtsSynthesisEngine(
      executor: executor,
      cacheDirectory: directory,
    );
    const profile = TtsProfile(
      id: 'secret',
      name: 'Secret URL',
      enabled: true,
      provider: CustomTtsProviderConfig(
        endpointTemplate: 'https://x.test/{{secret:token}}/tts',
        method: CustomHttpMethod.get,
      ),
      voice: 'v',
    );
    const document = NovelTtsDocument(
      novelId: '1',
      pages: [
        NovelTtsPageDocument(pageNumber: 1, displayText: '本文。', ruby: []),
      ],
    );
    final first = await engine.synthesize(
      document: document,
      profile: profile,
      rules: const [],
      context: const PronunciationContext(novelId: '1'),
      title: '題',
      author: '著者',
      secrets: const {'token': 'first-secret'},
    );
    final second = await engine.synthesize(
      document: document,
      profile: profile,
      rules: const [],
      context: const PronunciationContext(novelId: '1'),
      title: '題',
      author: '著者',
      secrets: const {'token': 'second-secret'},
    );
    expect(first.single.filePath, second.single.filePath);
    expect(first.single.filePath, isNot(contains('first-secret')));
    expect(executor.requests, hasLength(1));
  });
}
