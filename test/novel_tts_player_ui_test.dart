import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/ui/novel_tts_full_player.dart';
import 'package:pixez/page/novel/tts/ui/novel_tts_start_sheet.dart';

class PlayerPort implements NovelTtsAudioPort {
  final controller = StreamController<NovelTtsAudioEvent>.broadcast();
  @override
  Stream<NovelTtsAudioEvent> get events => controller.stream;
  @override
  Future<void> append(NovelTtsPlaybackItem item) async {}
  @override
  Future<void> load(List<NovelTtsPlaybackItem> items) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> skipTo(int index) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => controller.close();
}

void main() {
  testWidgets('start sheet exposes first current page and selected position', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelTtsStartSheet(currentPage: 3, hasSelectedPosition: true),
        ),
      ),
    );
    expect(find.text('从第一页开始'), findsOneWidget);
    expect(find.text('从第 3 页开始'), findsOneWidget);
    expect(find.text('从当前位置开始'), findsOneWidget);
  });
  testWidgets('start sheet uses consistent Traditional Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: NovelTtsStartSheet(currentPage: 3)),
      ),
    );

    expect(find.text('小說語音朗讀'), findsOneWidget);
    expect(find.text('從第 3 頁開始'), findsOneWidget);
    expect(find.textContaining('朗读'), findsNothing);
    expect(find.textContaining('开始'), findsNothing);
  });

  testWidgets('full player shows displayText and queue position', (
    tester,
  ) async {
    final port = PlayerPort();
    final controller = NovelTtsPlaybackController(port);
    addTearDown(controller.dispose);
    await controller.load(const [
      NovelTtsPlaybackItem(
        id: '1',
        filePath: '/a',
        title: 'Novel',
        author: 'Author',
        displayText: '行方',
        pageNumber: 2,
        chunkIndex: 0,
        chunkCount: 3,
        duration: Duration(seconds: 10),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: NovelTtsFullPlayer(controller: controller)),
      ),
    );
    expect(find.text('行方'), findsOneWidget);
    expect(find.text('Page 2 · Part 1/3'), findsOneWidget);
    expect(find.text('Novel'), findsOneWidget);
  });
}
