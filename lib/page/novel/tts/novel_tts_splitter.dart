/// Packs novel text into speakable chunks near [maxChars] without chopping
/// through a sentence when a nearby ending is available.
List<String> splitNovelTtsText(String source, {required int maxChars}) {
  final limit = maxChars < 20 ? 20 : maxChars;
  final text = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) {
    return const [];
  }

  final sentences = _splitSentences(text);
  final chunks = <String>[];
  final pending = StringBuffer();

  void flush() {
    final value = pending.toString().trim();
    pending.clear();
    if (value.isNotEmpty) {
      chunks.add(value);
    }
  }

  for (final sentence in sentences) {
    final piece = sentence.trim();
    if (piece.isEmpty) {
      continue;
    }
    if (pending.isEmpty) {
      if (piece.length <= limit) {
        pending.write(piece);
      } else {
        for (final part in _splitLongSentence(piece, limit)) {
          chunks.add(part);
        }
      }
      continue;
    }

    final merged = '${pending.toString().trimRight()}$piece';
    if (merged.length <= limit) {
      pending
        ..clear()
        ..write(merged);
      continue;
    }

    // A leftover shorter than 20% of the budget is less natural as its own
    // clip than slightly overflowing the current one.
    final overflow = merged.length - limit;
    if (overflow <= (limit * 0.2).round() && overflow <= 24) {
      pending
        ..clear()
        ..write(merged);
      continue;
    }
    flush();
    if (piece.length <= limit) {
      pending.write(piece);
    } else {
      for (final part in _splitLongSentence(piece, limit)) {
        chunks.add(part);
      }
    }
  }
  flush();
  return chunks;
}

List<String> _splitSentences(String text) {
  final sentences = <String>[];
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    buffer.write(char);
    if (!_isSentenceEnder(char)) {
      if (char == '\n') {
        final nextIsBreak = i + 1 < text.length && text[i + 1] == '\n';
        if (nextIsBreak || _looksLikeParagraphEnd(buffer.toString())) {
          while (i + 1 < text.length && text[i + 1] == '\n') {
            i++;
            buffer.write('\n');
          }
          sentences.add(buffer.toString());
          buffer.clear();
        }
      }
      continue;
    }
    var end = i;
    while (end + 1 < text.length && _isCloser(text[end + 1])) {
      end++;
      buffer.write(text[end]);
    }
    i = end;
    sentences.add(buffer.toString());
    buffer.clear();
  }
  if (buffer.isNotEmpty) {
    sentences.add(buffer.toString());
  }
  return sentences;
}

Iterable<String> _splitLongSentence(String sentence, int limit) sync* {
  var start = 0;
  while (start < sentence.length) {
    if (sentence.length - start <= limit) {
      final rest = sentence.substring(start).trim();
      if (rest.isNotEmpty) {
        yield rest;
      }
      return;
    }
    var end = start + limit;
    final window = sentence.substring(start, end);
    final breakAt = _lastSoftBreak(window);
    if (breakAt > limit ~/ 4) {
      end = start + breakAt;
    }
    final part = sentence.substring(start, end).trim();
    if (part.isNotEmpty) {
      yield part;
    }
    start = end;
  }
}

int _lastSoftBreak(String window) {
  const marks = <String>['；', ';', '，', ',', '、', '：', ':', '—', '–', ' '];
  var best = -1;
  for (final mark in marks) {
    final index = window.lastIndexOf(mark);
    if (index >= 0 && index + mark.length > best) {
      best = index + mark.length;
    }
  }
  return best;
}

bool _isSentenceEnder(String char) {
  return char == '。' ||
      char == '！' ||
      char == '？' ||
      char == '!' ||
      char == '?' ||
      char == '…' ||
      char == '．';
}

bool _isCloser(String char) {
  return char == '」' ||
      char == '』' ||
      char == '"' ||
      char == '”' ||
      char == '’' ||
      char == ')' ||
      char == '）' ||
      char == ']' ||
      char == '】';
}

bool _looksLikeParagraphEnd(String pending) {
  final trimmed = pending.trimRight();
  return trimmed.endsWith('。') ||
      trimmed.endsWith('！') ||
      trimmed.endsWith('？') ||
      trimmed.endsWith('…');
}
