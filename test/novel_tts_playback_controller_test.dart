import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';

class FakeNovelTtsAudioPort implements NovelTtsAudioPort {
  final _events = StreamController<NovelTtsAudioEvent>.broadcast();
  List<NovelTtsPlaybackItem> loaded = const [];
  bool played = false;
  bool paused = false;
  bool stopped = false;
  int? skippedTo;

  @override
  Stream<NovelTtsAudioEvent> get events => _events.stream;

  void emit(NovelTtsAudioEvent event) => _events.add(event);

  @override
  Future<void> load(List<NovelTtsPlaybackItem> items) async => loaded = items;

  @override
  Future<void> append(NovelTtsPlaybackItem item) async =>
      loaded = [...loaded, item];

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> play() async => played = true;

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> skipTo(int index) async => skippedTo = index;

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> dispose() async => _events.close();
}

NovelTtsPlaybackItem item(int index) => NovelTtsPlaybackItem(
  id: 'item-$index',
  filePath: '/tmp/$index.mp3',
  title: 'Novel',
  author: 'Author',
  displayText: index == 0 ? '行方' : '次の文',
  pageNumber: 2,
  chunkIndex: index + 1,
  chunkCount: 2,
  duration: const Duration(seconds: 10),
);

void main() {
  test(
    'keeps displayText for subtitles while exposing playback progress',
    () async {
      final port = FakeNovelTtsAudioPort();
      final controller = NovelTtsPlaybackController(port);
      await controller.load([item(0), item(1)]);

      port.emit(
        const NovelTtsAudioEvent(
          currentIndex: 0,
          position: Duration(seconds: 3),
          processingState: NovelTtsAudioProcessingState.ready,
          playing: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.snapshot.currentItem?.displayText, '行方');
      expect(controller.snapshot.position, const Duration(seconds: 3));
      expect(controller.snapshot.state, NovelTtsPlaybackState.playing);
      expect(controller.snapshot.progress, closeTo(.3, .001));
    },
  );

  test(
    'maps exhausted audio to honest buffering without fake playback',
    () async {
      final port = FakeNovelTtsAudioPort();
      final controller = NovelTtsPlaybackController(port);
      await controller.load([item(0)]);
      controller.updateBufferedDuration(Duration.zero);

      port.emit(
        const NovelTtsAudioEvent(
          currentIndex: 0,
          position: Duration(seconds: 10),
          processingState: NovelTtsAudioProcessingState.buffering,
          playing: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.snapshot.state, NovelTtsPlaybackState.buffering);
      expect(controller.snapshot.playing, isFalse);
    },
  );

  test('manual page changes do not mutate the audio queue', () async {
    final port = FakeNovelTtsAudioPort();
    final controller = NovelTtsPlaybackController(port);
    await controller.load([item(0), item(1)]);

    controller.noteVisiblePageChanged(9);

    expect(port.loaded.map((entry) => entry.id), ['item-0', 'item-1']);
    expect(port.skippedTo, isNull);
    expect(controller.snapshot.visiblePage, 9);
    expect(controller.snapshot.currentItem?.pageNumber, 2);
  });
}
