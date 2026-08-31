import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

/// Turns a reader page into spoken text. Images and page breaks are skipped;
/// ruby keeps the base characters so the voice does not read furigana twice.
String novelTtsTextFromSpans(Iterable<NovelSpansData> spans) {
  return _speakableRaw(spans).trim();
}

String novelTtsTextFromPages(List<List<NovelSpansData>> pages, int pageIndex) {
  if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) {
    return '';
  }
  return novelTtsTextFromSpans(pages[pageIndex]);
}

String novelTtsTextFromBlocks(Iterable<NovelReaderBlock> blocks) {
  return novelTtsTextFromSpans(blocks.expand((block) => block.spans));
}

NovelTtsTextDocument novelTtsDocumentFromSpans(Iterable<NovelSpansData> spans) {
  final buffer = StringBuffer();
  final rubies = <NovelTtsRubyAnnotation>[];
  for (final span in spans) {
    if (span.type == NovelSpansType.rb) {
      final ruby = parseNovelRubyPayload(span.text);
      if (ruby.base.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty &&
          !_startsWithBreak(ruby.base) &&
          !_endsWithBreak(buffer)) {
        // Ruby is inline; no extra separator.
      }
      final start = buffer.length;
      buffer.write(ruby.base);
      if (ruby.ruby.isNotEmpty) {
        rubies.add(
          NovelTtsRubyAnnotation(
            start: start,
            end: start + ruby.base.length,
            surface: ruby.base,
            reading: ruby.ruby,
          ),
        );
      }
      continue;
    }
    final piece = novelTtsSpeakableSpan(span);
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
  final raw = buffer.toString();
  final display = raw.trim();
  final lead = display.isEmpty ? 0 : raw.indexOf(display);
  final shifted = [
    for (final ruby in rubies)
      if (ruby.start >= lead && ruby.end <= lead + display.length)
        NovelTtsRubyAnnotation(
          start: ruby.start - lead,
          end: ruby.end - lead,
          surface: ruby.surface,
          reading: ruby.reading,
        ),
  ];
  return NovelTtsTextDocument(
    displayText: display,
    rubyAnnotations: shifted,
    sourceHash: sha1.convert(utf8.encode(display)).toString(),
  );
}

NovelTtsTextDocument novelTtsDocumentFromText(String text) {
  final display = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return NovelTtsTextDocument(
    displayText: display,
    sourceHash: sha1.convert(utf8.encode(display)).toString(),
  );
}

NovelTtsTextDocument novelTtsDocumentFromPages(
  List<List<NovelSpansData>> pages,
  int pageIndex,
) {
  if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) {
    return const NovelTtsTextDocument(displayText: '');
  }
  return novelTtsDocumentFromSpans(pages[pageIndex]);
}

/// Spoken characters for one reader span. Empty means the span is skipped.
String novelTtsSpeakableSpan(NovelSpansData span) {
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

/// One spoken run inside a reader span, with offsets in the raw (untrimmed)
/// speakable page and in the characters actually drawn for that span.
class NovelTtsSpeakableRun {
  const NovelTtsSpeakableRun({
    required this.blockIndex,
    required this.spanIndex,
    required this.rawStart,
    required this.rawEnd,
    required this.displayStart,
    required this.displayEnd,
  });

  final int blockIndex;
  final int spanIndex;
  final int rawStart;
  final int rawEnd;
  final int displayStart;
  final int displayEnd;
}

class NovelTtsSpeakableLayout {
  const NovelTtsSpeakableLayout({
    required this.raw,
    required this.pageText,
    required this.lead,
    required this.runs,
  });

  final String raw;
  final String pageText;
  final int lead;
  final List<NovelTtsSpeakableRun> runs;

  int toPageOffset(int rawOffset) {
    return (rawOffset - lead).clamp(0, pageText.length);
  }

  int toRawOffset(int pageOffset) {
    return (pageOffset + lead).clamp(0, raw.length);
  }
}

/// Walks reader blocks the same way [novelTtsTextFromBlocks] concatenates them.
NovelTtsSpeakableLayout novelTtsSpeakableLayout(
  Iterable<NovelReaderBlock> blocks,
) {
  final runs = <NovelTtsSpeakableRun>[];
  final buffer = StringBuffer();
  final list = blocks.toList();
  for (var blockIndex = 0; blockIndex < list.length; blockIndex++) {
    final spans = list[blockIndex].spans;
    for (var spanIndex = 0; spanIndex < spans.length; spanIndex++) {
      final span = spans[spanIndex];
      final piece = novelTtsSpeakableSpan(span);
      if (piece.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty &&
          !_startsWithBreak(piece) &&
          !_endsWithBreak(buffer)) {
        if (span.type == NovelSpansType.chapter) {
          buffer.write('\n');
        }
      }
      final rawStart = buffer.length;
      if (span.type == NovelSpansType.chapter) {
        final trimmed = span.text.trim();
        final displayStart = span.text.indexOf(trimmed);
        buffer.write(piece);
        runs.add(
          NovelTtsSpeakableRun(
            blockIndex: blockIndex,
            spanIndex: spanIndex,
            rawStart: rawStart,
            rawEnd: rawStart + trimmed.length,
            displayStart: displayStart < 0 ? 0 : displayStart,
            displayEnd: (displayStart < 0 ? 0 : displayStart) + trimmed.length,
          ),
        );
      } else if (span.type == NovelSpansType.rb) {
        buffer.write(piece);
        runs.add(
          NovelTtsSpeakableRun(
            blockIndex: blockIndex,
            spanIndex: spanIndex,
            rawStart: rawStart,
            rawEnd: rawStart + piece.length,
            displayStart: 0,
            displayEnd: piece.length,
          ),
        );
      } else {
        buffer.write(piece);
        runs.add(
          NovelTtsSpeakableRun(
            blockIndex: blockIndex,
            spanIndex: spanIndex,
            rawStart: rawStart,
            rawEnd: rawStart + piece.length,
            displayStart: 0,
            displayEnd: span.text.length,
          ),
        );
      }
    }
  }
  final raw = buffer.toString();
  final pageText = raw.trim();
  final lead = pageText.isEmpty ? 0 : raw.indexOf(pageText);
  return NovelTtsSpeakableLayout(
    raw: raw,
    pageText: pageText,
    lead: lead < 0 ? 0 : lead,
    runs: runs,
  );
}

String _speakableRaw(Iterable<NovelSpansData> spans) {
  final buffer = StringBuffer();
  for (final span in spans) {
    final piece = novelTtsSpeakableSpan(span);
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
  return buffer.toString();
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
