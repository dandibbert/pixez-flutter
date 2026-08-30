import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/domain/novel_tts_document.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

void main() {
  test('extracts ruby and continues through newpage while skipping media', () {
    final document = NovelTtsDocument.fromSpans('42', [
      NovelSpansData(NovelSpansType.normal, '前'),
      NovelSpansData(NovelSpansType.rb, '人気>にんき'),
      NovelSpansData(NovelSpansType.pixivImage, 'ignored'),
      NovelSpansData(NovelSpansType.newPage, ''),
      NovelSpansData(NovelSpansType.normal, '次頁'),
    ]);
    expect(document.pages.length, 2);
    expect(document.pages[0].displayText, '前人気');
    expect(document.pages[0].ruby.single.reading, 'にんき');
    expect(document.pages[1].displayText, '次頁');
    expect(document.pages.map((e) => e.pageNumber), [1, 2]);
  });
}
