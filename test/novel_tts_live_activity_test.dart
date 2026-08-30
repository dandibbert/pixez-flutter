import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_live_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends displayText rather than pronunciation text to iOS', () async {
    const channel = MethodChannel('com.perol.dev/novel_tts_live_activity');
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return true;
        });
    final bridge = MethodChannelNovelTtsLiveActivity();

    await bridge.start(
      const NovelTtsLiveActivityPayload(
        title: 'Novel',
        author: 'Author',
        displayText: '行方',
        page: 3,
        chunkIndex: 4,
        chunkTotal: 9,
        playbackState: 'playing',
      ),
    );

    expect(captured?.method, 'start');
    expect(captured?.arguments, containsPair('displayText', '行方'));
    expect(captured?.arguments.toString(), isNot(contains('ゆくえ')));
  });
}
