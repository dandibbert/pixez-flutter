import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

/// Turns a reader page into spoken text. Images and page breaks are skipped;
/// ruby keeps the base characters so the voice does not read furigana twice.
String novelTtsTextFromSpans(Iterable<NovelSpansData> spans) {
  final buffer = StringBuffer();
  for (final span in spans) {
    final piece = _speakableSpan(span);
    if (piece.isEmpty) {
      continue;
    }
    if (buffer.isNotEmpty && !_startsWithBreak(piece) && !_endsWithBreak(buffer)) {
      if (span.type == NovelSpansType.chapter) {
        buffer.write('\n');
      }
    }
    buffer.write(piece);
  }
  return buffer.toString().trim();
}

String novelTtsTextFromPages(List<List<NovelSpansData>> pages, int pageIndex) {
  if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) {
    return '';
  }
  return novelTtsTextFromSpans(pages[pageIndex]);
}

String _speakableSpan(NovelSpansData span) {
  switch (span.type) {
    case NovelSpansType.normal:
      return span.text;
    case NovelSpansType.chapter:
      return span.text.trim().isEmpty ? '' : '${span.text.trim()}\n';
    case NovelSpansType.rb:
      return parseNovelRubyPayload(span.text).base;
    case NovelSpansType.jump:
    case NovelSpansType.jumpUri:
      return '';
    case NovelSpansType.newPage:
    case NovelSpansType.pixivImage:
    case NovelSpansType.uploadedImage:
      return '';
  }
}

bool _startsWithBreak(String text) =>
    text.startsWith('\n') || text.startsWith('\r');

bool _endsWithBreak(StringBuffer buffer) {
  if (buffer.isEmpty) {
    return true;
  }
  final value = buffer.toString();
  return value.endsWith('\n') || value.endsWith('\r');
}

String novelTtsTextFromBlocks(Iterable<NovelReaderBlock> blocks) {
  return novelTtsTextFromSpans(blocks.expand((block) => block.spans));
}
