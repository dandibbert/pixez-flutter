import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/diagnostics/pronunciation_preview.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const Key novelTtsAddReadingKey = Key('novelTtsAddReading');
const Key novelTtsBulkReadingKey = Key('novelTtsBulkReading');
const Key novelTtsExportReadingKey = Key('novelTtsExportReading');
const Key novelTtsReadingSearchKey = Key('novelTtsReadingSearch');
const Key novelTtsReadingSurfaceFieldKey = Key('novelTtsReadingSurface');
const Key novelTtsReadingValueFieldKey = Key('novelTtsReadingValue');
const Key novelTtsReadingScopeKey = Key('novelTtsReadingScope');
const Key novelTtsReadingConflictKey = Key('novelTtsReadingConflict');
const Key novelTtsReadingSaveKey = Key('novelTtsReadingSave');
const Key novelTtsReadingPreviewFieldKey = Key('novelTtsReadingPreview');
const Key novelTtsReadingPreviewSpokenKey = Key('novelTtsReadingPreviewSpoken');
const Key novelTtsBulkReadingFieldKey = Key('novelTtsBulkReadingField');

Key novelTtsReadingTileKey(String id) => ValueKey('novelTtsReadingTile:$id');
Key novelTtsReadingSwitchKey(String id) =>
    ValueKey('novelTtsReadingSwitch:$id');
Key novelTtsReadingDeleteKey(String id) =>
    ValueKey('novelTtsReadingDelete:$id');

/// The work being read when an entry is added from the reader, which decides
/// the scopes the dialog can offer.
class NovelTtsReadingContext {
  const NovelTtsReadingContext({
    this.workId,
    this.workTitle,
    this.seriesId,
    this.seriesTitle,
  });

  final String? workId;
  final String? workTitle;
  final String? seriesId;
  final String? seriesTitle;
}

String novelTtsScopeLabel(AppLocalizations i18n, NovelTtsReading reading) {
  switch (reading.scope.type) {
    case PronunciationScopeType.global:
      return i18n.novel_tts_scope_global;
    case PronunciationScopeType.work:
      return i18n.novel_tts_scope_work(
        reading.scopeLabel ?? '#${reading.scope.scopeId}',
      );
    case PronunciationScopeType.series:
      return i18n.novel_tts_scope_series(
        reading.scopeLabel ?? '#${reading.scope.scopeId}',
      );
  }
}

String novelTtsModeLabel(AppLocalizations i18n, PronunciationMatchMode mode) {
  switch (mode) {
    case PronunciationMatchMode.exactPhrase:
      return i18n.novel_tts_mode_exact;
    case PronunciationMatchMode.nameAlias:
      return i18n.novel_tts_mode_alias;
    case PronunciationMatchMode.force:
      return i18n.novel_tts_mode_force;
  }
}

String _entryLabel(NovelTtsReading reading) =>
    '${reading.surface} → ${reading.reading}';

/// Opens the entry dialog. Returns the entry to save, with its id, scope and
/// edit time filled in, or null when the user cancels.
Future<NovelTtsReading?> showNovelTtsReadingDialog(
  BuildContext context, {
  NovelTtsReading? initial,
  List<NovelTtsReading> existing = const [],
  NovelTtsReadingContext? readingContext,
  String? initialSurface,
  String? previewText,
}) {
  return showDialog<NovelTtsReading>(
    context: context,
    builder: (context) => _ReadingDialog(
      initial: initial,
      existing: existing,
      readingContext: readingContext,
      initialSurface: initialSurface,
      previewText: previewText,
    ),
  );
}

