import 'dart:async';

import 'package:just_audio/just_audio.dart';

abstract class NovelTtsAudioPlayer {
  Stream<void> get onComplete;

  void listen() {}

  Future<void> playFile(String path);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<Duration?> get position;

  Future<Duration?> get duration;

  Future<void> dispose();
}

class JustAudioNovelTtsPlayer implements NovelTtsAudioPlayer {
  JustAudioNovelTtsPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final StreamController<void> _completed = StreamController<void>.broadcast();
  StreamSubscription<PlayerState>? _subscription;
  var _armed = false;

  void listen() {
    _subscription ??= _player.playerStateStream.listen((state) {
      if (!_armed) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _armed = false;
        _completed.add(null);
      }
    });
  }

  @override
  Stream<void> get onComplete => _completed.stream;

  @override
  Future<void> playFile(String path) async {
    listen();
    _armed = true;
    await _player.setFilePath(path);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() async {
    _armed = false;
    await _player.stop();
  }

  @override
  Future<Duration?> get position async => _player.position;

  @override
  Future<Duration?> get duration async => _player.duration;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _completed.close();
    await _player.dispose();
  }
}
