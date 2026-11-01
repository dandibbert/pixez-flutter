import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_export.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

void main() {
  NovelSpansData span(NovelSpansType type, String text) =>
      NovelSpansData(type, text);

  test('exports every page with page markers and resolved markup', () {
    final text = novelExportText(
      title: '月の夜',
      author: '柚子',
      novelId: 42,
      seriesTitle: '探偵事務所',
      spans: [
        span(NovelSpansType.chapter, '第一章'),
        span(NovelSpansType.normal, '\n'),
        span(NovelSpansType.rb, '漢字>かんじ'),
        span(NovelSpansType.normal, 'を読む。'),
        span(NovelSpansType.jump, '2'),
        span(NovelSpansType.newPage, ''),
        span(NovelSpansType.normal, '\n二ページ目。\n'),
        span(NovelSpansType.uploadedImage, 'https://i.pximg.net/a.jpg'),
        span(NovelSpansType.newPage, ''),
        span(NovelSpansType.normal, '三ページ目。'),
      ],
    );
    expect(
      text,
      '月の夜\n探偵事務所\n柚子\nhttps://www.pixiv.net/novel/show.php?id=42\n'
      '\n\n—— 1 / 3 ——\n\n【第一章】\n漢字（かんじ）を読む。'
      '\n\n—— 2 / 3 ——\n\n二ページ目。\nhttps://i.pximg.net/a.jpg'
      '\n\n—— 3 / 3 ——\n\n三ページ目。\n',
    );
  });

  test('a single page novel has no page markers', () {
    final text = novelExportText(
      title: 'One',
      author: 'A',
      novelId: 1,
      spans: [NovelSpansData(NovelSpansType.normal, '本文')],
    );
    expect(text, 'One\nA\nhttps://www.pixiv.net/novel/show.php?id=1\n\n\n本文\n');
  });
}
