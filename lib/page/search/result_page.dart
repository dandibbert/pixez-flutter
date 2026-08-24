/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/page/search/illust_search_query.dart';
import 'package:pixez/page/search/result/painter/search_result_painter_page.dart';
import 'package:pixez/page/search/result_illust_list.dart';
import 'package:pixez/utils/haptic_util.dart';

class ResultPage extends StatefulWidget {
  final String word;
  final String translatedName;
  final IllustSearchQuery? initialQuery;

  const ResultPage({
    Key? key,
    required this.word,
    this.translatedName = '',
    this.initialQuery,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late IllustSearchQuery _query;

  @override
  void initState() {
    super.initState();
    _query =
        widget.initialQuery ??
        IllustSearchQuery(
          word: widget.word,
          translatedName: widget.translatedName,
          mode: userSetting.searchResultMode,
        );
    _recordQuery(_query);
  }

  void _recordQuery(IllustSearchQuery query) async {
    _query = query;
    try {
      await tagHistoryStore.insert(
        TagsPersist(
          name: query.word,
          translatedName: query.translatedName,
          type: 0,
          lastPage: query.normalizedPage,
          queryJson: query.encode(),
        ),
        historyType: 0,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save search history: $error\n$stackTrace');
    }
  }

  int index = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              onTap: (i) {
                HapticUtil.selectionClick();
                if (i == index) {
                  topStore.setTop("401");
                }
                index = i;
              },
              tabs: [
              Tab(text: I18n.of(context).illust),
              Tab(text: I18n.of(context).painter),
            ],
                ),
                ),
        body: TabBarView(
          children: [
            ResultIllustList(
              initialQuery: _query,
              restoreQuery: widget.initialQuery != null,
              onQueryChanged: _recordQuery,
        ),
            SearchResultPainterPage(word: _query.word),
          ],
          ),
      ),
    );
  }
}
