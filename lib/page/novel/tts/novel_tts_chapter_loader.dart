import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';

/// Background series playback must not retain a disposed reader route.
Future<NovelTtsChapter?> loadNovelTtsChapter(int id) async {
  final store = NovelStore(id, null);
  await store.fetch();
  return novelTtsChapterFromStore(store);
}

NovelTtsChapter? novelTtsChapterFromStore(NovelStore store) {
  final novel = store.novel;
  if (novel == null || store.spans.isEmpty) return null;
  final pages = NovelReaderSplitCache().pages(store.spans);
  final navigation = store.novelTextResponse?.seriesNavigation;
  return NovelTtsChapter(
    novelId: store.id,
    title: novel.title,
    author: novel.user.name,
    pageTexts: [
      for (var i = 0; i < pages.length; i++) novelTtsTextFromPages(pages, i),
    ],
    coverUrl: novel.imageUrls.medium,
    prevSeriesId: navigation?.prevNovel?.viewable == true
        ? navigation!.prevNovel!.id
        : null,
    nextSeriesId: navigation?.nextNovel?.viewable == true
        ? navigation!.nextNovel!.id
        : null,
  );
}
