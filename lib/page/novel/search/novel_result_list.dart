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
  late String searchTarget;
  late String selectSort;
  late int _bookmarkMin;
  late int _bookmarkMax;
  late int _textLengthMin;
  late String _lang;
  late bool _excludeAi;
  late bool _originalOnly;
  late bool _includeR18;
  late bool _translatedTags;
  late bool _mergeKeyword;
  DateTimeRange? _dateTimeRange;

  final sort = ["date_desc", "date_asc", "popular_desc"];
  static const List<String> search_target = [
    "keyword",
    "partial_match_for_tags",
    "exact_match_for_tags",
    "text",
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    searchTarget = _query.searchTarget;
    selectSort = _query.sort;
    _bookmarkMin = _query.bookmarkNumMin;
    _bookmarkMax = _query.bookmarkNumMax;
    _textLengthMin = _query.textLengthMin;
    _lang = _query.lang;
    _excludeAi = _query.searchAiType == 1;
    _originalOnly = _query.isOriginalOnly;
    _includeR18 = _query.includePotentialViolationWorks;
    _translatedTags = _query.includeTranslatedTagResults;
    _mergeKeyword = _query.mergePlainKeywordResults;
    if (_query.startDate != null && _query.endDate != null) {
      _dateTimeRange = DateTimeRange(
        start: _query.startDate!,
        end: _query.endDate!,
      );
    }
    _applyQuery(page: widget.restoreQuery ? _query.normalizedPage : 1);
  }

  String _label(String en, String zh) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
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
                    _buildBookmarkMenu(),
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

  void _applyDatePreset(int? days) {
    if (days == null) {
      _dateTimeRange = null;
      return;
    }
    final range = NovelSearchQuery.dateRangeForPreset(days);
    if (range == null) {
      _dateTimeRange = null;
      return;
    }
    _dateTimeRange = DateTimeRange(start: range.start, end: range.end);
  }

  void _applyQuery({int page = 1}) {
    _query = NovelSearchQuery(
      word: _query.word,
      translatedName: _query.translatedName,
      searchTarget: searchTarget,
      sort: selectSort,
      startDate: _dateTimeRange?.start,
      endDate: _dateTimeRange?.end,
      bookmarkNumMin: _bookmarkMin,
      bookmarkNumMax: _bookmarkMax,
      textLengthMin: _textLengthMin,
      lang: _lang,
      includePotentialViolationWorks: _includeR18,
      includeTranslatedTagResults: _translatedTags,
      isOriginalOnly: _originalOnly,
      mergePlainKeywordResults: _mergeKeyword,
      searchAiType: _excludeAi ? 1 : 0,
      page: page,
      mode: SearchResultMode.paged,
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
        bookmark_num_min:
            pageQuery.bookmarkNumMin > 0 ? pageQuery.bookmarkNumMin : null,
        bookmark_num_max:
            pageQuery.bookmarkNumMax > 0 ? pageQuery.bookmarkNumMax : null,
        text_length_min:
            pageQuery.textLengthMin > 0 ? pageQuery.textLengthMin : null,
        offset: pageQuery.offset,
        lang: pageQuery.lang.isEmpty ? null : pageQuery.lang,
        include_potential_violation_works:
            pageQuery.includePotentialViolationWorks,
        include_translated_tag_results: pageQuery.includeTranslatedTagResults,
        is_original_only: pageQuery.isOriginalOnly,
        is_replaceable_only: pageQuery.isReplaceableOnly,
        merge_plain_keyword_results: pageQuery.mergePlainKeywordResults,
        search_ai_type: pageQuery.searchAiType,
        force: force,
      );
    }

    return ApiPagedSource(
      initialPage: query.normalizedPage,
      futureGet: fetchPage,
      searchQueryJson: query.encode(),
      searchPage: query.normalizedPage,
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
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8.0))),
        builder: (context) {
          return StatefulBuilder(builder: (_, setS) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            TextButton(
                                onPressed: () {},
                                child: Text(I18n.of(context).filter)),
                            TextButton(
                                onPressed: () {
                                  setState(() {
                                    _applyQuery();
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: Text(I18n.of(context).apply)),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl(
                            groupValue: search_target.indexOf(searchTarget),
                            children: <int, Widget>{
                              0: Text(
                                I18n.of(context).key_word,
                                maxLines: 1,
                              ),
                              1: Text(
                                I18n.of(context).partial_match_for_tag,
                                maxLines: 1,
                              ),
                              2: Text(
                                I18n.of(context).exact_match_for_tag,
                                maxLines: 1,
                              ),
                              3: Text(
                                I18n.of(context).text,
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
                        const SizedBox(height: 12),
                        SizedBox(
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: Text(_label('Anytime', '不限时间')),
                              onPressed: () {
                                setS(() => _applyDatePreset(null));
                              },
                            ),
                            for (final days in NovelSearchQuery.datePresetDays)
                              ActionChip(
                                label: Text(_label(
                                  'Last $days days',
                                  '近$days天',
                                )),
                                onPressed: () {
                                  setS(() => _applyDatePreset(days));
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_label('Bookmarks', '收藏数')),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final value
                                in NovelSearchQuery.bookmarkPresets)
                              ActionChip(
                                label: Text(value == 0
                                    ? _label('Any', '不限')
                                    : '$value+'),
                                onPressed: () {
                                  setS(() {
                                    _bookmarkMin = value;
                                    _bookmarkMax = 0;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_label('Minimum length', '最少字数')),
                        Slider(
                          value: _textLengthMin.toDouble().clamp(0, 20000),
                          min: 0,
                          max: 20000,
                          divisions: 20,
                          label: _textLengthMin == 0
                              ? _label('Any', '不限')
                              : '$_textLengthMin',
                          onChanged: (value) {
                            setS(() {
                              _textLengthMin = value.round();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(_label('Language', '语言')),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('日本語'),
                              onPressed: () => setS(() => _lang = 'ja'),
                            ),
                            ActionChip(
                              label: const Text('中文'),
                              onPressed: () => setS(() => _lang = 'zh-CN'),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_label('Exclude AI', '排除 AI')),
                          value: _excludeAi,
                          onChanged: (value) =>
                              setS(() => _excludeAi = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_label('Original only', '仅原创')),
                          value: _originalOnly,
                          onChanged: (value) =>
                              setS(() => _originalOnly = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_label(
                            'Include potential R-18',
                            '包含可能违规作品',
                          )),
                          value: _includeR18,
                          onChanged: (value) =>
                              setS(() => _includeR18 = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_label(
                            'Translated tags',
                            '包含翻译标签',
                          )),
                          value: _translatedTags,
                          onChanged: (value) =>
                              setS(() => _translatedTags = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_label(
                            'Merge keyword results',
                            '合并关键词结果',
                          )),
                          value: _mergeKeyword,
                          onChanged: (value) =>
                              setS(() => _mergeKeyword = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          });
        });
  }

  Widget _buildBookmarkMenu() {
    return PopupMenuButton(
      initialValue: _bookmarkMin,
      child: Icon(
        Icons.sort,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0))),
      itemBuilder: (context) {
        return NovelSearchQuery.bookmarkPresets.map((int value) {
          return PopupMenuItem(
            value: value,
            child: Text(value == 0 ? _label('Any', '不限') : '$value+'),
            onTap: () {
              setState(() {
                _bookmarkMin = value;
                _bookmarkMax = 0;
                _applyQuery();
              });
            },
          );
        }).toList();
      },
    );
  }
}
