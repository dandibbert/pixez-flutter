import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

enum NovelReaderNavKind { page, series, none }

class NovelReaderNavAction {
  final NovelReaderNavKind kind;
  final int? seriesNovelId;

  const NovelReaderNavAction.page()
    : kind = NovelReaderNavKind.page,
      seriesNovelId = null;

  const NovelReaderNavAction.series(this.seriesNovelId)
    : kind = NovelReaderNavKind.series;

  const NovelReaderNavAction.none()
    : kind = NovelReaderNavKind.none,
      seriesNovelId = null;
}

class NovelPageNavState {
  final bool isOnFirstPage;
  final bool isOnLastPage;
  final bool canJumpPrevSeries;
  final bool canJumpNextSeries;
  final bool isPrevDisabled;
  final bool isNextDisabled;

  const NovelPageNavState({
    required this.isOnFirstPage,
    required this.isOnLastPage,
    required this.canJumpPrevSeries,
    required this.canJumpNextSeries,
    required this.isPrevDisabled,
    required this.isNextDisabled,
  });
}

bool _isBlankSpan(NovelSpansData span) {
  return span.type == NovelSpansType.normal && span.text.trim().isEmpty;
}

List<List<NovelSpansData>> splitNovelSpanPages(List<NovelSpansData> spans) {
  final pages = <List<NovelSpansData>>[];
  var current = <NovelSpansData>[];

  void flushPage() {
    final meaningful = current.where((span) => !_isBlankSpan(span)).toList();
    if (meaningful.isNotEmpty) {
      pages.add(List<NovelSpansData>.from(current));
    }
    current = <NovelSpansData>[];
  }

  for (final span in spans) {
    if (span.type == NovelSpansType.newPage) {
      flushPage();
    } else {
      current.add(span);
    }
  }
  flushPage();

  if (pages.isEmpty) {
    return [<NovelSpansData>[]];
  }
  return pages;
}

class NovelReaderBlock {
  final List<NovelSpansData> spans;

  NovelReaderBlock(NovelSpansData span) : spans = [span];

  NovelReaderBlock.spans(List<NovelSpansData> spans)
    : spans = List<NovelSpansData>.unmodifiable(spans);

  NovelSpansData get span => spans.first;

  NovelSpansType get type =>
      spans.length == 1 ? spans.first.type : NovelSpansType.normal;

  String get text => spans.map((span) => span.text).join();

  bool get isBlank =>
      spans.length == 1 &&
      spans.first.type == NovelSpansType.normal &&
      spans.first.text.isEmpty;
}

/// Remembers the last page and block split for a chapter.
///
/// Both splits walk every span in the chapter, and the reader asks for them
/// several times per interaction (page navigation, key handling, and once per
/// rebuild, including every frame of a font-size drag). Recomputing each time
/// burns CPU for a result that only changes when the chapter or page does.
class NovelReaderSplitCache {
  List<NovelSpansData>? _source;
  List<List<NovelSpansData>>? _pages;
  int _blocksPage = -1;
  List<NovelReaderBlock>? _blocks;

  List<List<NovelSpansData>> pages(List<NovelSpansData> spans) {
    if (_pages == null || !identical(spans, _source)) {
      _source = spans;
      _pages = splitNovelSpanPages(spans);
      _blocksPage = -1;
      _blocks = null;
    }
    return _pages!;
  }

  List<NovelReaderBlock> blocks(List<NovelSpansData> pageSpans, int pageIndex) {
    if (_blocks == null || _blocksPage != pageIndex) {
      _blocks = splitNovelReaderBlocks(pageSpans);
      _blocksPage = pageIndex;
    }
    return _blocks!;
  }
}

bool isNovelInlineSpan(NovelSpansType type) {
  switch (type) {
    case NovelSpansType.normal:
    case NovelSpansType.rb:
    case NovelSpansType.jump:
    case NovelSpansType.jumpUri:
      return true;
    case NovelSpansType.newPage:
    case NovelSpansType.pixivImage:
    case NovelSpansType.uploadedImage:
    case NovelSpansType.chapter:
      return false;
  }
}

const int novelReaderBlockMaxChars = 1200;

