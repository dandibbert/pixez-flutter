import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:pixez/store/search_result_mode.dart';

const Key novelSearchFilterSheetKey = Key('novelSearchFilterSheet');
const Key novelSearchFilterApplyKey = Key('novelSearchFilterApply');
const Key novelSearchFilterResetKey = Key('novelSearchFilterReset');

class NovelSearchFilterSheet extends StatefulWidget {
  final NovelSearchQuery initial;
  final bool Function()? canUsePopular;
  final ValueChanged<NovelSearchQuery> onApply;

  const NovelSearchFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
    this.canUsePopular,
  });

  static Future<void> show({
    required BuildContext context,
    required NovelSearchQuery initial,
    required ValueChanged<NovelSearchQuery> onApply,
    bool Function()? canUsePopular,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: NovelSearchFilterSheet(
            initial: initial,
            onApply: onApply,
            canUsePopular: canUsePopular,
          ),
        );
      },
    );
  }

  @override
  State<NovelSearchFilterSheet> createState() => _NovelSearchFilterSheetState();
}

class _NovelSearchFilterSheetState extends State<NovelSearchFilterSheet> {
  late String _searchTarget;
  late String _sort;
  DateTime? _startDate;
  DateTime? _endDate;
  late int _bookmarkMin;
  late int _bookmarkMax;
  late int _textLengthMin;
  late String _lang;
  late bool _excludeAi;
  late bool _originalOnly;
  late bool _includeR18;
  late bool _translatedTags;
  late bool _mergeKeyword;
  late final TextEditingController _bookmarkMinController;
  late final TextEditingController _bookmarkMaxController;
  late final TextEditingController _textLengthController;
  String? _error;

  static const _targets = NovelSearchQuery.supportedSearchTargets;
  static const _sorts = ['date_desc', 'date_asc', 'popular_desc'];

  @override
  void initState() {
    super.initState();
    _bookmarkMinController = TextEditingController();
    _bookmarkMaxController = TextEditingController();
    _textLengthController = TextEditingController();
    _restore(widget.initial);
  }

  @override
  void dispose() {
    _bookmarkMinController.dispose();
    _bookmarkMaxController.dispose();
    _textLengthController.dispose();
    super.dispose();
  }

  void _restore(NovelSearchQuery query) {
    _searchTarget = query.searchTarget;
    _sort = query.sort;
    _startDate = query.startDate;
    _endDate = query.endDate;
    _bookmarkMin = query.bookmarkNumMin;
    _bookmarkMax = query.bookmarkNumMax;
    _textLengthMin = query.textLengthMin;
    _lang = query.lang;
    _excludeAi = query.searchAiType == 1;
    _originalOnly = query.isOriginalOnly;
    _includeR18 = query.includePotentialViolationWorks;
    _translatedTags = query.includeTranslatedTagResults;
    _mergeKeyword = query.mergePlainKeywordResults;
    _error = null;
    _syncFields();
  }

  String _numberText(int value) => value > 0 ? '$value' : '';

  void _syncFields() {
    _bookmarkMinController.text = _numberText(_bookmarkMin);
    _bookmarkMaxController.text = _numberText(_bookmarkMax);
    _textLengthController.text = _numberText(_textLengthMin);
  }

  void _reset() {
    setState(() {
      _restore(
        NovelSearchQuery(
          word: widget.initial.word,
          translatedName: widget.initial.translatedName,
        ),
      );
    });
  }

