import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/viewer/installed_fonts.dart';
import 'package:pixez/page/novel/viewer/novel_custom_font.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';

const Key novelFontPickerKey = Key('novelFontPicker');
const Key novelFontSearchKey = Key('novelFontSearch');
const Key novelFontDefaultKey = Key('novelFontDefault');
const Key novelFontImportKey = Key('novelFontImport');

class NovelFontChoice {
  final String family;
  final String? filePath;

  const NovelFontChoice(this.family, {this.filePath});
}

class NovelFontPickerPage extends StatefulWidget {
  final String selectedFamily;
  final String? selectedFilePath;
  final List<String>? families;
  final Future<List<String>> Function()? loadFamilies;
  final Future<NovelImportedFont?> Function()? importFont;

  const NovelFontPickerPage({
    super.key,
    required this.selectedFamily,
    this.selectedFilePath,
    this.families,
    this.loadFamilies,
    this.importFont,
  });

  @override
  State<NovelFontPickerPage> createState() => _NovelFontPickerPageState();
}

class _NovelFontPickerPageState extends State<NovelFontPickerPage> {
  final TextEditingController _search = TextEditingController();
  List<String> _families = const <String>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final families =
          widget.families ??
          await (widget.loadFamilies ?? InstalledFonts.listFamilies)();
      if (!mounted) {
        return;
      }
      setState(() {
        _families = InstalledFonts.mergeSelected(
          families,
          widget.selectedFamily,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _select(NovelFontChoice choice) {
    Navigator.of(context).pop(choice);
  }

  Future<void> _import() async {
    try {
      final imported = await (widget.importFont ??
          NovelCustomFont.importPickedFile)();
      if (!mounted || imported == null) {
        return;
      }
      _select(
        NovelFontChoice(imported.family, filePath: imported.filePath),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.of(context).novel_font_import_failed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final visible = InstalledFonts.filterFamilies(_families, _search.text);
    return Scaffold(
      key: novelFontPickerKey,
      appBar: AppBar(
        title: Text(i18n.novel_font),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: novelFontSearchKey,
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: i18n.novel_font_search,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          ListTile(
            key: novelFontDefaultKey,
            leading: Icon(
              NovelReaderStyle.isDefaultFamily(widget.selectedFamily)
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(i18n.novel_font_default),
            onTap: () => _select(const NovelFontChoice('')),
          ),
          ListTile(
            key: novelFontImportKey,
            leading: const Icon(Icons.file_open_outlined),
            title: Text(i18n.novel_font_import),
            onTap: _import,
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final family = visible[index];
                      final selected = family == widget.selectedFamily;
                      return ListTile(
                        key: Key('novelFontFamily_$family'),
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(
                          NovelCustomFont.displayName(family),
                          style: TextStyle(fontFamily: family),
                        ),
                        subtitle: Text(
                          NovelCustomFont.isImportedFamily(family)
                              ? i18n.novel_font_imported
                              : '本文プレビュー Preview 预览',
                          style: TextStyle(fontFamily: family, fontSize: 13),
                        ),
                        onTap: () => _select(
                          NovelFontChoice(
                            family,
                            filePath: family == widget.selectedFamily
                                ? widget.selectedFilePath
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
