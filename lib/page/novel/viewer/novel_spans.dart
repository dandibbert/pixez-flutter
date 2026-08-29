import 'package:pixez/models/novel_web_response.dart';

enum NovelSpansType {
  normal,
  newPage,
  pixivImage,
  uploadedImage,
  jumpUri,
  rb,
  chapter,
  jump,
}

class NovelSpansData {
  final NovelSpansType type;
  final String text;

  NovelSpansData(this.type, this.text);
}

class PixivImageSpanData extends NovelSpansData {
  final int illustId;
  final int targetIndex;
  final NovelIllusts illust;

  PixivImageSpanData(this.illustId, this.targetIndex, String text, this.illust)
    : super(NovelSpansType.pixivImage, text);
}

/// A raw run of the novel body. [delimited] marks the runs that were closed by
/// `]`; only those are interpreted as pixiv markup. An unterminated run such as
/// `[chapter:x` stays plain text even though it looks like a tag.
class NovelTextToken {
  final String text;
  final bool delimited;

  const NovelTextToken(this.text, {required this.delimited});
}

/// Splits a novel body into plain runs and bracket tokens in a single pass.
///
/// The pending run is tracked as an index into [source] and only materialised
/// when a token is emitted. Accumulating it character by character instead
/// costs O(n^2) time and memory traffic, which on a long chapter is seconds of
/// CPU and gigabytes of copying every time the reader opens it.
List<NovelTextToken> tokenizeNovelText(String source) {
  final tokens = <NovelTextToken>[];
  var pending = 0;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (char == '[') {
      final length = i - pending;
      // `[` right after `[` keeps building a `[[...]]` tag; anything else that
      // is already pending is flushed as plain text so the tag starts clean.
      final pendingIsOpenBracket = length == 1 && source[pending] == '[';
      if (length != 0 && !pendingIsOpenBracket) {
        tokens.add(
          NovelTextToken(source.substring(pending, i), delimited: false),
        );
        pending = i;
      }
    } else if (char == ']') {
      final length = i - pending;
      final isDoubleBracket =
          length >= 2 && source[pending] == '[' && source[pending + 1] == '[';
      final endsWithBracket = length >= 1 && source[i - 1] == ']';
      // A `[[...]]` tag needs both closing brackets; everything else closes on
      // the first one.
      if (!isDoubleBracket || endsWithBracket) {
        tokens.add(
          NovelTextToken(source.substring(pending, i + 1), delimited: true),
        );
        pending = i + 1;
      }
    }
  }
  if (pending < source.length) {
    tokens.add(NovelTextToken(source.substring(pending), delimited: false));
  }
  return tokens;
}