  void _applyDatePreset(int? days) {
    setState(() {
      if (days == null) {
        _startDate = null;
        _endDate = null;
        return;
      }
      final range = NovelSearchQuery.dateRangeForPreset(days);
      _startDate = range?.start;
      _endDate = range?.end;
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2007, 8),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  NovelSearchQuery _draft() {
    return NovelSearchQuery(
      word: widget.initial.word,
      translatedName: widget.initial.translatedName,
      searchTarget: _searchTarget,
      sort: _sort,
      startDate: _startDate,
      endDate: _endDate,
      bookmarkNumMin: NovelSearchQuery.parseNumberInput(
        _bookmarkMinController.text,
      ),
      bookmarkNumMax: NovelSearchQuery.parseNumberInput(
        _bookmarkMaxController.text,
      ),
      textLengthMin: NovelSearchQuery.parseNumberInput(
        _textLengthController.text,
      ),
      lang: _lang,
      includePotentialViolationWorks: _includeR18,
      includeTranslatedTagResults: _translatedTags,
      isOriginalOnly: _originalOnly,
      mergePlainKeywordResults: _mergeKeyword,
      searchAiType: _excludeAi ? 1 : 0,
      page: 1,
      mode: SearchResultMode.paged,
    );
  }

  void _apply() {
    final draft = _draft();
    if (NovelSearchQuery.isBookmarkRangeInvalid(
      draft.bookmarkNumMin,
      draft.bookmarkNumMax,
    )) {
      setState(() {
        _error = I18n.of(context).novel_filter_bookmark_range_invalid;
      });
      return;
    }
    widget.onApply(draft);
    Navigator.of(context).pop();
  }

  String _datePresetLabel(AppLocalizations i18n, int? days) {
    if (days == null) {
      return i18n.novel_filter_anytime;
    }
    if (days == 180) {
      return i18n.novel_filter_last_half_year;
    }
    if (days == 365) {
      return i18n.novel_filter_last_year;
    }
    return i18n.novel_filter_last_n_days(days);
  }

  String _targetLabel(AppLocalizations i18n, String target) {
    switch (target) {
      case 'partial_match_for_tags':
        return i18n.partial_match_for_tag;
      case 'exact_match_for_tags':
        return i18n.exact_match_for_tag;
      case 'text':
        return i18n.text;
      default:
        return i18n.key_word;
    }
  }

  String _sortLabel(AppLocalizations i18n, String value) {
    switch (value) {
      case 'date_asc':
        return i18n.date_asc;
      case 'popular_desc':
        return i18n.popular_desc;
      default:
        return i18n.date_desc;
    }
  }

  String _formatDate(DateTime? value, String empty) {
    if (value == null) {
      return empty;
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return ConstrainedBox(
      key: novelSearchFilterSheetKey,
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.filter,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: i18n.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _section(
                  context,
                  title: i18n.novel_filter_search_mode,
                  child: _chipWrap(
                    children: [
                      for (final target in _targets)
                        _choice(
                          label: _targetLabel(i18n, target),
                          selected: _searchTarget == target,
                          onTap: () => setState(() => _searchTarget = target),
                        ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_sort,
                  child: _chipWrap(
                    children: [
                      for (final value in _sorts)
                        _choice(
                          label: _sortLabel(i18n, value),
                          selected: _sort == value,
                          onTap: () {
                            if (value == 'popular_desc' &&
                                widget.canUsePopular?.call() == false) {
                              return;
                            }
                            setState(() => _sort = value);
                          },
                        ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_publish_date,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _chipWrap(
                        children: [
                          _choice(
                            label: _datePresetLabel(i18n, null),
                            selected: _startDate == null && _endDate == null,
                            onTap: () => _applyDatePreset(null),
                          ),
                          for (final days in NovelSearchQuery.datePresetDays)
                            _choice(
                              label: _datePresetLabel(i18n, days),
                              selected: _isDatePreset(days),
                              onTap: () => _applyDatePreset(days),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dateField(
                              label: i18n.novel_filter_start_date,
                              value: _formatDate(
                                _startDate,
                                i18n.novel_filter_no_limit,
                              ),
                              onTap: () => _pickDate(start: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dateField(
                              label: i18n.novel_filter_end_date,
                              value: _formatDate(
                                _endDate,
                                i18n.novel_filter_no_limit,
                              ),
                              onTap: () => _pickDate(start: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_bookmarks,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _chipWrap(
                        children: [
                          for (final value in NovelSearchQuery.bookmarkPresets)
                            _choice(
                              label: value == 0
                                  ? i18n.novel_filter_any
                                  : '$value+',
                              selected:
                                  _bookmarkMin == value && _bookmarkMax == 0,
                              onTap: () {
                                setState(() {
                                  _bookmarkMin = value;
                                  _bookmarkMax = 0;
                                  _error = null;
                                  _syncFields();
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              controller: _bookmarkMinController,
                              label: i18n.novel_filter_minimum,
                              hint: i18n.novel_filter_no_limit,
                              onChanged: (value) {
                                setState(() {
                                  _bookmarkMin =
                                      NovelSearchQuery.parseNumberInput(value);
                                  _error = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberField(
                              controller: _bookmarkMaxController,
                              label: i18n.novel_filter_maximum,
                              hint: i18n.novel_filter_no_limit,
                              onChanged: (value) {
                                setState(() {
                                  _bookmarkMax =
                                      NovelSearchQuery.parseNumberInput(value);
                                  _error = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_min_length,
                  child: _numberField(
                    controller: _textLengthController,
                    label: i18n.novel_filter_min_length,
                    hint: i18n.novel_filter_no_limit,
                    onChanged: (value) {
                      setState(() {
                        _textLengthMin = NovelSearchQuery.parseNumberInput(
                          value,
                        );
                      });
                    },
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_language,
                  child: _chipWrap(
                    children: [
                      _choice(
                        label: i18n.novel_filter_lang_ja,
                        selected: _lang == 'ja',
                        onTap: () => setState(() => _lang = 'ja'),
                      ),
                      _choice(
                        label: i18n.novel_filter_lang_zh,
                        selected: _lang == 'zh-CN',
                        onTap: () => setState(() => _lang = 'zh-CN'),
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_content,
                  child: Column(
                    children: [
                      _switchTile(
                        title: i18n.novel_filter_exclude_ai,
                        value: _excludeAi,
                        onChanged: (value) =>
                            setState(() => _excludeAi = value),
                      ),
                      _switchTile(
                        title: i18n.novel_filter_original_only,
                        value: _originalOnly,
                        onChanged: (value) =>
                            setState(() => _originalOnly = value),
                      ),
                      _switchTile(
                        title: i18n.novel_filter_include_r18,
                        value: _includeR18,
                        onChanged: (value) =>
                            setState(() => _includeR18 = value),
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: i18n.novel_filter_matching,
                  child: Column(
                    children: [
                      _switchTile(
                        title: i18n.novel_filter_translated_tags,
                        value: _translatedTags,
                        onChanged: (value) =>
                            setState(() => _translatedTags = value),
                      ),
                      _switchTile(
                        title: i18n.novel_filter_merge_keyword,
                        value: _mergeKeyword,
                        onChanged: (value) =>
                            setState(() => _mergeKeyword = value),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: scheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: novelSearchFilterResetKey,
                        onPressed: _reset,
                        child: Text(i18n.novel_filter_reset),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: novelSearchFilterApplyKey,
                        onPressed: _apply,
                        child: Text(i18n.apply),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDatePreset(int days) {
    final preset = NovelSearchQuery.dateRangeForPreset(days);
    if (preset == null || _startDate == null || _endDate == null) {
      return false;
    }
    return _sameDay(_startDate!, preset.start) &&
        _sameDay(_endDate!, preset.end);
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipWrap({required List<Widget> children}) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(value),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
