import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

/// Turns a whole novel, every `[newpage]` page of it, into plain text for
/// saving as a .txt file.
///
/// pixiv markup is resolved the way a reader sees it: ruby becomes
/// `漢字（かんじ）`, chapter marks become their title on a line of their own,
/// images become their link, and page jumps are dropped. When the novel has
/// more than one page each page starts with a `—— n / total ——` line.
String novelExportText({
  required String title,
  required String author,
  required int novelId,
  String? seriesTitle,
  required List<NovelSpansData> spans,
}) {
  final pages = splitNovelSpanPages(spans);
  final out = StringBuffer()..writeln(title.trim());
  if (seriesTitle != null && seriesTitle.trim().isNotEmpty) {
    out.writeln(seriesTitle.trim());
  }
  out
    ..writeln(author.trim())
    ..writeln('https://www.pixiv.net/novel/show.php?id=$novelId');
  for (var i = 0; i < pages.length; i++) {
    out.write('\n\n');
    if (pages.length > 1) out.write('—— ${i + 1} / ${pages.length} ——\n\n');
    out.write(_pageText(pages[i]));
  }
  out.writeln();
  return out.toString();
}

String _pageText(List<NovelSpansData> spans) {
  final page = StringBuffer();
  // Chapter titles and image links sit on lines of their own. The line break
  // after one is written lazily, so text that already starts with a newline
  // does not leave an extra blank line.
  var lineOpen = false;
  var atLineStart = true;
  void write(String text) {
    if (text.isEmpty) return;
    if (lineOpen && !text.startsWith('\n')) page.write('\n');
    lineOpen = false;
    page.write(text);
    atLineStart = text.endsWith('\n');
  }

  void ownLine(String line) {
    if (lineOpen || !atLineStart) page.write('\n');
    page.write(line);
    lineOpen = true;
    atLineStart = false;
  }

  for (final span in spans) {
    switch (span.type) {
      case NovelSpansType.normal:
      case NovelSpansType.jumpUri:
        write(span.text);
      case NovelSpansType.rb:
        final ruby = parseNovelRubyPayload(span.text);
        write(ruby.ruby.isEmpty ? ruby.base : '${ruby.base}（${ruby.ruby}）');
      case NovelSpansType.chapter:
        ownLine('【${span.text.trim()}】');
      case NovelSpansType.pixivImage:
        final id = (span as PixivImageSpanData).illustId;
        if (id > 0) ownLine('https://www.pixiv.net/artworks/$id');
      case NovelSpansType.uploadedImage:
        ownLine(span.text);
      case NovelSpansType.jump:
      case NovelSpansType.newPage:
        break;
    }
  }
  return page.toString().trim();
}
