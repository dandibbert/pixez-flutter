import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';

/// Finds the reader block that contains the start of the current TTS clip.
int novelTtsBlockIndexForClip({
  required List<NovelReaderBlock> blocks,
  required String clipText,
}) {
  if (blocks.isEmpty) {
    return 0;
  }
  final needle = clipText.trim();
  if (needle.isEmpty) {
    return 0;
  }
  final pageText = novelTtsTextFromBlocks(blocks);
  var start = pageText.indexOf(needle);
  if (start < 0) {
    final head = needle.length > 24 ? needle.substring(0, 24) : needle;
    start = pageText.indexOf(head);
  }
  if (start < 0) {
    return 0;
  }
  var cursor = 0;
  var lastSpoken = 0;
  for (var i = 0; i < blocks.length; i++) {
    final piece = novelTtsTextFromSpans(blocks[i].spans);
    if (piece.isEmpty) {
      continue;
    }
    lastSpoken = i;
    final at = pageText.indexOf(piece, cursor);
    final begin = at >= 0 ? at : cursor;
    final end = begin + piece.length;
    if (start < end) {
      return i;
    }
    cursor = end;
  }
  return lastSpoken;
}
