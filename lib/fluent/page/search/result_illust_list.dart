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

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show showDateRangePicker;
import 'package:pixez/i18n.dart';
import 'package:pixez/fluent/lighting/fluent_lighting_page.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/search/illust_search_query.dart';
import 'package:pixez/page/search/result_illust_store.dart';
import 'package:pixez/store/search_result_mode.dart';

class ResultIllustList extends StatefulWidget {
  final IllustSearchQuery initialQuery;
  final ValueChanged<IllustSearchQuery>? onQueryChanged;

  const ResultIllustList({
    Key? key,
    required this.initialQuery,
    this.onQueryChanged,
  }) : super(key: key);

  @override
  _ResultIllustListState createState() => _ResultIllustListState();
}

class _ResultIllustListState extends State<ResultIllustList> {
  late ResultIllustStore resultIllustStore;
  late LightSource futureGet;
  late IllustSearchQuery _query;
  late ScrollController _scrollController;
  late StreamSubscription<String> listen;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    searchTarget = _query.searchTarget;
    selectSort = _query.sort;
    _starValue = _query.starValue;
    if (_query.startDate != null && _query.endDate != null) {
      _dateTimeRange = DateTimeRange(
        start: _query.startDate!,
        end: _query.endDate!,
      );
    }
    _scrollController = ScrollController();
    _changeQueryParams(page: _query.normalizedPage, source: _query.source);
    listen = topStore.topStream.listen((event) {
      if (event == "401") {
        _scrollController.position.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    listen.cancel();
    super.dispose();
  }

  List<int> starNum = [
    0,
    100,
    250,
    500,
    1000,
    5000,
    7500,
    10000,
    20000,
    30000,
    50000,
  ];

  final sort = [
    "date_desc",
    "date_asc",
    "popular_desc",
    "popular_male_desc",
    "popular_female_desc",
  ];
  static List<String> search_target = [
    "partial_match_for_tags",
    "exact_match_for_tags",
    "title_and_caption",
  ];
  String searchTarget = search_target[0];
  String selectSort = "date_desc";
  int selectStarNum = 0;
  // double starValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: Align(
        alignment: Alignment.centerRight,
        child: Row(
          children: [
            IconButton(
                icon: Icon(FluentIcons.date_time),
                onPressed: () {
                  _buildShowDateRange(context);
              },
            ),
            _buildStar(),
            IconButton(
                icon: Icon(FluentIcons.filter),
                onPressed: () {
                  _buildShowBottomSheet(context);
                  // _showMaterialBottom();
              },
            ),
          ],
        ),
      ),
      content: LightingList(
        source: futureGet,
        scrollController: _scrollController,
        filter: (illust) {
          return switch (_query.ugoiraFilter) {
            UgoiraFilter.all => true,
            UgoiraFilter.onlyUgoira => illust.type == 'ugoira',
            UgoiraFilter.noUgoira => illust.type != 'ugoira',
          };
        },
        onPageChanged: _onPageChanged,
      ),
    );
  }

  DateTimeRange? _dateTimeRange;

  Future _buildShowDateRange(BuildContext context) async {
    final dateTimeRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateTimeRange,
      firstDate: DateTime(2007, 8),
      lastDate: DateTime.now(),
    );
    if (dateTimeRange == null || !mounted) return;
    _dateTimeRange = dateTimeRange;
    setState(_changeQueryParams);
  }

  void _changeQueryParams({
    int page = 1,
    IllustSearchSource source = IllustSearchSource.normal,
  }) {
    _query = _query.copyWith(
      searchTarget: searchTarget,
              sort: selectSort,
      startDate: _dateTimeRange?.start,
      endDate: _dateTimeRange?.end,
      bookmarkRange: _query.bookmarkRange,
      starValue: _starValue,
      page: source == IllustSearchSource.normal ? page : 1,
      source: source,
    );
    futureGet = _buildSource(_query);
    widget.onQueryChanged?.call(_query);
  }

  LightSource _buildSource(IllustSearchQuery query) {
    if (query.source == IllustSearchSource.popularPreview) {
      if (query.mode == SearchResultMode.paged) {
        return ApiPagedSource(
          searchQueryJson: query.copyWith(page: 1).encode(),
          searchPage: 1,
          futureGet: (page, _) {
            if (page != 1) {
              return Future.error(StateError('Popular preview has one page'));
            }
            return apiClient.getPopularPreview(query.word);
          },
        );
      }
      return ApiForceSource(
        futureGet: (_) => apiClient.getPopularPreview(query.word),
        searchQueryJson: query.copyWith(page: 1).encode(),
        searchPage: 1,
      );
    }
    Future<Response> fetchPage(int page, bool force) {
      final pageQuery = query.copyWith(page: page);
      return apiClient.getSearchIllust(
        pageQuery.requestWord,
        search_target: pageQuery.searchTarget,
        sort: pageQuery.sort,
        start_date: pageQuery.startDate,
        end_date: pageQuery.endDate,
        bookmark_num: pageQuery.bookmarkRange,
        search_ai_type: pageQuery.searchAIType,
        offset: pageQuery.offset,
        force: force,
      );
    }

    if (query.mode == SearchResultMode.paged) {
      return ApiPagedSource(
        initialPage: query.normalizedPage,
        futureGet: fetchPage,
        searchQueryJson: query.encode(),
        searchPage: query.normalizedPage,
      );
    }
    return ApiForceSource(
      futureGet: (force) => fetchPage(1, force),
      searchQueryJson: query.copyWith(page: 1).encode(),
      searchPage: 1,
    );
  }

  void _onPageChanged(int page) {
    if (_query.page == page) return;
    setState(() {
      _query = _query.copyWith(page: page);
    });
    widget.onQueryChanged?.call(_query);
  }

  void _buildShowBottomSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(I18n.of(context).filter),
        content: StatefulBuilder(
          builder: (_, setS) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ComboBox<int>(
                          value: search_target.indexOf(searchTarget),
                          items: [
                            ComboBoxItem(
                                child: Text(
                                  I18n.of(context).partial_match_for_tag,
                                ),
                              value: 0,
                            ),
                            ComboBoxItem(
                                child: Text(
                                  I18n.of(context).exact_match_for_tag,
                                ),
                              value: 1,
                            ),
                            ComboBoxItem(
                              child: Text(I18n.of(context).title_and_caption),
                              value: 2,
                            ),
                          ],
                          onChanged: (int? index) {
                            setS(() {
                              searchTarget = search_target[index!];
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ComboBox<int>(
                          value: sort.indexOf(selectSort),
                          items: [
                            ComboBoxItem(
                              child: Text(I18n.of(context).date_desc),
                              value: 0,
                            ),
                            ComboBoxItem(
                              child: Text(I18n.of(context).date_asc),
                              value: 1,
                            ),
                            ComboBoxItem(
                              child: Text(I18n.of(context).popular_desc),
                              value: 2,
                            ),
                            ComboBoxItem(
                              child: Text(I18n.of(context).popular_male_desc),
                              value: 3,
                            ),
                            ComboBoxItem(
                                child: Text(
                                  I18n.of(context).popular_female_desc,
                                ),
                              value: 4,
                            ),
                          ],
                          onChanged: (int? index) {
                            if (accountStore.now != null && index == 2) {
                              if (accountStore.now!.isPremium == 0) {
                                BotToast.showText(text: 'not premium');
                                setState(() {
                                    _changeQueryParams(
                                      source: IllustSearchSource.popularPreview,
                                    );
                                });
                                Navigator.of(context).pop();
                                return;
                              }
                            }
                            setS(() {
                              selectSort = sort[index!];
                            });
                          },
                        ),
                      ),
                    ),
                      Container(height: 16),
                  ],
                ),
              ),
            ),
          );
          },
        ),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() {
                _changeQueryParams();
              });
              Navigator.of(context).pop();
            },
            child: Text(I18n.of(context).apply),
          ),
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(I18n.of(context).cancel),
          ),
        ],
      ),
    );
  }

  int _starValue = 0;

  Widget _buildStar() {
    return ComboBox(
        value: _starValue,
        icon: Icon(FluentIcons.sort),
        items: starNum.map((int value) {
          if (value > 0) {
            return ComboBoxItem(
              value: value,
              child: Text("${value} users入り"),
              onTap: () {
                setState(() {
                  _starValue = value;
                  _changeQueryParams();
                });
              },
            );
          } else {
            return ComboBoxItem(
              value: value,
              child: Text("Default"),
              onTap: () {
                setState(() {
                  _starValue = value;
                  _changeQueryParams();
                });
              },
            );
          }
      }).toList(),
    );
  }
}
