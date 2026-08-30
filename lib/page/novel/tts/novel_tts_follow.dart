import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_splitter.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';

class NovelTtsTextRange {
  const NovelTtsTextRange(this.start, this.end);

  final int start;
  final int end;

  bool get isEmpty => start >= end;
}

/// Highlight window inside one reader span's displayed characters.
class NovelTtsSpanHighlight {
  const NovelTtsSpanHighlight({
    required this.blockIndex,
    required this.spanIndex,
    required this.start,
    required this.end,
  });

  final int blockIndex;
  final int spanIndex;
  final int start;
  final int end;
}

/// Aligns packed TTS chunks back onto [pageText], skipping whitespace the
/// splitter trimmed when it joined sentences.
List<NovelTtsTextRange> novelTtsAlignChunks(
  String pageText,
  List<String> chunks,
) {
  final ranges = <NovelTtsTextRange>[];
  var pos = 0;
  for (final chunk in chunks) {
    if (chunk.isEmpty) {
      ranges.add(NovelTtsTextRange(pos, pos));
      continue;
    }
    while (pos < pageText.length && _isSpeakableSpace(pageText[pos])) {
      pos++;
    }
    final start = pos;
    var ci = 0;
    while (ci < chunk.length && pos < pageText.length) {
      if (pageText[pos] == chunk[ci]) {
        pos++;
        ci++;
        continue;
      }
      if (_isSpeakableSpace(pageText[pos])) {
        pos++;
        continue;
      }
      break;
    }
    if (ci == chunk.length) {
      ranges.add(NovelTtsTextRange(start, pos));
      continue;
    }
    final at = pageText.indexOf(chunk, start);
    if (at >= 0) {
      ranges.add(NovelTtsTextRange(at, at + chunk.length));
      pos = at + chunk.length;
      continue;
    }
    final head = chunk.length > 24 ? chunk.substring(0, 24) : chunk;
    final headAt = pageText.indexOf(head, start);
    if (headAt >= 0) {
      ranges.add(NovelTtsTextRange(headAt, headAt + head.length));
      pos = headAt + head.length;
      continue;
    }
    ranges.add(NovelTtsTextRange(start, start));
  }
  return ranges;
}

/// Spoken-character range of [chunkIndex] on the current page.
NovelTtsTextRange? novelTtsClipSpeakableRange({
  required String pageText,
  required List<String> chunks,
  required int chunkIndex,
}) {
  if (chunks.isEmpty) {
    return null;
  }
  final ranges = novelTtsAlignChunks(pageText, chunks);
  final index = chunkIndex.clamp(0, ranges.length - 1);
  final range = ranges[index];
  return range.isEmpty ? null : range;
}

List<NovelTtsSpanHighlight> _highlightsForPageRange(
  NovelTtsSpeakableLayout layout,
  NovelTtsTextRange range,
) {
  if (range.isEmpty) {
    return const [];
  }
  final rawStart = layout.toRawOffset(range.start);
  final rawEnd = layout.toRawOffset(range.end);
  final highlights = <NovelTtsSpanHighlight>[];
  for (final run in layout.runs) {
    final start = rawStart > run.rawStart ? rawStart : run.rawStart;
    final end = rawEnd < run.rawEnd ? rawEnd : run.rawEnd;
    if (start >= end) {
      continue;
    }
    highlights.add(
      NovelTtsSpanHighlight(
        blockIndex: run.blockIndex,
        spanIndex: run.spanIndex,
        start: run.displayStart + (start - run.rawStart),
        end: run.displayStart + (end - run.rawStart),
      ),
    );
  }
  return highlights;
}

