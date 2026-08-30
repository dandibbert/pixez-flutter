import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/ui/novel_tts_mini_player.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';

void main() {
  testWidgets('mini player reserves layout space above page navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelReaderScaffold(
            header: const SizedBox(key: Key('header'), height: 40),
            article: const SizedBox(key: Key('article')),
            miniPlayer: NovelTtsMiniPlayer(
              displayText: '行方',
              statusText: '02:30 buffered',
              pageAndChunkText: 'Page 2 · 3/8',
              playing: true,
              buffering: false,
              onTogglePlayback: () {},
              onOpen: () {},
              onClose: () {},
            ),
            pageNav: const SizedBox(key: Key('pageNav'), height: 50),
          ),
        ),
      ),
    );

    final playerBottom = tester.getBottomRight(find.byType(NovelTtsMiniPlayer)).dy;
    final navTop = tester.getTopLeft(find.byKey(const Key('pageNav'))).dy;
    expect(playerBottom, lessThanOrEqualTo(navTop));
    expect(find.text('行方'), findsOneWidget);
  });
}