/// Adds an entry while reading or listening, without leaving the reader. The
/// entry starts limited to the current work, and a session that is playing
/// picks it up from the current sentence.
Future<void> addNovelTtsReadingFromReader(
  BuildContext context, {
  String? surface,
  String? previewText,
  required NovelTtsReadingContext readingContext,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final i18n = I18n.of(context);
  final settings = NovelTtsSettings.load();
  final saved = await showNovelTtsReadingDialog(
    context,
    existing: settings.readings,
    readingContext: readingContext,
    initialSurface: surface,
    previewText: previewText,
  );
  if (saved == null) {
    return;
  }
  // Reload: the dialog may have been open while another entry point saved.
  final latest = NovelTtsSettings.load();
  await latest
      .copyWith(readings: upsertNovelTtsReading(latest.readings, saved))
      .save();
  messenger?.showSnackBar(
    SnackBar(content: Text(i18n.novel_tts_reading_saved(_entryLabel(saved)))),
  );
  await NovelTtsController.maybeInstance?.applySettings();
}

class NovelTtsReadingsEditor extends StatefulWidget {
  const NovelTtsReadingsEditor({
    super.key,
    required this.readings,
    required this.onChanged,
  });

  final List<NovelTtsReading> readings;
  final ValueChanged<List<NovelTtsReading>> onChanged;

  @override
  State<NovelTtsReadingsEditor> createState() => _NovelTtsReadingsEditorState();
}

class _NovelTtsReadingsEditorState extends State<NovelTtsReadingsEditor> {
  static const _searchThreshold = 6;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NovelTtsReading> get readings => widget.readings;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final theme = Theme.of(context);
    final query = _search.text.trim();
    final visible = [
      for (final reading in readings)
        if (query.isEmpty ||
            reading.surface.contains(query) ||
            reading.reading.contains(query))
          reading,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(i18n.novel_tts_readings_hint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (readings.length > _searchThreshold)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: novelTtsReadingSearchKey,
              controller: _search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: i18n.novel_tts_reading_search,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (readings.isEmpty || visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              readings.isEmpty
                  ? i18n.novel_tts_readings_empty
                  : i18n.novel_tts_reading_no_match,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final reading in visible) _tile(context, i18n, reading),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: novelTtsAddReadingKey,
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: Text(i18n.novel_tts_reading_add),
            ),
            OutlinedButton(
              key: novelTtsBulkReadingKey,
              onPressed: () => _bulk(context),
              child: Text(i18n.novel_tts_reading_bulk),
            ),
            if (readings.isNotEmpty)
              OutlinedButton(
                key: novelTtsExportReadingKey,
                onPressed: () => _export(context),
                child: Text(i18n.novel_tts_reading_export),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    AppLocalizations i18n,
    NovelTtsReading reading,
  ) {
    final theme = Theme.of(context);
    final active = reading.isActive;
    final id = reading.id ?? reading.dedupeKey;
    final details = [
      novelTtsModeLabel(i18n, reading.effectiveMode),
      novelTtsScopeLabel(i18n, reading),
      if (!active && reading.enabled)
        i18n.novel_tts_reading_needs_review
      else if (!active)
        i18n.novel_tts_reading_disabled,
    ].join(' · ');
    return ListTile(
      key: novelTtsReadingTileKey(id),
      contentPadding: EdgeInsets.zero,
      title: Text(
        _entryLabel(reading),
        style: active
            ? null
            : TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(details),
      onTap: () => _edit(context, entry: reading),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: novelTtsReadingSwitchKey(id),
            value: active,
            onChanged: (value) => _setActive(reading, value),
          ),
          IconButton(
            key: novelTtsReadingDeleteKey(id),
            tooltip: i18n.novel_tts_reading_delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, reading),
          ),
        ],
      ),
    );
  }

  void _setActive(NovelTtsReading reading, bool value) {
    final next = reading.copyWith(
      enabled: value,
      // Turning on an entry the guesser left off is the user confirming the
      // guessed mode, so it is written down.
      mode: value ? reading.effectiveMode : null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onChanged([
      for (final item in readings)
        if (identical(item, reading)) next else item,
    ]);
  }

  void _delete(BuildContext context, NovelTtsReading reading) {
    final index = readings.indexOf(reading);
    if (index < 0) {
      return;
    }
    widget.onChanged([...readings]..removeAt(index));
    final i18n = I18n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(i18n.novel_tts_reading_deleted(_entryLabel(reading))),
        action: SnackBarAction(
          label: i18n.novel_tts_reading_undo,
          onPressed: () {
            if (!mounted) {
              return;
            }
            final current = widget.readings;
            if (current.any((item) => item.dedupeKey == reading.dedupeKey)) {
              return;
            }
            final at = index.clamp(0, current.length);
            widget.onChanged([...current]..insert(at, reading));
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, {NovelTtsReading? entry}) async {
    final saved = await showNovelTtsReadingDialog(
      context,
      initial: entry,
      existing: readings,
    );
    if (saved == null || !mounted) {
      return;
    }
    widget.onChanged(upsertNovelTtsReading(widget.readings, saved));
  }

  Future<void> _bulk(BuildContext context) async {
    final i18n = I18n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _BulkReadingDialog(),
    );
    if (raw == null || !mounted) {
      return;
    }
    final parsed = parseNovelTtsReadingImport(raw);
    final merged = mergeNovelTtsReadings(widget.readings, parsed.readings);
    if (merged.added > 0 || merged.updated > 0) {
      widget.onChanged(merged.readings);
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          i18n.novel_tts_reading_import_result(
            '${merged.added}',
            '${merged.updated}',
            '${merged.unchanged}',
            '${parsed.skipped.length}',
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final i18n = I18n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(
      ClipboardData(text: formatNovelTtsReadingLines(readings)),
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(i18n.novel_tts_reading_exported('${readings.length}')),
      ),
    );
  }
}

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    this.initial,
    required this.existing,
    this.readingContext,
    this.initialSurface,
    this.previewText,
  });

  final NovelTtsReading? initial;
  final List<NovelTtsReading> existing;
  final NovelTtsReadingContext? readingContext;
  final String? initialSurface;
  final String? previewText;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ScopeOption {
  const _ScopeOption(this.scope, this.label);

  final PronunciationScope scope;
  final String? label;
}

