import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';

class NovelTtsAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements NovelTtsAudioPort {
  NovelTtsAudioHandler._(this._player) {
    _subscriptions.add(
      _player.playerStateStream.listen((_) => _broadcastPlayerState()),
    );
    _subscriptions.add(
      _player.positionStream.listen((_) => _broadcastPlayerState()),
    );
    _subscriptions.add(
      _player.currentIndexStream.listen((index) {
        _syncCurrentMediaItem(index);
        _broadcastPlayerState();
      }),
    );
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) => _broadcastPlayerState(),
        onError: _events.addError,
      ),
    );
  }

  final just_audio.AudioPlayer _player;
  final StreamController<NovelTtsAudioEvent> _events =
      StreamController<NovelTtsAudioEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<NovelTtsPlaybackItem> _items = const [];

  static NovelTtsAudioHandler create() {
    final handler = NovelTtsAudioHandler._(just_audio.AudioPlayer());
    unawaited(handler._configureAudioSession());
    return handler;
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  @override
  Stream<NovelTtsAudioEvent> get events => _events.stream;

  @override
  Future<void> load(List<NovelTtsPlaybackItem> items) async {
    _items = List<NovelTtsPlaybackItem>.unmodifiable(items);
    queue.add(_items.map(_toMediaItem).toList(growable: false));
    mediaItem.add(_items.isEmpty ? null : _toMediaItem(_items.first));
    if (items.isEmpty) {
      await _player.stop();
      return;
    }
    await _player.setAudioSources(
      items
          .map((item) => just_audio.AudioSource.file(item.filePath))
          .toList(growable: false),
      preload: true,
    );
    _broadcastPlayerState();
  }

  @override
  Future<void> append(NovelTtsPlaybackItem item) async {
    _items = List<NovelTtsPlaybackItem>.unmodifiable([..._items, item]);
    queue.add(_items.map(_toMediaItem).toList(growable: false));
    await _player.addAudioSource(just_audio.AudioSource.file(item.filePath));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) =>
      _player.setSpeed(speed.clamp(0.5, 2.0));

  @override
  Future<void> skipTo(int index) => skipToQueueItem(index);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _player.seek(Duration.zero, index: index);
    _syncCurrentMediaItem(index);
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 5)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
    await _player.dispose();
  }

  MediaItem _toMediaItem(NovelTtsPlaybackItem item) => MediaItem(
    id: item.id,
    title: item.title,
    artist: item.author,
    duration: item.duration,
    displayTitle: item.title,
    displaySubtitle: item.author,
    displayDescription: item.displayText,
    extras: <String, dynamic>{
      'filePath': item.filePath,
      'displayText': item.displayText,
      'page': item.pageNumber,
      'chunkIndex': item.chunkIndex,
      'chunkCount': item.chunkCount,
    },
  );

  void _syncCurrentMediaItem(int? index) {
    if (index == null || index < 0 || index >= _items.length) return;
    mediaItem.add(_toMediaItem(_items[index]));
  }

  void _broadcastPlayerState() {
    final processingState = switch (_player.processingState) {
      just_audio.ProcessingState.idle => AudioProcessingState.idle,
      just_audio.ProcessingState.loading => AudioProcessingState.loading,
      just_audio.ProcessingState.buffering => AudioProcessingState.buffering,
      just_audio.ProcessingState.ready => AudioProcessingState.ready,
      just_audio.ProcessingState.completed => AudioProcessingState.completed,
    };
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        queueIndex: _player.currentIndex,
      ),
    );
    if (!_events.isClosed) {
      _events.add(
        NovelTtsAudioEvent(
          currentIndex: _player.currentIndex,
          position: _player.position,
          processingState: switch (_player.processingState) {
            just_audio.ProcessingState.idle =>
              NovelTtsAudioProcessingState.idle,
            just_audio.ProcessingState.loading =>
              NovelTtsAudioProcessingState.loading,
            just_audio.ProcessingState.buffering =>
              NovelTtsAudioProcessingState.buffering,
            just_audio.ProcessingState.ready =>
              NovelTtsAudioProcessingState.ready,
            just_audio.ProcessingState.completed =>
              NovelTtsAudioProcessingState.completed,
          },
          playing: _player.playing,
        ),
      );
    }
  }
}

class NovelTtsAudioService {
  NovelTtsAudioService._();

  static Future<NovelTtsAudioHandler>? _initializing;

  static Future<NovelTtsAudioHandler> initialize() {
    return _initializing ??= AudioService.init<NovelTtsAudioHandler>(
      builder: NovelTtsAudioHandler.create,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.perol.pixez.novel_tts',
        androidNotificationChannelName: 'Novel text to speech',
        androidNotificationChannelDescription:
            'Background playback controls for novel narration',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    );
  }

  static bool get supported => Platform.isAndroid || Platform.isIOS;
}
