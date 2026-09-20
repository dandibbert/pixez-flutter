import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_chapter_loader.dart';
import 'package:pixez/page/novel/tts/novel_tts_now_playing.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

class _Audio extends Fake implements NovelTtsAudioPlayer {
  @override
  void listen() {}
  @override
  Stream<void> get onComplete => const Stream.empty();
  @override
  Stream<int> get onClipIndex => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _NowPlaying extends NovelTtsNowPlaying {
  @override
  void bind() {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> keepAlive(bool enabled) async {}
}

class _Store extends NovelStore {
  _Store() : super(1, null) {
    errorMessage = 'offline';
  }
  @override
  Future<void> fetch() async {}
}

Widget _reader() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: NovelViewerPage(id: 1, novelStore: _Store()),
);

void main() {
  testWidgets('closing a reader releases its chapter loader and navigation', (
    tester,
  ) async {
    final controller = NovelTtsController(audio: _Audio(), nowPlaying: _NowPlaying());
    NovelTtsController.debugInstance = controller;
    addTearDown(() {
      NovelTtsController.debugInstance = null;
      controller.dispose();
    });
    await tester.pumpWidget(_reader());
    final loader = controller.onLoadChapter!;
    expect(controller.onNavigate, isNotNull);

    await tester.pumpWidget(const SizedBox());
    expect(controller.onNavigate, isNull);
    expect(controller.onLoadChapter, same(loadNovelTtsChapter));
    expect(await loader(99), isNull, reason: 'a stale loader must not fetch after disposal');
  });

  testWidgets('closing an old reader preserves a newer playback owner', (
    tester,
  ) async {
    final controller = NovelTtsController(audio: _Audio(), nowPlaying: _NowPlaying());
    NovelTtsController.debugInstance = controller;
    addTearDown(() {
      NovelTtsController.debugInstance = null;
      controller.dispose();
    });
    await tester.pumpWidget(_reader());
    void navigate(NovelTtsNavigate value) {}
    Future<NovelTtsChapter?> load(int id) async => null;
    controller.onNavigate = navigate;
    controller.onLoadChapter = load;
    await tester.pumpWidget(const SizedBox());
    expect(controller.onNavigate, same(navigate));
    expect(controller.onLoadChapter, same(load));
  });

  for (final covered in [false, true]) {
    testWidgets(covered
        ? 'a chapter change cannot replace an open settings route'
        : 'background playback cannot navigate an unrelated reader', (tester) async {
      final controller = NovelTtsController(audio: _Audio(), nowPlaying: _NowPlaying());
      controller.session = NovelTtsSession(
        novelId: covered ? 1 : 42,
        title: 'playing book', author: 'author', page: 1,
        totalPages: 2, chunks: const ['text'],
      );
      NovelTtsController.debugInstance = controller;
      addTearDown(() {
        NovelTtsController.debugInstance = null;
        controller.dispose();
      });
      await tester.pumpWidget(_reader());
      if (covered) {
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('voice settings')),
        ));
        await tester.pumpAndSettle();
      }
      controller.onNavigate!(const NovelTtsNavigate(
        kind: NovelTtsNavigateKind.series, seriesNovelId: 2, keepPlaying: true,
      ));
      await tester.pumpAndSettle();
      if (covered) {
        expect(find.text('voice settings'), findsOneWidget);
      }
      final reader = tester.widget<NovelViewerPage>(
        find.byType(NovelViewerPage, skipOffstage: false),
      );
      expect(reader.id, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
