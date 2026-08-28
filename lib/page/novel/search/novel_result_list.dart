import 'package:bot_toast/bot_toast.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/component/novel_lighting_list.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';

class NovelResultList extends StatefulWidget {
  final NovelSearchQuery initialQuery;
  final bool restoreQuery;
  final ValueChanged<NovelSearchQuery>? onQueryChanged;

  const NovelResultList({
    Key? key,
    required this.initialQuery,
    this.restoreQuery = false,
    this.onQueryChanged,
  }) : super(key: key);

  @override
  _NovelResultListState createState() => _NovelResultListState();
}

class _NovelResultListState extends State<NovelResultList> {
  late NovelSearchQuery _query;
  late LightSource _source;
  String searchTarget = NovelSearchQuery.supportedSearchTargets.first;
  String selectSort = "date_desc";
  int _starValue = 0;
  DateTimeRange? _dateTimeRange;

  final sort = ["date_desc", "date_asc", "popular_desc"];
  static const List<String> search_target = [
    "partial_match_for_tags",
    "exact_match_for_tags",
    "text",
    "keyword",
  ];
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
    _applyQuery(page: widget.restoreQuery ? _query.normalizedPage : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              InkWell(
                onTap: () {},
                child: Container(
                  width: MediaQuery.of(context).size.width * 2 / 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Text(
                        _query.word,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.date_range),
                        onPressed: () {
                          _buildShowDateRange(context);
                        }),
                    _buildStar(),
                    IconButton(
                        icon: Icon(Icons.filter_alt_outlined),
                        onPressed: () {
                          _buildShowBottomSheet(context);
                        }),
                  ],
                ),
              )
            ],
          ),
          Expanded(
            child: NovelLightingList(
              source: _source,
              onPageChanged: _onPageChanged,
            ),
          ),
        ],
      ),
    );
  }

  Future _buildShowDateRange(BuildContext context) async {
    DateTimeRange? dateTimeRange = await showDateRangePicker(
        context: context,
        initialDateRange: _dateTimeRange,
        firstDate: DateTime(2007, 8),
        lastDate: DateTime.now());
    if (dateTimeRange != null) {
      _dateTimeRange = dateTimeRange;
      setState(() {
        _applyQuery();
      });
    }
  }

  void _applyQuery({int page = 1}) {
    _query = NovelSearchQuery(
      word: _query.word,
      translatedName: _query.translatedName,
      searchTarget: searchTarget,
      sort: selectSort,
      startDate: _dateTimeRange?.start,
      endDate: _dateTimeRange?.end,
      starValue: _starValue,
      page: page,
      mode: _query.mode,
    );
    _source = _buildSource(_query);
    widget.onQueryChanged?.call(_query);
  }

  LightSource _buildSource(NovelSearchQuery query) {
    Future<Response> fetchPage(int page, bool force) {
      final pageQuery = query.copyWith(page: page);
      return apiClient.getSearchNovel(
        pageQuery.requestWord,
        search_target: pageQuery.searchTarget,
        sort: pageQuery.sort,
        start_date: pageQuery.startDate,
        end_date: pageQuery.endDate,
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
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8.0))),
        builder: (context) {
          return StatefulBuilder(builder: (_, setS) {
            return SafeArea(
              child: Container(
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          TextButton(
                              onPressed: () {},
                              child: Text(I18n.of(context).filter,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary))),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  _applyQuery();
                                });
                                Navigator.of(context).pop();
                              },
                              child: Text(I18n.of(context).apply,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary))),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl(
                            groupValue: search_target.indexOf(searchTarget),
                            children: <int, Widget>{
                              0: Text(
                                I18n.of(context).partial_match_for_tag,
                                maxLines: 1,
                              ),
                              1: Text(
                                I18n.of(context).exact_match_for_tag,
                                maxLines: 1,
                              ),
                              2: Text(
                                I18n.of(context).text,
                                maxLines: 1,
                              ),
                              3: Text(
                                I18n.of(context).key_word,
                                maxLines: 1,
                              ),
                            },
                            onValueChanged: (int? index) {
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
                          child: CupertinoSlidingSegmentedControl(
                            groupValue: sort.indexOf(selectSort),
                            children: <int, Widget>{
                              0: Text(
                                I18n.of(context).date_desc,
                                maxLines: 1,
                              ),
                              1: Text(
                                I18n.of(context).date_asc,
                                maxLines: 1,
                              ),
                              2: Text(
                                I18n.of(context).popular_desc,
                                maxLines: 1,
                              ),
                            },
                            onValueChanged: (int? index) {
                              if (accountStore.now != null && index == 2) {
                                if (accountStore.now!.isPremium == 0) {
                                  BotToast.showText(text: 'not premium');
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
                      Container(
                        height: 16,
                      )
                    ],
                  )),
            );
          });
        });
  }

  Widget _buildStar() {
    return PopupMenuButton(
      initialValue: _starValue,
      child: Icon(
        Icons.sort,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0))),
      itemBuilder: (context) {
        return starNum.map((int value) {
          if (value > 0) {
            return PopupMenuItem(
              value: value,
              child: Text("${value} users入り"),
              onTap: () {
                setState(() {
                  _starValue = value;
                  _applyQuery();
                });
              },
            );
          } else {
            return PopupMenuItem(
              value: value,
              child: Text("Default"),
              onTap: () {
                setState(() {
                  _starValue = value;
                  _applyQuery();
                });
              },
            );
          }
        }).toList();
      },
    );
  }
}
