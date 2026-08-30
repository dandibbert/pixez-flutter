import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_live_activity.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_system_presenter.dart';

class PresenterPort implements NovelTtsAudioPort {
  final eventsController = StreamController<NovelTtsAudioEvent>.broadcast();
  @override
  Stream<NovelTtsAudioEvent> get events => eventsController.stream;
  @override
  Future<void> append(NovelTtsPlaybackItem item) async {}
  @override
  Future<void> dispose() async => eventsController.close();
  @override
  Future<void> load(List<NovelTtsPlaybackItem> items) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipTo(int index) async {}
  @override
  Future<void> stop() async {}
}

class Live implements NovelTtsLiveActivity {
  final payloads = <NovelTtsLiveActivityPayload>[];
  int ends = 0;
  @override
  Future<bool> end() async {
    ends++;
    return true;
  }

  @override
  Future<bool> start(NovelTtsLiveActivityPayload payload) async {
    payloads.add(payload);
    return true;
  }

  @override
  Future<bool> update(NovelTtsLiveActivityPayload payload) async {
    payloads.add(payload);
    return true;
  }
}

void main() {
  test('system presenter always publishes displayText', () async {
    final port = PresenterPort();
    final controller = NovelTtsPlaybackController(port);
    final live = Live();
    final presenter = NovelTtsSystemPresenter(
      controller: controller,
      liveActivity: live,
    );
    addTearDown(() async {
      presenter.dispose();
      controller.dispose();
    });
    await controller.load(const [
      NovelTtsPlaybackItem(
        id: '1',
        filePath: '/a',
        title: 'T',
        author: 'A',
        displayText: '行方',
        pageNumber: 1,
        chunkIndex: 0,
        chunkCount: 1,
        duration: Duration(seconds: 2),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(live.payloads.last.displayText, '行方');
  });
}
