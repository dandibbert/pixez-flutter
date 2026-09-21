import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';

enum NovelTtsPreviewStage { synthesis, savingAudio, loadingAudio, playback, cleanup }

class NovelTtsPreviewException implements Exception {
  const NovelTtsPreviewException(this.stage, this.cause);
  final NovelTtsPreviewStage stage;
  final Object cause;

  @override
  String toString() => '${stage.name}: $cause';
}

/// Uses the same request builder and transport as reading. Only playback is
/// isolated, so trying a voice cannot alter the novel queue or its cache.
class NovelTtsPreview {
  NovelTtsPreview({
    AudioPlayer Function()? audioPlayerFactory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _audioPlayerFactory = audioPlayerFactory ?? AudioPlayer.new,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AudioPlayer Function() _audioPlayerFactory;
  final Future<Directory> Function() _temporaryDirectory;
  Future<void>? _task;
  HttpClient? _client;
  AudioPlayer? _player;
  bool _cancelled = false;
  bool _disposed = false;
  int _generation = 0;

  Future<void> play(NovelTtsSettings settings, String text) async {
    final generation = ++_generation;
    await _stopCurrent();
    if (_disposed || generation != _generation) return;
    _cancelled = false;
    final task = _run(settings, text);
    _task = task;
    try {
      await task;
    } finally {
      if (identical(_task, task)) _task = null;
    }
  }

  Future<void> _run(NovelTtsSettings settings, String text) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    _client = client;
    Directory? directory;
    AudioPlayer? player;
    var stage = NovelTtsPreviewStage.synthesis;
    NovelTtsPreviewException? failure;
    StackTrace? failureStack;
    try {
      final bytes = await NovelTtsHttpSynthesizer(client: client)
          .synthesize(settings, text);
      if (_cancelled) return;
      stage = NovelTtsPreviewStage.savingAudio;
      final temporary = await _temporaryDirectory();
      if (_cancelled) return;
      // createTemp creates a child inside an existing directory, not a path
      // obtained by appending a prefix to it. The old parent did not exist.
      directory = await temporary.createTemp('novel_tts_preview_');
      if (_cancelled) return;
      final file = await File('${directory.path}/preview.mp3').writeAsBytes(bytes);
      if (_cancelled) return;
      stage = NovelTtsPreviewStage.loadingAudio;
      player = _audioPlayerFactory();
      _player = player;
      final duration = await player.setFilePath(file.path)
          .timeout(const Duration(seconds: 15));
      if (_cancelled) return;
      stage = NovelTtsPreviewStage.playback;
      final playbackTimeout = duration == null
          ? const Duration(minutes: 5)
          : duration + const Duration(seconds: 15);
      await player.play().timeout(playbackTimeout);
    } catch (error, stack) {
      if (!_cancelled) {
        failure = NovelTtsPreviewException(stage, error);
        failureStack = stack;
      }
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
      if (identical(_player, player)) _player = null;
      try {
        await player?.dispose();
      } catch (error, stack) {
        if (!_cancelled && failure == null) {
          failure = NovelTtsPreviewException(NovelTtsPreviewStage.cleanup, error);
          failureStack = stack;
        }
      }
      try {
        if (directory != null && await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (error, stack) {
        if (!_cancelled && failure == null) {
          failure = NovelTtsPreviewException(NovelTtsPreviewStage.cleanup, error);
          failureStack = stack;
        }
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  Future<void> stop() async {
    _generation++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    _cancelled = true;
    _client?.close(force: true);
    try {
      await _player?.stop();
    } catch (_) {
      // Disposal below still releases the player after a stop failure.
    }
    try {
      await _task;
    } catch (_) {
      // play() delivers the original failure to the caller.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
