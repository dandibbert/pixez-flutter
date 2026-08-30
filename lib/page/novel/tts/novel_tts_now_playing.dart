import 'package:flutter/services.dart';

typedef NovelTtsRemoteHandler = void Function(String action);

class NovelTtsNowPlayingInfo {
  const NovelTtsNowPlayingInfo({
    required this.title,
    required this.artist,
    required this.subtitle,
    required this.isPlaying,
    this.durationMs = 0,
    this.positionMs = 0,
  });

  final String title;
  final String artist;
  final String subtitle;
  final bool isPlaying;
  final int durationMs;
  final int positionMs;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'subtitle': subtitle,
      'isPlaying': isPlaying,
      'durationMs': durationMs,
      'positionMs': positionMs,
    };
  }
}

class NovelTtsNowPlaying {
  NovelTtsNowPlaying({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.perol.dev/novel_tts');

  final MethodChannel _channel;
  NovelTtsRemoteHandler? onRemote;

  void bind() {
    _channel.setMethodCallHandler((call) async {
      onRemote?.call(call.method);
    });
  }

  Future<void> start(NovelTtsNowPlayingInfo info) {
    return _invoke('start', info.toMap());
  }

  Future<void> update(NovelTtsNowPlayingInfo info) {
    return _invoke('update', info.toMap());
  }

  Future<void> stop() {
    return _invoke('stop', const {});
  }

  Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (_) {}
  }
}