List<NovelReaderBlock> splitNovelReaderBlocks(List<NovelSpansData> spans) {
  final blocks = <NovelReaderBlock>[];
  var pending = <NovelSpansData>[];
  var pendingChars = 0;
  var pendingEmpty = false;

  void emitBlank() {
    blocks.add(NovelReaderBlock(NovelSpansData(NovelSpansType.normal, '')));
  }

  void flushParagraph() {
    if (pending.isEmpty) {
      return;
    }
    if (pendingEmpty) {
      emitBlank();
      pendingEmpty = false;
    }
    blocks.add(NovelReaderBlock.spans(pending));
    pending = <NovelSpansData>[];
    pendingChars = 0;
  }

  void addInline(NovelSpansData span) {
    if (pending.isNotEmpty &&
        pendingChars + span.text.length > novelReaderBlockMaxChars) {
      flushParagraph();
    }
    pending.add(span);
    pendingChars += span.text.length;
  }

  for (final span in spans) {
    if (span.type == NovelSpansType.newPage) {
      continue;
    }
    if (!isNovelInlineSpan(span.type)) {
      flushParagraph();
      if (pendingEmpty) {
        emitBlank();
        pendingEmpty = false;
      }
      blocks.add(NovelReaderBlock(span));
      continue;
    }
    if (span.type != NovelSpansType.normal) {
      addInline(span);
      continue;
    }
    final lines = _splitLines(span.text);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isNotEmpty) {
        for (final part in _chunkLine(line)) {
          addInline(NovelSpansData(NovelSpansType.normal, part));
        }
      }
      if (i < lines.length - 1) {
        flushParagraph();
        if (line.isEmpty) {
          pendingEmpty = blocks.isNotEmpty;
        }
      }
    }
  }

  flushParagraph();
  if (pendingEmpty && blocks.isNotEmpty) {
    emitBlank();
  }

  if (blocks.isEmpty) {
    return [
      NovelReaderBlock(NovelSpansData(NovelSpansType.normal, '')),
    ];
  }
  return blocks;
}

List<String> _splitLines(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.split('\n');
}

Iterable<String> _chunkLine(String line) sync* {
  if (line.length <= novelReaderBlockMaxChars) {
    yield line;
    return;
  }
  var start = 0;
  while (start < line.length) {
    var end = start + novelReaderBlockMaxChars;
    if (end >= line.length) {
      yield line.substring(start);
      break;
    }
    final window = line.substring(start, end);
    final breakAt = _lastTextBreak(window);
    if (breakAt > novelReaderBlockMaxChars ~/ 4) {
      end = start + breakAt;
    }
    yield line.substring(start, end);
    start = end;
  }
}

int _lastTextBreak(String window) {
  const marks = <String>['。', '！', '？', '」', '』', '、', '.', '!', '?', ' '];
  var best = -1;
  for (final mark in marks) {
    final index = window.lastIndexOf(mark);
    if (index > best) {
      best = index + mark.length;
    }
  }
  return best;
}

int restoreNovelPage({required double bookedOffset, required int totalPages}) {
  if (totalPages <= 0) {
    return 1;
  }
  final page = bookedOffset.round();
  if (page >= 1 && page <= totalPages) {
    return page;
  }
  return 1;
}

int clampNovelPage(int page, int totalPages) {
  if (totalPages <= 0) {
    return 1;
  }
  if (page < 1) {
    return 1;
  }
  if (page > totalPages) {
    return totalPages;
  }
  return page;
}

NovelPageNavState resolveNovelPageNavState({
  required int currentPage,
  required int totalPages,
  required bool hasPrevSeries,
  required bool hasNextSeries,
}) {
  final isOnFirstPage = currentPage <= 1;
  final isOnLastPage = totalPages <= 0 || currentPage >= totalPages;
  final canJumpPrevSeries = isOnFirstPage && hasPrevSeries;
  final canJumpNextSeries = isOnLastPage && hasNextSeries;
  return NovelPageNavState(
    isOnFirstPage: isOnFirstPage,
    isOnLastPage: isOnLastPage,
    canJumpPrevSeries: canJumpPrevSeries,
    canJumpNextSeries: canJumpNextSeries,
    isPrevDisabled: isOnFirstPage && !hasPrevSeries,
    isNextDisabled: isOnLastPage && !hasNextSeries,
  );
}

NovelReaderNavAction resolveNovelReaderNavigation({
  required String direction,
  required int currentPage,
  required int totalPages,
  PrevNovel? prevNovel,
  PrevNovel? nextNovel,
}) {
  final hasPrevSeries = prevNovel != null && prevNovel.viewable;
  final hasNextSeries = nextNovel != null && nextNovel.viewable;

  if (direction == 'prev') {
    if (currentPage <= 1) {
      if (hasPrevSeries) {
        return NovelReaderNavAction.series(prevNovel.id);
      }
      return const NovelReaderNavAction.none();
    }
    return const NovelReaderNavAction.page();
  }

  final isOnLastPage = totalPages <= 0 || currentPage >= totalPages;
  if (isOnLastPage) {
    if (hasNextSeries) {
      return NovelReaderNavAction.series(nextNovel.id);
    }
    return const NovelReaderNavAction.none();
  }
  return const NovelReaderNavAction.page();
}
