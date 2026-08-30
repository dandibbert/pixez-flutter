import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/session/novel_tts_buffered_session.dart';
import 'package:pixez/page/novel/tts/synthesis/novel_tts_synthesis_engine.dart';

class SessionAudioPort implements NovelTtsAudioPort {
  final loaded = <NovelTtsPlaybackItem>[];
  int playCalls = 0;
  @override
  Stream<NovelTtsAudioEvent> get events => const Stream.empty();
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
  Future<void> dispose() async {}
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
  test('short completed chapter starts without waiting forever', () async {
    final audio = SessionAudioPort();
    final session = NovelTtsBufferedSession(audio: audio);
    await session.consume(Stream.value(item('1', 20)));
    expect(audio.playCalls, 1);
  });
}