class _ReadingDialogState extends State<_ReadingDialog> {
  late final TextEditingController _surface;
  late final TextEditingController _reading;
  late final TextEditingController _previewSource;
  late PronunciationMatchMode _mode;
  late final List<_ScopeOption> _scopes;
  late _ScopeOption _scope;
  final _previewer = PronunciationPreview();
  PronunciationPreviewResult? _preview;
  Timer? _previewTimer;
  var _previewSourceEdited = false;
  var _previewGeneration = 0;
  var _modeEdited = false;
  var _submitted = false;

  static const _global = PronunciationScope(
    type: PronunciationScopeType.global,
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _surface = TextEditingController(
      text: initial?.surface ?? widget.initialSurface?.trim() ?? '',
    );
    _reading = TextEditingController(text: initial?.reading ?? '');
    _modeEdited = initial?.mode != null;
    _mode = initial?.mode ?? defaultNovelTtsReadingMode(_surface.text);
    _scopes = _scopeOptions();
    _scope = initial == null
        ? (widget.readingContext?.workId != null
              ? _scopes.firstWhere(
                  (option) => option.scope.type == PronunciationScopeType.work,
                )
              : _scopes.first)
        : _scopes.firstWhere((option) => option.scope == initial.scope);
    final preview = widget.previewText?.trim();
    _previewSourceEdited = preview != null && preview.isNotEmpty;
    _previewSource = TextEditingController(
      text: _previewSourceEdited
          ? preview
          : defaultPronunciationPreviewText(_surface.text),
    );
    _schedulePreview();
  }

  List<_ScopeOption> _scopeOptions() {
    final options = <_ScopeOption>[const _ScopeOption(_global, null)];
    void add(PronunciationScope scope, String? label) {
      if (options.any((option) => option.scope == scope)) {
        return;
      }
      options.add(_ScopeOption(scope, label));
    }

    final context = widget.readingContext;
    if (context?.workId case final workId?) {
      add(
        PronunciationScope(type: PronunciationScopeType.work, scopeId: workId),
        context!.workTitle,
      );
    }
    if (context?.seriesId case final seriesId?) {
      add(
        PronunciationScope(
          type: PronunciationScopeType.series,
          scopeId: seriesId,
        ),
        context!.seriesTitle,
      );
    }
    if (widget.initial case final initial?) {
      add(initial.scope, initial.scopeLabel);
    }
    return options;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _surface.dispose();
    _reading.dispose();
    _previewSource.dispose();
    super.dispose();
  }

  NovelTtsReading _draft() {
    return NovelTtsReading(
      id: widget.initial?.id,
      surface: _surface.text,
      reading: _reading.text,
      mode: _mode,
      scope: _scope.scope,
      scopeLabel: _scope.label,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ).trimmed();
  }

