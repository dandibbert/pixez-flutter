import 'package:flutter/material.dart';
import 'package:pixez/page/novel/tts/data/pronunciation_dictionary_repository.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';

class PronunciationDictionaryPage extends StatefulWidget {
  const PronunciationDictionaryPage({
    super.key,
    this.repository,
    this.initialSurface = '',
    this.initialScope = PronunciationScope.global,
    this.initialScopeId,
  });
  final PronunciationDictionaryRepository? repository;
  final String initialSurface;
  final PronunciationScope initialScope;
  final String? initialScopeId;
  @override
  State<PronunciationDictionaryPage> createState() =>
      _PronunciationDictionaryPageState();
}

class _PronunciationDictionaryPageState
    extends State<PronunciationDictionaryPage> {
  late final PronunciationDictionaryRepository repository =
      widget.repository ?? PronunciationDictionaryRepository();
  List<PronunciationRule> rules = const [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    if (mounted)
      setState(() {
        rules = value;
        loading = false;
      });
  }

  Future<void> _edit([PronunciationRule? rule]) async {
    final value = await showDialog<PronunciationRule>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: PronunciationRuleEditor(
            initial: rule,
            initialSurface: rule == null ? widget.initialSurface : '',
            initialScope: rule?.scope ?? widget.initialScope,
            initialScopeId: rule?.scopeId ?? widget.initialScopeId,
          ),
        ),
      ),
    );
    if (value == null) return;
    await repository.upsert(value);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pronunciation dictionary')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Add pronunciation'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : rules.isEmpty
        ? const Center(child: Text('No pronunciation rules yet.'))
        : ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return ListTile(
                leading: Switch(
                  value: rule.enabled,
                  onChanged: (value) async {
                    await repository.upsert(rule.copyWith(enabled: value));
                    await _load();
                  },
                ),
                title: Text('${rule.surface} → ${rule.reading}'),
                subtitle: Text(
                  '${rule.scope.name}${rule.scopeId == null ? '' : ' · ${rule.scopeId}'} · priority ${rule.priority}${rule.overridePixivRuby ? ' · overrides Pixiv ruby' : ''}',
                ),
                onTap: () => _edit(rule),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await repository.delete(rule.id);
                    await _load();
                  },
                ),
              );
            },
          ),
  );
}

class PronunciationRuleEditor extends StatefulWidget {
  const PronunciationRuleEditor({
    super.key,
    this.initial,
    this.initialSurface = '',
    this.initialScope = PronunciationScope.global,
    this.initialScopeId,
  });
  final PronunciationRule? initial;
  final String initialSurface;
  final PronunciationScope initialScope;
  final String? initialScopeId;
  @override
  State<PronunciationRuleEditor> createState() =>
      _PronunciationRuleEditorState();
}

class _PronunciationRuleEditorState extends State<PronunciationRuleEditor> {
  late final TextEditingController surface = TextEditingController(
    text: widget.initial?.surface ?? widget.initialSurface,
  );
  late final TextEditingController reading = TextEditingController(
    text: widget.initial?.reading ?? '',
  );
  late final TextEditingController scopeId = TextEditingController(
    text: widget.initial?.scopeId ?? widget.initialScopeId ?? '',
  );
  late final TextEditingController priority = TextEditingController(
    text: (widget.initial?.priority ?? 0).toString(),
  );
  late PronunciationScope scope = widget.initial?.scope ?? widget.initialScope;
  late bool enabled = widget.initial?.enabled ?? true;
  late bool overrideRuby = widget.initial?.overridePixivRuby ?? false;
  @override
  void dispose() {
    surface.dispose();
    reading.dispose();
    scopeId.dispose();
    priority.dispose();
    super.dispose();
  }

  PronunciationRule? _draft() {
    if (surface.text.trim().isEmpty || reading.text.trim().isEmpty) return null;
    if (scope != PronunciationScope.global && scopeId.text.trim().isEmpty)
      return null;
    return PronunciationRule(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      surface: surface.text.trim(),
      reading: reading.text.trim(),
      scope: scope,
      scopeId: scope == PronunciationScope.global ? null : scopeId.text.trim(),
      priority: int.tryParse(priority.text) ?? 0,
      enabled: enabled,
      overridePixivRuby: overrideRuby,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    final projection = draft == null
        ? null
        : PronunciationEngine().apply(
            draft.surface,
            [draft],
            PronunciationContext(
              novelId: draft.scope == PronunciationScope.novel
                  ? draft.scopeId
                  : null,
              seriesId: draft.scope == PronunciationScope.series
                  ? draft.scopeId
                  : null,
              authorId: draft.scope == PronunciationScope.author
                  ? draft.scopeId
                  : null,
            ),
          );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null
                  ? 'Add pronunciation'
                  : 'Edit pronunciation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('pronunciation-surface'),
              controller: surface,
              decoration: const InputDecoration(labelText: 'Written text'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              key: const Key('pronunciation-reading'),
              controller: reading,
              decoration: const InputDecoration(labelText: 'Spoken reading'),
              onChanged: (_) => setState(() {}),
            ),
            DropdownButtonFormField<PronunciationScope>(
              initialValue: scope,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: [
                for (final value in PronunciationScope.values)
                  DropdownMenuItem(value: value, child: Text(value.name)),
              ],
              onChanged: (value) => setState(() => scope = value!),
            ),
            if (scope != PronunciationScope.global)
              TextField(
                controller: scopeId,
                decoration: InputDecoration(labelText: '${scope.name} ID'),
                onChanged: (_) => setState(() {}),
              ),
            TextField(
              controller: priority,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Priority'),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Override overlapping Pixiv ruby'),
              value: overrideRuby,
              onChanged: (value) => setState(() => overrideRuby = value),
            ),
            const Divider(),
            Text('Display: ${projection?.displayText ?? '—'}'),
            Text('Spoken: ${projection?.spokenText ?? '—'}'),
            Text(
              'SSML: ${projection?.ssml ?? '—'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: draft == null
                      ? null
                      : () => Navigator.pop(context, draft),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