/// Per-span display ranges that overlap the current TTS clip.
List<NovelTtsSpanHighlight> novelTtsHighlightsForClip({
  required List<NovelReaderBlock> blocks,
  required int chunkIndex,
  required int splitChars,
}) {
  if (blocks.isEmpty) {
    return const [];
  }
  final layout = novelTtsSpeakableLayout(blocks);
  if (layout.pageText.isEmpty) {
    return const [];
  }
  final chunks = splitNovelTtsText(layout.pageText, maxChars: splitChars);
  final range = novelTtsClipSpeakableRange(
    pageText: layout.pageText,
    chunks: chunks,
    chunkIndex: chunkIndex,
  );
  if (range == null) {
    return const [];
  }
  return _highlightsForPageRange(layout, range);
}

/// Aligns [clipText] onto reader blocks even when the viewer dropped newlines
/// that the synthesizer still has in [clipText].
List<NovelTtsSpanHighlight> novelTtsHighlightsForSpokenText({
  required List<NovelReaderBlock> blocks,
  required String clipText,
}) {
  if (blocks.isEmpty) {
    return const [];
  }
  final layout = novelTtsSpeakableLayout(blocks);
  final range = novelTtsAlignFlexible(layout.pageText, clipText);
  if (range == null) {
    return const [];
  }
  return _highlightsForPageRange(layout, range);
}

/// Finds [needle] in [pageText] while ignoring whitespace / newline mismatches.
NovelTtsTextRange? novelTtsAlignFlexible(String pageText, String needle) {
  final compact = _stripSpeakableSpace(needle);
  if (compact.isEmpty || pageText.isEmpty) {
    return null;
  }
  var n = 0;
  var start = -1;
  for (var i = 0; i < pageText.length; i++) {
    if (_isSpeakableSpace(pageText[i])) {
      continue;
    }
    if (pageText[i] == compact[n]) {
      if (n == 0) {
        start = i;
      }
      n++;
      if (n == compact.length) {
        return NovelTtsTextRange(start, i + 1);
      }
      continue;
    }
    n = 0;
    start = -1;
    if (pageText[i] == compact[0]) {
      start = i;
      n = 1;
      if (n == compact.length) {
        return NovelTtsTextRange(start, i + 1);
      }
    }
  }
  return null;
}

String _stripSpeakableSpace(String text) {
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (!_isSpeakableSpace(text[i])) {
      buffer.write(text[i]);
    }
  }
  return buffer.toString();
}

bool novelTtsTextCoversNeedle(String clipText, String needle) {
  final compactClip = _stripSpeakableSpace(clipText);
  final compactNeedle = _stripSpeakableSpace(needle);
  if (compactClip.isEmpty || compactNeedle.isEmpty) {
    return false;
  }
  return compactClip.contains(compactNeedle) ||
      compactNeedle.contains(compactClip);
}

int novelTtsIndexOfNeedle(Iterable<String> clipTexts, String needle) {
  final compactNeedle = _stripSpeakableSpace(needle);
  if (compactNeedle.isEmpty) {
    return -1;
  }
  var index = 0;
  for (final clipText in clipTexts) {
    if (novelTtsTextCoversNeedle(clipText, needle)) {
      return index;
    }
    index++;
  }
  return -1;
}

String novelTtsNeedleForBlock(List<NovelReaderBlock> blocks, int blockIndex) {
  if (blockIndex < 0 || blockIndex >= blocks.length) {
    return '';
  }
  for (var i = blockIndex; i < blocks.length; i++) {
    final text = novelTtsTextFromBlocks([blocks[i]]).trim();
    if (text.isNotEmpty) {
      return text.length > 80 ? text.substring(0, 80) : text;
    }
  }
  return '';
}

NovelTtsSpanHighlight? novelTtsHighlightForSpan({
  required List<NovelTtsSpanHighlight> highlights,
  required int blockIndex,
  required int spanIndex,
}) {
  NovelTtsSpanHighlight? merged;
  for (final highlight in highlights) {
    if (highlight.blockIndex != blockIndex || highlight.spanIndex != spanIndex) {
      continue;
    }
    if (merged == null) {
      merged = highlight;
      continue;
    }
    merged = NovelTtsSpanHighlight(
      blockIndex: blockIndex,
      spanIndex: spanIndex,
      start: highlight.start < merged.start ? highlight.start : merged.start,
      end: highlight.end > merged.end ? highlight.end : merged.end,
    );
  }
  return merged;
}

