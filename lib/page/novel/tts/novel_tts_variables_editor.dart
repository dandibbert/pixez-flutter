import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

const novelTtsAddVariableKey = Key('novelTtsAddVariable');

class NovelTtsVariablesEditor extends StatefulWidget {
  const NovelTtsVariablesEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onValidityChanged,
    this.legacyVoiceFieldKey,
  });

  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onChanged;
  final ValueChanged<bool> onValidityChanged;
  final Key? legacyVoiceFieldKey;

  @override
  State<NovelTtsVariablesEditor> createState() =>
      _NovelTtsVariablesEditorState();
}

class _VariableRow {
  _VariableRow(String name, String value)
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);
  final TextEditingController name;
  final TextEditingController value;
  final key = UniqueKey();
  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _NovelTtsVariablesEditorState extends State<NovelTtsVariablesEditor> {
  late final List<_VariableRow> _rows = [
    for (final entry in widget.initial.entries)
      _VariableRow(entry.key, entry.value),
  ];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String? _error(BuildContext context, _VariableRow row) {
    final name = row.name.text.trim().toLowerCase();
    final i18n = I18n.of(context);
    if (name.isEmpty || !novelTtsVariableNamePattern.hasMatch(name)) {
      return i18n.novel_tts_variable_name_invalid;
    }
    if (name == 'text') return i18n.novel_tts_variable_text_reserved;
    if (_rows
            .where((other) => other.name.text.trim().toLowerCase() == name)
            .length >
        1) {
      return i18n.novel_tts_variable_name_duplicate;
    }
    return null;
  }

  void _changed() {
    setState(() {});
    final valid = !_rows.any((row) => _error(context, row) != null);
    widget.onValidityChanged(valid);
    if (!valid) return;
    widget.onChanged({
      for (final row in _rows)
        row.name.text.trim().toLowerCase(): row.value.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(i18n.novel_tts_variables_hint),
        const SizedBox(height: 12),
        for (final row in _rows)
          Padding(
            key: row.key,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey(
                          'novelTtsVariableName_${_rows.indexOf(row)}',
                        ),
                        controller: row.name,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: i18n.novel_tts_variable_name,
                          hintText: 'speaker_id',
                          errorText: _error(context, row),
                          errorMaxLines: 3,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                        'novelTtsRemoveVariable_${_rows.indexOf(row)}',
                      ),
                      tooltip: i18n.novel_tts_variable_remove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => _rows.remove(row));
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => row.dispose(),
                        );
                        _changed();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: row.name.text.trim().toLowerCase() == 'voice'
                      ? widget.legacyVoiceFieldKey
                      : ValueKey('novelTtsVariableValue_${_rows.indexOf(row)}'),
                  controller: row.value,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: i18n.novel_tts_variable_value,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _changed(),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: novelTtsAddVariableKey,
            icon: const Icon(Icons.add),
            label: Text(i18n.novel_tts_variable_add),
            onPressed: () {
              setState(() => _rows.add(_VariableRow('', '')));
              _changed();
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
