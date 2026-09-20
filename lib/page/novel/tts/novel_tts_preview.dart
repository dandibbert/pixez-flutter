import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';

/// A short, disposable preview. It does not enter the novel playback queue.
class NovelTtsPreview {
  Future<void>? _task;
  HttpClient? _client;
  AudioPlayer? _player;
  bool _cancelled = false;
  bool _disposed = false;

  Future<void> play(NovelTtsSettings settings, String text) async {
    await stop();
    if (_disposed) return;
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
    final client = HttpClient();
    _client = client;
    Directory? directory;
    AudioPlayer? player;
    try {
      final bytes = await NovelTtsHttpSynthesizer(
        client: client,
      ).synthesize(settings, text).timeout(const Duration(seconds: 30));
      if (_cancelled) return;
      final temporary = await getTemporaryDirectory();
      if (_cancelled) return;
      directory = await Directory(
        '${temporary.path}/novel_tts_preview_',
      ).createTemp();
      if (_cancelled) return;
      final file = await File(
        '${directory.path}/preview.mp3',
      ).writeAsBytes(bytes);
      if (_cancelled) return;
      player = AudioPlayer();
      _player = player;
      await player.setFilePath(file.path).timeout(const Duration(seconds: 15));
      if (_cancelled) return;
      await player.play().timeout(const Duration(seconds: 30));
    } catch (_) {
      if (!_cancelled) rethrow;
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
      if (identical(_player, player)) _player = null;
      try {
        await player?.dispose();
      } finally {
        if (directory != null && await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    }
  }

  Future<void> stop() async {
    _cancelled = true;
    _client?.close(force: true);
    try {
      await _player?.stop();
    } catch (_) {
      // Disposal below still releases the native player after a stop failure.
    }
    try {
      await _task;
    } catch (_) {
      // The caller of play receives the preview error.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
