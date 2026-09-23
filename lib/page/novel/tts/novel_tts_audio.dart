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

/// Optional platform events; fake/minimal players need only the base API.
abstract interface class NovelTtsAudioEvents {
  Stream<bool> get onPlaying;

  Stream<Object> get onError;
}

class JustAudioNovelTtsPlayer
    implements NovelTtsAudioPlayer, NovelTtsAudioEvents {
  JustAudioNovelTtsPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final StreamController<void> _completed = StreamController<void>.broadcast();
  final StreamController<int> _clipIndex = StreamController<int>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<SequenceState>? _indexSub;
  ConcatenatingAudioSource? _playlist;
  Future<void> _operations = Future<void>.value();
  var _generation = 0;
  var _armed = false;
  var _replacing = false;
  var _wantPause = false;
  var _disposed = false;
  var _lastIndex = 0;
  var _nextIndex = 0;

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  @override
  void listen() {
    if (_disposed) return;
    _stateSub ??= _player.playerStateStream.listen((state) {
      if (!_armed || _replacing || _disposed) return;
      if (state.processingState == ProcessingState.completed) {
        _armed = false;
        _completed.add(null);
      } else {
        _playing.add(state.playing);
      }
    }, onError: (_) {});
    _errorSub ??= _player.errorStream.listen((error) {
      if (!_disposed && _armed && !_replacing) _errors.add(error);
    });
    _indexSub ??= _player.sequenceStateStream.listen((state) {
      if (!_armed || _replacing || _disposed) return;
      // Source tags stay stable when played entries are removed. The
      // controller therefore sees the same queue indexes after pruning.
      final absoluteIndex = state.currentSource?.tag;
      if (absoluteIndex is int && absoluteIndex != _lastIndex) {
        _lastIndex = absoluteIndex;
        _clipIndex.add(absoluteIndex);
        unawaited(_trimPlayed().catchError((Object _) {}));
      }
    }, onError: (_) {});
  }

  Future<void> _trimPlayed() {
    final generation = _generation;
    return _serialize(() async {
      if (_disposed || generation != _generation || _replacing) return;
      final playlist = _playlist;
      final current = _player.currentIndex;
      if (playlist == null || current == null || current <= 1) return;
      // Retain one previous clip for instant back navigation. Keeping every
      // played source here retains native player items across a whole series.
      await playlist.removeRange(0, current - 1);
    });
  }

  @override
  Stream<void> get onComplete => _completed.stream;

  @override
  Stream<bool> get onPlaying => _playing.stream;

  @override
  Stream<Object> get onError => _errors.stream;

  @override
  Stream<int> get onClipIndex => _clipIndex.stream;

  @override
  Future<void> playFile(String path) => playFiles([path]);

  @override
  Future<void> playFiles(List<String> paths) {
    final generation = ++_generation;
    _armed = false;
    _replacing = true;
    return _serialize(() async {
      if (_disposed || generation != _generation || paths.isEmpty) return;
      listen();
      try {
        await _player.stop();
        if (_disposed || generation != _generation) return;
        _nextIndex = 0;
        final playlist = ConcatenatingAudioSource(
          useLazyPreparation: true,
          children: [
            for (final path in paths) AudioSource.file(path, tag: _nextIndex++),
          ],
        );
        _playlist = playlist;
        _lastIndex = 0;
        await _player.setAudioSource(playlist, preload: true);
        if (_disposed || generation != _generation) return;
        _replacing = false;
        _armed = true;
        if (_wantPause) {
          await _player.pause();
        } else {
          unawaited(_playUntilPaused(generation));
        }
      } catch (_) {
        if (generation == _generation) {
          _armed = false;
          _playlist = null;
        }
        rethrow;
      } finally {
        if (generation == _generation) _replacing = false;
      }
    });
  }

  @override
  Future<void> enqueue(String path) {
    final generation = _generation;
    return _serialize(() async {
      final playlist = _playlist;
      if (_disposed ||
          generation != _generation ||
          !_armed ||
          _replacing ||
          playlist == null)
        return;
      await playlist.add(AudioSource.file(path, tag: _nextIndex++));
    });
  }

  @override
  Future<bool> seekNext() async {
    if (_disposed || _replacing || !_armed) return false;
    try {
      if (!_player.hasNext) return false;
      await _player.seekToNext();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> seekPrevious() async {
    if (_disposed || _replacing || !_armed) return false;
    try {
      if (!_player.hasPrevious) return false;
      await _player.seekToPrevious();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> pause() async {
    _wantPause = true;
    if (_disposed) return;
    try {
      await _player.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    _wantPause = false;
    if (_disposed) return;
    unawaited(_playUntilPaused(_generation));
  }

  @override
  Future<void> stop() {
    final generation = ++_generation;
    _wantPause = false;
    _armed = false;
    _replacing = true;
    _playlist = null;
    return _serialize(() async {
      if (_disposed || generation != _generation) return;
      try {
        await _player.stop();
        // stop() releases decoders but retains the source tree; clear it too.
        await _player.setAudioSource(
          ConcatenatingAudioSource(children: []),
          preload: false,
        );
      } catch (_) {
      } finally {
        if (generation == _generation) _replacing = false;
      }
    });
  }

  @override
  Future<Duration?> get position async => _player.position;

  @override
  Future<Duration?> get duration async => _player.duration;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _armed = false;
    _playlist = null;
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    await _errorSub?.cancel();
    await _serialize(() async {
      try {
        await _player.dispose();
      } catch (_) {}
    });
    await _completed.close();
    await _clipIndex.close();
    await _playing.close();
    await _errors.close();
  }

  Future<void> _playUntilPaused(int generation) async {
    try {
      await _player.play();
      if (!_disposed && generation == _generation && _wantPause) {
        await _player.pause();
      }
    } catch (error) {
      if (!_disposed && generation == _generation) _errors.add(error);
    }
  }
}
