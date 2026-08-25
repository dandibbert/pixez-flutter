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