/// Finds the reader block that contains the start of the current TTS clip.
int novelTtsBlockIndexForClip({
  required List<NovelReaderBlock> blocks,
  required String clipText,
}) {
  if (blocks.isEmpty) {
    return 0;
  }
  final layout = novelTtsSpeakableLayout(blocks);
  final needle = clipText.trim();
  if (needle.isEmpty || layout.pageText.isEmpty) {
    return 0;
  }
  var start = layout.pageText.indexOf(needle);
  if (start < 0) {
    final head = needle.length > 24 ? needle.substring(0, 24) : needle;
    start = layout.pageText.indexOf(head);
  }
  if (start < 0) {
    return 0;
  }
  final rawStart = layout.toRawOffset(start);
  for (final run in layout.runs) {
    if (rawStart < run.rawEnd) {
      return run.blockIndex;
    }
  }
  return layout.runs.isEmpty ? 0 : layout.runs.last.blockIndex;
}

/// First block whose bottom edge sits below the article viewport top.
int novelTtsFirstVisibleBlockIndex({
  required List<GlobalKey> keys,
  required double viewportTop,
}) {
  var fallback = 0;
  for (var i = 0; i < keys.length; i++) {
    final box = keys[i].currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      continue;
    }
    fallback = i;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top + box.size.height > viewportTop + 12) {
      return i;
    }
  }
  return fallback;
}

/// Chunk index on the current page that covers [blockIndex].
int novelTtsChunkIndexForBlock({
  required List<NovelReaderBlock> blocks,
  required int blockIndex,
  required int splitChars,
}) {
  if (blocks.isEmpty) {
    return 0;
  }
  final layout = novelTtsSpeakableLayout(blocks);
  final chunks = splitNovelTtsText(layout.pageText, maxChars: splitChars);
  if (chunks.isEmpty) {
    return 0;
  }
  final ranges = novelTtsAlignChunks(layout.pageText, chunks);
  NovelTtsSpeakableRun? run;
  for (final item in layout.runs) {
    if (item.blockIndex >= blockIndex) {
      run = item;
      break;
    }
  }
  run ??= layout.runs.isEmpty ? null : layout.runs.last;
  if (run == null) {
    return 0;
  }
  final pageStart = layout.toPageOffset(run.rawStart);
  for (var i = 0; i < ranges.length; i++) {
    if (ranges[i].end > pageStart) {
      return i;
    }
  }
  return ranges.length - 1;
}

/// Inverse of [novelTtsChunkIndexForBlock].
int novelTtsBlockIndexForChunk({
  required List<NovelReaderBlock> blocks,
  required int chunkIndex,
  required int splitChars,
}) {
  final highlights = novelTtsHighlightsForClip(
    blocks: blocks,
    chunkIndex: chunkIndex,
    splitChars: splitChars,
  );
  if (highlights.isNotEmpty) {
    return highlights.first.blockIndex;
  }
  if (blocks.isEmpty) {
    return 0;
  }
  return 0;
}

int novelTtsBlockIndexForSpokenText({
  required List<NovelReaderBlock> blocks,
  required String clipText,
}) {
  final highlights = novelTtsHighlightsForSpokenText(
    blocks: blocks,
    clipText: clipText,
  );
  if (highlights.isNotEmpty) {
    return highlights.first.blockIndex;
  }
  return novelTtsBlockIndexForClip(blocks: blocks, clipText: clipText);
}

bool _isSpeakableSpace(String char) {
  return char == ' ' ||
      char == '\n' ||
      char == '\r' ||
      char == '\t' ||
      char == '　';
}
