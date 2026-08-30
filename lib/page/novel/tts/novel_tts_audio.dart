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

  AudioPlayer _player;
  final StreamController<void> _completed = StreamController<void>.broadcast();
  final StreamController<int> _clipIndex = StreamController<int>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;
  ConcatenatingAudioSource? _playlist;
  var _armed = false;
  var _replacing = false;
  var _wantPause = false;
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
    }, onError: (_) {});
    _indexSub ??= _player.currentIndexStream.listen((index) {
      if (!_armed || _replacing || index == null) {
        return;
      }
      if (index != _lastIndex) {
        _lastIndex = index;
        _clipIndex.add(index);
      }
    }, onError: (_) {});
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
      _replacing = false;
      _armed = true;
      // play() completes only when the clip ends or is paused. Awaiting it
      // would block pause/resume and keep the UI stuck on synthesizing.
      if (_wantPause) {
        await _player.pause();
      } else {
        unawaited(_playUntilPaused());
      }
    } catch (_) {
      _armed = false;
      _replacing = false;
      await _rebuildPlayer();
      rethrow;
    } finally {
      _replacing = false;
    }
  }

  @override
  Future<void> enqueue(String path) async {
    final playlist = _playlist;
    if (!_armed || _replacing || playlist == null) {
      return;
    }
    try {
      await playlist.add(AudioSource.file(path));
    } catch (_) {}
  }

  @override
  Future<bool> seekNext() async {
    try {
      if (!_player.hasNext) {
        return false;
      }
      await _player.seekToNext();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> seekPrevious() async {
    try {
      if (!_player.hasPrevious) {
        return false;
      }
      await _player.seekToPrevious();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> pause() async {
    _wantPause = true;
    try {
      await _player.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    _wantPause = false;
    unawaited(_playUntilPaused());
  }

  @override
  Future<void> stop() async {
    _wantPause = false;
    _armed = false;
    _replacing = true;
    _playlist = null;
    try {
      await _player.stop();
    } catch (_) {
    } finally {
      _replacing = false;
    }
  }

  @override
  Future<Duration?> get position async {
    try {
      return _player.position;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Future<Duration?> get duration async {
    try {
      return _player.duration;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Future<void> dispose() async {
    _armed = false;
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    await _completed.close();
    await _clipIndex.close();
    try {
      await _player.dispose();
    } catch (_) {}
  }

  Future<void> _playUntilPaused() async {
    try {
      await _player.play();
    } catch (_) {}
    if (_wantPause) {
      try {
        await _player.pause();
      } catch (_) {}
    }
  }

  Future<void> _rebuildPlayer() async {
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    _stateSub = null;
    _indexSub = null;
    _playlist = null;
    try {
      await _player.dispose();
    } catch (_) {}
    _player = AudioPlayer();
    listen();
  }
}
