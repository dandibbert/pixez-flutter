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
  final NovelSpansData span;

  const NovelReaderBlock(this.span);

  NovelSpansType get type => span.type;

  String get text => span.text;
}

const int novelReaderBlockMaxChars = 1200;

List<NovelReaderBlock> splitNovelReaderBlocks(List<NovelSpansData> spans) {
  final blocks = <NovelReaderBlock>[];
  var pendingEmpty = false;

  void addBlock(NovelSpansData span) {
    if (span.type == NovelSpansType.normal && span.text.isEmpty) {
      pendingEmpty = blocks.isNotEmpty;
      return;
    }
    if (pendingEmpty) {
      blocks.add(NovelReaderBlock(NovelSpansData(NovelSpansType.normal, '')));
      pendingEmpty = false;
    }
    blocks.add(NovelReaderBlock(span));
  }

  for (final span in spans) {
    if (span.type == NovelSpansType.newPage) {
      continue;
    }
    if (span.type == NovelSpansType.normal) {
      for (final part in _splitNormalText(span.text)) {
        addBlock(NovelSpansData(NovelSpansType.normal, part));
      }
    } else {
      addBlock(span);
    }
  }

  if (blocks.isEmpty) {
    return [
      NovelReaderBlock(NovelSpansData(NovelSpansType.normal, '')),
    ];
  }
  return blocks;
}

Iterable<String> _splitNormalText(String text) sync* {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final line in normalized.split('\n')) {
    if (line.length <= novelReaderBlockMaxChars) {
      yield line;
      continue;
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
