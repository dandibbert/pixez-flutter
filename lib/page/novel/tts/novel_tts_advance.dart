enum NovelTtsAdvanceKind { chunk, page, series, stop }

class NovelTtsAdvance {
  const NovelTtsAdvance._(this.kind, {this.page, this.seriesNovelId});

  const NovelTtsAdvance.chunk() : this._(NovelTtsAdvanceKind.chunk);

  const NovelTtsAdvance.page(int page)
    : this._(NovelTtsAdvanceKind.page, page: page);

  const NovelTtsAdvance.series(int seriesNovelId)
    : this._(NovelTtsAdvanceKind.series, seriesNovelId: seriesNovelId);

  const NovelTtsAdvance.stop() : this._(NovelTtsAdvanceKind.stop);

  final NovelTtsAdvanceKind kind;
  final int? page;
  final int? seriesNovelId;
}

NovelTtsAdvance resolveNovelTtsAdvance({
  required String direction,
  required int chunkIndex,
  required int chunkCount,
  required int currentPage,
  required int totalPages,
  int? prevSeriesId,
  int? nextSeriesId,
  bool autoContinue = true,
}) {
  final safeChunks = chunkCount < 1 ? 1 : chunkCount;
  final safeIndex = chunkIndex.clamp(0, safeChunks - 1);
  if (direction == 'prev') {
    if (safeIndex > 0) {
      return const NovelTtsAdvance.chunk();
    }
    if (!autoContinue) {
      return const NovelTtsAdvance.stop();
    }
    if (currentPage > 1) {
      return NovelTtsAdvance.page(currentPage - 1);
    }
    if (prevSeriesId != null) {
      return NovelTtsAdvance.series(prevSeriesId);
    }
    return const NovelTtsAdvance.stop();
  }

  if (safeIndex + 1 < safeChunks) {
    return const NovelTtsAdvance.chunk();
  }
  if (!autoContinue) {
    return const NovelTtsAdvance.stop();
  }
  if (currentPage < totalPages) {
    return NovelTtsAdvance.page(currentPage + 1);
  }
  if (nextSeriesId != null) {
    return NovelTtsAdvance.series(nextSeriesId);
  }
  return const NovelTtsAdvance.stop();
}
