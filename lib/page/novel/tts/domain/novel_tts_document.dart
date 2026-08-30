import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

class NovelTtsPageDocument {
  const NovelTtsPageDocument({
    required this.pageNumber,
    required this.displayText,
    required this.ruby,
  });
  final int pageNumber;
  final String displayText;
  final List<PronunciationRuby> ruby;
}

class NovelTtsDocument {
  const NovelTtsDocument({required this.novelId, required this.pages});
  final String novelId;
  final List<NovelTtsPageDocument> pages;

  factory NovelTtsDocument.fromSpans(
    String novelId,
    List<NovelSpansData> spans,
  ) {
    final pages = <NovelTtsPageDocument>[];
    var buffer = StringBuffer();
    var ruby = <PronunciationRuby>[];
    void flush() {
      pages.add(
        NovelTtsPageDocument(
          pageNumber: pages.length + 1,
          displayText: buffer.toString(),
          ruby: List.unmodifiable(ruby),
        ),
      );
      buffer = StringBuffer();
      ruby = <PronunciationRuby>[];
    }

    for (final span in spans) {
      switch (span.type) {
        case NovelSpansType.newPage:
          flush();
        case NovelSpansType.normal:
        case NovelSpansType.chapter:
          buffer.write(span.text);
        case NovelSpansType.rb:
          final parts = parseNovelRubyPayload(span.text);
          final start = buffer.length;
          buffer.write(parts.base);
          if (parts.ruby.isNotEmpty) {
            ruby.add(
              PronunciationRuby(
                start: start,
                end: buffer.length,
                reading: parts.ruby,
              ),
            );
          }
        case NovelSpansType.pixivImage:
        case NovelSpansType.uploadedImage:
        case NovelSpansType.jumpUri:
        case NovelSpansType.jump:
          break;
      }
    }
    if (buffer.isNotEmpty || pages.isEmpty) flush();
    return NovelTtsDocument(novelId: novelId, pages: List.unmodifiable(pages));
  }
}