  void _onRuleChanged() {
    if (!_previewSourceEdited) {
      _previewSource.text = defaultPronunciationPreviewText(_surface.text);
    }
    if (!_modeEdited) {
      final auto = defaultNovelTtsReadingMode(_surface.text);
      if (auto != _mode) {
        _mode = auto;
      }
    }
    setState(() {});
    _schedulePreview();
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 250), _runPreview);
  }

  /// Previews the draft together with every other entry that would apply in
  /// the same place, so a longer entry that wins over the draft shows up here
  /// rather than during playback.
  Future<void> _runPreview() async {
    final draft = _draft();
    final source = _previewSource.text;
    if (!draft.isValid || source.trim().isEmpty) {
      if (mounted) {
        setState(() => _preview = null);
      }
      return;
    }
    final generation = ++_previewGeneration;
    final entries = upsertNovelTtsReading(
      widget.existing,
      draft.copyWith(id: draft.id ?? '\u0000draft'),
    );
    final context = widget.readingContext;
    final scope = _scope.scope;
    final snapshot = PronunciationCompiler().compile(
      const PronunciationMigration().migrateV1(entries),
      workId: scope.type == PronunciationScopeType.work
          ? scope.scopeId
          : context?.workId,
      seriesId: scope.type == PronunciationScopeType.series
          ? scope.scopeId
          : context?.seriesId,
    );
    PronunciationPreviewResult? result;
    try {
      result = await _previewer.preview(source: source, snapshot: snapshot);
    } catch (_) {
      // A preview that cannot be produced shows nothing. Saving the rule is
      // still the user's call, and the pipeline degrades on its own at read
      // time, so there is nothing here worth blocking the dialog over.
    }
    if (!mounted || generation != _previewGeneration) {
      return;
    }
    setState(() => _preview = result);
  }

  String? _errorText(
    AppLocalizations i18n,
    String? error, {
    required bool forSurface,
  }) {
    switch (error) {
      case 'empty_surface':
        return forSurface && _submitted
            ? i18n.novel_tts_reading_error_empty_surface
            : null;
      case 'empty_reading':
        return !forSurface && _submitted
            ? i18n.novel_tts_reading_error_empty_reading
            : null;
      case 'surface_too_long':
        return forSurface
            ? i18n.novel_tts_reading_error_too_long(
                '${PronunciationLimits.maxSurfaceScalars}',
              )
            : null;
      case 'reading_too_long':
        return !forSurface
            ? i18n.novel_tts_reading_error_too_long(
                '${PronunciationLimits.maxReadingScalars}',
              )
            : null;
      case 'control_char':
        return i18n.novel_tts_reading_error_control;
    }
    return null;
  }

  void _save() {
    final draft = _draft();
    if (draft.validationError != null) {
      setState(() => _submitted = true);
      return;
    }
    Navigator.of(context).pop(
      draft.copyWith(id: draft.id ?? newNovelTtsReadingId(), enabled: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final theme = Theme.of(context);
    final draft = _draft();
    final error = draft.validationError;
    final conflict = draft.surface.isEmpty
        ? null
        : conflictingNovelTtsReading(widget.existing, draft);
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? i18n.novel_tts_reading_add
            : i18n.novel_tts_reading_edit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: novelTtsReadingSurfaceFieldKey,
              controller: _surface,
              autofocus: _surface.text.isEmpty,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_surface,
                border: const OutlineInputBorder(),
                errorText: _errorText(i18n, error, forSurface: true),
              ),
              onChanged: (_) => _onRuleChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: novelTtsReadingValueFieldKey,
              controller: _reading,
              autofocus: _surface.text.isNotEmpty,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_value,
                border: const OutlineInputBorder(),
                errorText: _errorText(i18n, error, forSurface: false),
              ),
              onChanged: (_) => _onRuleChanged(),
              onSubmitted: (_) => _save(),
            ),
            if (conflict != null)
              Padding(
                key: novelTtsReadingConflictKey,
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  i18n.novel_tts_reading_replaces(_entryLabel(conflict)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PronunciationMatchMode>(
              // The field keeps its own value, so it has to be rebuilt when the
              // surface picks a different mode for the user.
              key: ValueKey(_mode),
              initialValue: _mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_mode,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final mode in PronunciationMatchMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(novelTtsModeLabel(i18n, mode)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _mode = value;
                  _modeEdited = true;
                  _onRuleChanged();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                switch (_mode) {
                  PronunciationMatchMode.exactPhrase =>
                    i18n.novel_tts_mode_exact_hint,
                  PronunciationMatchMode.nameAlias =>
                    i18n.novel_tts_mode_alias_hint,
                  PronunciationMatchMode.force =>
                    i18n.novel_tts_mode_force_warning,
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _mode == PronunciationMatchMode.force
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_scopes.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: novelTtsReadingScopeKey,
                initialValue: _scopes.indexOf(_scope),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: i18n.novel_tts_reading_scope,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (var i = 0; i < _scopes.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        novelTtsScopeLabel(
                          i18n,
                          NovelTtsReading(
                            surface: '',
                            reading: '',
                            scope: _scopes[i].scope,
                            scopeLabel: _scopes[i].label,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _scope = _scopes[value];
                    _onRuleChanged();
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: novelTtsReadingPreviewFieldKey,
              controller: _previewSource,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_preview_source,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                _previewSourceEdited = true;
                _schedulePreview();
              },
            ),
            if (_preview case final preview?) _PreviewReport(preview: preview),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          key: novelTtsReadingSaveKey,
          onPressed: _save,
          child: Text(i18n.novel_tts_reading_save),
        ),
      ],
    );
  }
}

class _PreviewReport extends StatelessWidget {
  const _PreviewReport({required this.preview});

  final PronunciationPreviewResult preview;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final theme = Theme.of(context);
    final decisions = [...preview.resolved.allDecisions]
      ..sort((a, b) => a.start.compareTo(b.start));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${i18n.novel_tts_preview_spoken}: ${preview.spoken}',
            key: novelTtsReadingPreviewSpokenKey,
            style: theme.textTheme.bodyMedium,
          ),
          for (final decision in decisions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${decision.surface} · '
                '${decision.isApplied ? i18n.novel_tts_preview_applied : i18n.novel_tts_preview_skipped}'
                ' · ${_reasonLabel(i18n, decision.reason)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: decision.isApplied
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _reasonLabel(AppLocalizations i18n, PronunciationReason reason) {
    switch (reason) {
      case PronunciationReason.explicitRuby:
        return i18n.novel_tts_reason_ruby;
      case PronunciationReason.exactPhrase:
        return i18n.novel_tts_mode_exact;
      case PronunciationReason.forcedRule:
        return i18n.novel_tts_mode_force;
      case PronunciationReason.morphologyProperName:
      case PronunciationReason.nameParticleContext:
      case PronunciationReason.quotativeNameContext:
      case PronunciationReason.aliasWithoutConflict:
        return i18n.novel_tts_reason_name;
      case PronunciationReason.rejectedVerbOrAdjective:
      case PronunciationReason.rejectedInflectionSuffix:
        return i18n.novel_tts_reason_verb;
      case PronunciationReason.rejectedInsideLargerToken:
        return i18n.novel_tts_reason_word;
      case PronunciationReason.rejectedOverlap:
      case PronunciationReason.rejectedLowConfidence:
      case PronunciationReason.analyzerUnavailable:
      case PronunciationReason.analyzerTimeout:
      case PronunciationReason.invalidAnalyzerOffsets:
      case PronunciationReason.invalidSourceRange:
      case PronunciationReason.staleSession:
        return i18n.novel_tts_reason_uncertain;
    }
  }
}

class _BulkReadingDialog extends StatefulWidget {
  const _BulkReadingDialog();

  @override
  State<_BulkReadingDialog> createState() => _BulkReadingDialogState();
}

class _BulkReadingDialogState extends State<_BulkReadingDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return AlertDialog(
      title: Text(i18n.novel_tts_reading_bulk),
      content: TextField(
        key: novelTtsBulkReadingFieldKey,
        controller: _controller,
        minLines: 6,
        maxLines: 12,
        decoration: InputDecoration(
          hintText: i18n.novel_tts_reading_bulk_hint,
          hintMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(i18n.novel_tts_reading_save),
        ),
      ],
    );
  }
}
