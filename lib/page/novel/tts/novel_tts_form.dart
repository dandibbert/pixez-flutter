import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

const Key novelTtsAdvancedToggleKey = Key('novelTtsAdvancedToggle');
const Key novelTtsAddHeaderKey = Key('novelTtsAddHeader');
const Key novelTtsHeaderNameFieldKey = Key('novelTtsHeaderName');
const Key novelTtsHeaderValueFieldKey = Key('novelTtsHeaderValue');
const Key novelTtsInsertTextChipKey = Key('novelTtsInsertText');

class NovelTtsChoice {
  const NovelTtsChoice(this.value, this.label);

  final String value;
  final String label;
}

const microsoftVoiceChoices = <NovelTtsChoice>[
  NovelTtsChoice('zh-CN-XiaoxiaoNeural', 'Xiaoxiao'),
  NovelTtsChoice('zh-CN-YunxiNeural', 'Yunxi'),
  NovelTtsChoice('zh-CN-YunjianNeural', 'Yunjian'),
  NovelTtsChoice('zh-TW-HsiaoChenNeural', 'HsiaoChen'),
  NovelTtsChoice('ja-JP-NanamiNeural', 'Nanami'),
  NovelTtsChoice('ja-JP-KeitaNeural', 'Keita'),
  NovelTtsChoice('en-US-JennyNeural', 'Jenny'),
  NovelTtsChoice('en-US-GuyNeural', 'Guy'),
  NovelTtsChoice('ko-KR-SunHiNeural', 'SunHi'),
];

const microsoftRegionChoices = <NovelTtsChoice>[
  NovelTtsChoice('eastasia', 'eastasia'),
  NovelTtsChoice('japaneast', 'japaneast'),
  NovelTtsChoice('japanwest', 'japanwest'),
  NovelTtsChoice('southeastasia', 'southeastasia'),
  NovelTtsChoice('eastus', 'eastus'),
  NovelTtsChoice('westus', 'westus'),
  NovelTtsChoice('westeurope', 'westeurope'),
];

const microsoftLanguageChoices = <NovelTtsChoice>[
  NovelTtsChoice('zh-CN', 'zh-CN'),
  NovelTtsChoice('zh-TW', 'zh-TW'),
  NovelTtsChoice('ja-JP', 'ja-JP'),
  NovelTtsChoice('en-US', 'en-US'),
  NovelTtsChoice('ko-KR', 'ko-KR'),
];

const openaiModelChoices = <NovelTtsChoice>[
  NovelTtsChoice('tts-1', 'tts-1'),
  NovelTtsChoice('tts-1-hd', 'tts-1-hd'),
  NovelTtsChoice('gpt-4o-mini-tts', 'gpt-4o-mini-tts'),
];

const openaiVoiceChoices = <NovelTtsChoice>[
  NovelTtsChoice('alloy', 'alloy'),
  NovelTtsChoice('ash', 'ash'),
  NovelTtsChoice('coral', 'coral'),
  NovelTtsChoice('echo', 'echo'),
  NovelTtsChoice('fable', 'fable'),
  NovelTtsChoice('nova', 'nova'),
  NovelTtsChoice('onyx', 'onyx'),
  NovelTtsChoice('sage', 'sage'),
  NovelTtsChoice('shimmer', 'shimmer'),
];

const contentTypeChoices = <NovelTtsChoice>[
  NovelTtsChoice('application/json', 'application/json'),
  NovelTtsChoice('application/x-www-form-urlencoded', 'form'),
  NovelTtsChoice('text/plain', 'text/plain'),
];

const novelTtsPlaceholderTokens = <String>[
  'text',
  'voice',
  'lang',
  'speed',
  'model',
];

double parseMicrosoftRatePercent(String raw) {
  final match = RegExp(r'([+-]?\d+)').firstMatch(raw.trim());
  return (double.tryParse(match?.group(1) ?? '0') ?? 0).clamp(-50, 50);
}

String formatMicrosoftRatePercent(double value) {
  final pct = value.round();
  return pct >= 0 ? '+$pct%' : '$pct%';
}

String? languageFromMicrosoftVoice(String voice) {
  final match = RegExp(r'^([a-z]{2}-[A-Z]{2})').firstMatch(voice.trim());
  return match?.group(1);
}

void insertNovelTtsToken(TextEditingController controller, String token) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : text.length;
  final end = selection.isValid ? selection.end : text.length;
  final next = text.replaceRange(start, end, token);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + token.length),
  );
}

class NovelTtsChoiceField extends StatelessWidget {
  const NovelTtsChoiceField({
    super.key,
    required this.label,
    required this.controller,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final List<NovelTtsChoice> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in choices)
                ChoiceChip(
                  label: Text(choice.label),
                  selected: current == choice.value,
                  onSelected: (_) {
                    controller.text = choice.value;
                    onChanged(choice.value);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NovelTtsPlaceholderChips extends StatelessWidget {
  const NovelTtsPlaceholderChips({
    super.key,
    required this.caption,
    required this.onInsert,
  });

  final String caption;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in novelTtsPlaceholderTokens)
                ActionChip(
                  key: name == 'text' ? novelTtsInsertTextChipKey : null,
                  label: Text('{$name}'),
                  onPressed: () => onInsert('{$name}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NovelTtsAdvancedPanel extends StatefulWidget {
  const NovelTtsAdvancedPanel({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  State<NovelTtsAdvancedPanel> createState() => _NovelTtsAdvancedPanelState();
}

class _NovelTtsAdvancedPanelState extends State<NovelTtsAdvancedPanel> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: novelTtsAdvancedToggleKey,
          contentPadding: EdgeInsets.zero,
          title: Text(widget.title),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

class NovelTtsHeaderListEditor extends StatefulWidget {
  const NovelTtsHeaderListEditor({
    super.key,
    required this.initial,
    required this.nameLabel,
    required this.valueLabel,
    required this.addLabel,
    required this.onChanged,
  });

  final String initial;
  final String nameLabel;
  final String valueLabel;
  final String addLabel;
  final ValueChanged<String> onChanged;

  @override
  State<NovelTtsHeaderListEditor> createState() =>
      _NovelTtsHeaderListEditorState();
}

class _HeaderRow {
  _HeaderRow(String name, String value)
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _NovelTtsHeaderListEditorState extends State<NovelTtsHeaderListEditor> {
  late List<_HeaderRow> _rows;

  @override
  void initState() {
    super.initState();
    final parsed = parseNovelTtsHeaderLines(widget.initial);
    _rows = [
      for (final entry in parsed.entries) _HeaderRow(entry.key, entry.value),
    ];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final headers = <String, String>{};
    for (final row in _rows) {
      final name = row.name.text.trim();
      if (name.isEmpty) {
        continue;
      }
      headers[name] = row.value.text.trim();
    }
    widget.onChanged(serializeNovelTtsHeaderLines(headers));
  }

  void _add() {
    setState(() {
      _rows.add(_HeaderRow('', ''));
    });
  }

  void _remove(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: i == 0 ? novelTtsHeaderNameFieldKey : null,
                    controller: _rows[i].name,
                    decoration: InputDecoration(
                      labelText: widget.nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: i == 0 ? novelTtsHeaderValueFieldKey : null,
                    controller: _rows[i].value,
                    decoration: InputDecoration(
                      labelText: widget.valueLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(i),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: novelTtsAddHeaderKey,
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
