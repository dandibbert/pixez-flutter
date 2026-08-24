import 'package:pixez/models/illust_persist.dart';
import 'package:pixez/page/search/illust_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';

/// 从作品浏览历史恢复其来源搜索；旧记录没有来源信息时返回 null。
IllustSearchQuery? restoreIllustHistoryOrigin(IllustPersist history) {
  final query = IllustSearchQuery.tryDecode(history.sourceQueryJson);
  if (query == null) return null;
  return query.copyWith(
    page: history.sourcePage ?? query.normalizedPage,
    mode: SearchResultMode.paged,
  );
}
