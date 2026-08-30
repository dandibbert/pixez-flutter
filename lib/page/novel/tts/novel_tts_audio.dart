import 'dart:async';

import 'package:just_audio/just_audio.dart';

abstract class NovelTtsAudioPlayer {
  Stream<void> get onComplete;

  Stream<int> get onClipIndex;

  void listen() {}

  Future<void> playFile(String path);

  Future<void> playFiles(List<String> paths);

  Future<void> enqueue(String path);

  Future<bool> seekNext();

  Future<bool> seekPrevious();

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
  final StreamController<int> _clipIndex = StreamController<int>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;
  ConcatenatingAudioSource? _playlist;
  var _armed = false;
  var _replacing = false;
  var _lastIndex = 0;

  @override
  void listen() {
    _stateSub ??= _player.playerStateStream.listen((state) {
      if (!_armed || _replacing) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _armed = false;
        _completed.add(null);
      }
    });
    _indexSub ??= _player.currentIndexStream.listen((index) {
      if (!_armed || _replacing || index == null) {
        return;
      }
      if (index != _lastIndex) {
        _lastIndex = index;
        _clipIndex.add(index);
      }
    });
  }

  @override
  Stream<void> get onComplete => _completed.stream;

  @override
  Stream<int> get onClipIndex => _clipIndex.stream;

  @override
  Future<void> playFile(String path) => playFiles([path]);

  @override
  Future<void> playFiles(List<String> paths) async {
    listen();
    if (paths.isEmpty) {
      return;
    }
    _armed = false;
    _replacing = true;
    _playlist = null;
    try {
      await _player.stop();
    } catch (_) {}
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: false,
      children: [for (final path in paths) AudioSource.file(path)],
    );
    _playlist = playlist;
    _lastIndex = 0;
    try {
      await _player.setAudioSource(playlist, preload: true);
    } finally {
      _replacing = false;
    }
    _armed = true;
    await _player.play();
  }

  @override
  Future<void> enqueue(String path) async {
    final playlist = _playlist;
    if (!_armed || _replacing || playlist == null) {
      return;
    }
    await playlist.add(AudioSource.file(path));
  }

  @override
  Future<bool> seekNext() async {
    if (!_player.hasNext) {
      return false;
    }
    await _player.seekToNext();
    return true;
  }

  @override
  Future<bool> seekPrevious() async {
    if (!_player.hasPrevious) {
      return false;
    }
    await _player.seekToPrevious();
    return true;
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() async {
    _armed = false;
    _replacing = true;
    _playlist = null;
    try {
      await _player.stop();
    } finally {
      _replacing = false;
    }
  }

  @override
  Future<Duration?> get position async => _player.position;

  @override
  Future<Duration?> get duration async => _player.duration;

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    await _completed.close();
    await _clipIndex.close();
    await _player.dispose();
  }
}
