import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/search/novel_result_list.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/page/painter/painter_list.dart';
import 'package:pixez/utils/haptic_util.dart';

class NovelResultPage extends StatefulWidget {
  final String word;
  final String? translatedName;
  final NovelSearchQuery? initialQuery;

  const NovelResultPage({
    Key? key,
    required this.word,
    this.translatedName,
    this.initialQuery,
  }) : super(key: key);

  @override
  _NovelResultPageState createState() => _NovelResultPageState();
}

class _NovelResultPageState extends State<NovelResultPage> {
  late NovelSearchQuery _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ??
        NovelSearchQuery(
          word: widget.word,
          translatedName: widget.translatedName ?? '',
          mode: userSetting.searchResultMode,
        );
    _recordQuery(_query);
  }

  void _recordQuery(NovelSearchQuery query) async {
    _query = query;
    try {
      await tagHistoryStore.insert(
        TagsPersist(
          name: query.word,
          translatedName: query.translatedName,
          type: 1,
          lastPage: query.normalizedPage,
          queryJson: query.encode(),
        ),
        historyType: 1,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save novel search history: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_query.word),
          bottom: TabBar(
            onTap: (i) {
              HapticUtil.selectionClick();
            },
            tabs: [
            Tab(
              child: Text('Novel'),
            ),
            Tab(
              child: Text(I18n.of(context).painter),
            ),
          ]),
        ),
        body: TabBarView(
          children: [
            NovelResultList(
              initialQuery: _query,
              restoreQuery: widget.initialQuery != null,
              onQueryChanged: _recordQuery,
            ),
            PainterList(
              futureGet: () => apiClient.getSearchUser(_query.word),
              isNovel: true,
            )
          ],
        ),
      ),
    );
  }
}
