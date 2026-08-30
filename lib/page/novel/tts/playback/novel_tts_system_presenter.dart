import 'dart:async';

import 'package:pixez/page/novel/tts/playback/novel_tts_live_activity.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';

class NovelTtsSystemPresenter {
  NovelTtsSystemPresenter({
    required this.controller,
    required this.liveActivity,
  }) {
    controller.addListener(_publish);
  }
  final NovelTtsPlaybackController controller;
  final NovelTtsLiveActivity liveActivity;
  bool _active = false;
  String? _lastSignature;
  void _publish() {
    final snapshot = controller.snapshot;
    final item = snapshot.currentItem;
    if (item == null ||
        snapshot.state == NovelTtsPlaybackState.idle ||
        snapshot.state == NovelTtsPlaybackState.completed) {
      if (_active) {
        _active = false;
        _lastSignature = null;
        unawaited(liveActivity.end());
      }
      return;
    }
    final payload = NovelTtsLiveActivityPayload(
      title: item.title,
      author: item.author,
      displayText: item.displayText,
      page: item.pageNumber,
      chunkIndex: item.chunkIndex,
      chunkTotal: item.chunkCount,
      playbackState: snapshot.state.name,
    );
    final signature = '${item.id}|${snapshot.state.name}|${item.displayText}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    if (_active) {
      unawaited(liveActivity.update(payload));
    } else {
      _active = true;
      unawaited(liveActivity.start(payload));
    }
  }

  void dispose() {
    controller.removeListener(_publish);
    if (_active) unawaited(liveActivity.end());
    _active = false;
  }
}
