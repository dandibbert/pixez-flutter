import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/component/novel_lighting_list.dart';
import 'package:pixez/page/novel/search/novel_search_filter_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _applyQuery(
      _query,
      page: widget.restoreQuery ? _query.normalizedPage : 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            InkWell(
              onTap: () {},
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 2 / 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
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
                    icon: const Icon(Icons.date_range),
                    onPressed: () {
                      _buildShowDateRange(context);
                    },
                  ),
                  _buildBookmarkMenu(),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_outlined),
                    onPressed: () {
                      _openFilterSheet();
                    },
                  ),
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
    );
  }

  Future<void> _buildShowDateRange(BuildContext context) async {
    final dateTimeRange = await showDateRangePicker(
      context: context,
      initialDateRange: _query.startDate != null && _query.endDate != null
          ? DateTimeRange(start: _query.startDate!, end: _query.endDate!)
          : null,
      firstDate: DateTime(2007, 8),
      lastDate: DateTime.now(),
    );
    if (dateTimeRange == null) {
      return;
    }
    setState(() {
      _applyQuery(
        _query.copyWith(
          startDate: dateTimeRange.start,
          endDate: dateTimeRange.end,
        ),
      );
    });
  }

  void _applyQuery(NovelSearchQuery query, {int page = 1}) {
    _query = query.copyWith(page: page, mode: SearchResultMode.paged);
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

  bool _canUsePopular() {
    final now = accountStore.now;
    if (now != null && now.isPremium == 0) {
      BotToast.showText(text: 'not premium');
      return false;
    }
    return true;
  }

  void _openFilterSheet() {
    NovelSearchFilterSheet.show(
      context: context,
      initial: _query,
      canUsePopular: _canUsePopular,
      onApply: (query) {
        setState(() {
          _applyQuery(query);
        });
      },
    );
  }

  Widget _buildBookmarkMenu() {
    return PopupMenuButton<int>(
      initialValue: _query.bookmarkNumMin,
      child: const Icon(Icons.sort),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
      ),
      itemBuilder: (context) {
        return NovelSearchQuery.bookmarkPresets.map((int value) {
          return PopupMenuItem<int>(
            value: value,
            child: Text(
              value == 0 ? I18n.of(context).novel_filter_any : '$value+',
            ),
            onTap: () {
              setState(() {
                _applyQuery(
                  _query.copyWith(
                    bookmarkNumMin: value,
                    bookmarkNumMax: 0,
                  ),
                );
              });
            },
          );
        }).toList();
      },
    );
  }
}
