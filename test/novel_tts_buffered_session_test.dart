import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/session/novel_tts_buffered_session.dart';
import 'package:pixez/page/novel/tts/synthesis/novel_tts_synthesis_engine.dart';

class SessionAudioPort implements NovelTtsAudioPort {
  final loaded = <NovelTtsPlaybackItem>[];
  final eventController = StreamController<NovelTtsAudioEvent>.broadcast();
  int playCalls = 0;
  @override
  Stream<NovelTtsAudioEvent> get events => eventController.stream;
  @override
  Future<void> load(List<NovelTtsPlaybackItem> items) async {
    loaded
      ..clear()
      ..addAll(items);
  }

  @override
  Future<void> append(NovelTtsPlaybackItem item) async => loaded.add(item);
  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> skipTo(int index) async {}
  @override
  Future<void> dispose() => eventController.close();

  void emit({required int index, required Duration position}) {
    eventController.add(
      NovelTtsAudioEvent(
        currentIndex: index,
        position: position,
        processingState: NovelTtsAudioProcessingState.ready,
        playing: true,
      ),
    );
  }
}

NovelTtsSynthesisItem item(String id, int seconds) => NovelTtsSynthesisItem(
  id: id,
  filePath: '/$id.mp3',
  title: 't',
  author: 'a',
  displayText: id,
  spokenText: id,
  ssml: '',
  pageNumber: 1,
  chunkIndex: 0,
  chunkCount: 1,
  duration: Duration(seconds: seconds),
);

void main() {
  test('starts at 90 seconds and appends direct successors in order', () async {
    final audio = SessionAudioPort();
    final session = NovelTtsBufferedSession(audio: audio);
    await session.consume(
      Stream.fromIterable([item('1', 40), item('2', 40), item('3', 20)]),
    );
    expect(audio.loaded.map((e) => e.id), ['1', '2', '3']);
    expect(audio.playCalls, 1);
    expect(session.bufferedDuration, const Duration(seconds: 100));
  });
  test('pauses at target and resumes only below low duration', () async {
    final audio = SessionAudioPort();
    final controller = NovelTtsPlaybackController(audio);
    final session = NovelTtsBufferedSession(
      audio: audio,
      playbackController: controller,
    );
    var produced = 0;
    Stream<NovelTtsSynthesisItem> source() async* {
      for (var index = 0; index < 4; index++) {
        produced++;
        yield item('${index + 1}', 60);
      }
    }

    final consuming = session.consume(source());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(produced, 3);
    expect(session.bufferedDuration, const Duration(seconds: 180));
    audio.emit(index: 1, position: const Duration(seconds: 31));
    await consuming;
    expect(produced, 4);
    expect(audio.loaded.map((item) => item.id), ['1', '2', '3', '4']);
    await session.dispose();
    controller.dispose();
  });

  test('cancelled generated results never reach the playback queue', () async {
    final audio = SessionAudioPort();
    final session = NovelTtsBufferedSession(audio: audio);
    final gate = Completer<void>();
    final consuming = session.consumeGenerated((guard, token) async* {
      await gate.future;
      yield item('stale', 20);
    });
    await Future<void>.delayed(Duration.zero);
    await session.cancel();
    gate.complete();
    await consuming;
    expect(audio.loaded, isEmpty);
    expect(audio.playCalls, 0);
  });

  test('short completed chapter starts without waiting forever', () async {
    final audio = SessionAudioPort();
    final session = NovelTtsBufferedSession(audio: audio);
    await session.consume(Stream.value(item('1', 20)));
    expect(audio.playCalls, 1);
  });
}
