import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_splitter.dart';
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
  final index = blockIndex.clamp(0, blocks.length - 1);
  final pageText = novelTtsTextFromBlocks(blocks);
  final chunks = splitNovelTtsText(pageText, maxChars: splitChars);
  if (chunks.isEmpty) {
    return 0;
  }
  final prefix = novelTtsTextFromBlocks(blocks.take(index));
  var consumed = 0;
  for (var i = 0; i < chunks.length; i++) {
    consumed += chunks[i].length;
    if (consumed > prefix.length) {
      return i;
    }
  }
  return chunks.length - 1;
}

/// Inverse of [novelTtsChunkIndexForBlock].
int novelTtsBlockIndexForChunk({
  required List<NovelReaderBlock> blocks,
  required int chunkIndex,
  required int splitChars,
}) {
  if (blocks.isEmpty) {
    return 0;
  }
  final pageText = novelTtsTextFromBlocks(blocks);
  final chunks = splitNovelTtsText(pageText, maxChars: splitChars);
  if (chunks.isEmpty) {
    return 0;
  }
  final index = chunkIndex.clamp(0, chunks.length - 1);
  var prefix = 0;
  for (var i = 0; i < index; i++) {
    prefix += chunks[i].length;
  }
  var consumed = 0;
  var lastSpoken = 0;
  for (var i = 0; i < blocks.length; i++) {
    final piece = novelTtsTextFromSpans(blocks[i].spans);
    if (piece.isEmpty) {
      continue;
    }
    lastSpoken = i;
    consumed += piece.length;
    if (consumed > prefix) {
      return i;
    }
  }
  return lastSpoken;
}
