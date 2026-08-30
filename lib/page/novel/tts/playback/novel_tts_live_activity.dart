import 'package:flutter/services.dart';

class NovelTtsLiveActivityPayload {
  const NovelTtsLiveActivityPayload({
    required this.title,
    required this.author,
    required this.displayText,
    required this.page,
    required this.chunkIndex,
    required this.chunkTotal,
    required this.playbackState,
  });

  final String title;
  final String author;
  final String displayText;
  final int page;
  final int chunkIndex;
  final int chunkTotal;
  final String playbackState;

  Map<String, Object> toMap() => <String, Object>{
    'title': title,
    'author': author,
    'displayText': displayText,
    'page': page,
    'chunkIndex': chunkIndex,
    'chunkTotal': chunkTotal,
    'playbackState': playbackState,
  };
}

abstract interface class NovelTtsLiveActivity {
  Future<bool> start(NovelTtsLiveActivityPayload payload);
  Future<bool> update(NovelTtsLiveActivityPayload payload);
  Future<bool> end();
}

class MethodChannelNovelTtsLiveActivity implements NovelTtsLiveActivity {
  static const MethodChannel _channel = MethodChannel(
    'com.perol.dev/novel_tts_live_activity',
  );

  @override
  Future<bool> start(NovelTtsLiveActivityPayload payload) async {
    return await _channel.invokeMethod<bool>('start', payload.toMap()) ?? false;
  }

  @override
  Future<bool> update(NovelTtsLiveActivityPayload payload) async {
    return await _channel.invokeMethod<bool>('update', payload.toMap()) ?? false;
  }

  @override
  Future<bool> end() async {
    return await _channel.invokeMethod<bool>('end') ?? false;
  }
}
