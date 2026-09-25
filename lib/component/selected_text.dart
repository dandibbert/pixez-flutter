import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/supportor_plugin.dart';
import 'package:share_plus/share_plus.dart';

/// Remembers the last non-empty selection.
///
/// On iOS 27 the system text-selection gesture clears the [SelectionArea]
/// before a context-menu action runs. [SelectedContent.plainText] is then
/// empty, so reading it inside the button handler shares or copies nothing.
/// Keeping the last real selection lets Copy and Translate use the text the
/// menu was built for.
class SelectedTextMemory {
  String value = '';

  void update(SelectedContent? content) {
    final next = selectedPlainText(content);
    publishSelectedContent(content);
    if (next.isEmpty) {
      return;
    }
    value = next;
  }
}

/// Publishes the live selection to iOS so Shortcuts can read it.
///
/// "Get Selected Text" reads the foreground view's selected text. A Flutter
/// [SelectionArea] draws its own highlight and never installs that selection.
void publishSelectedContent(SelectedContent? content) {
  SelectedTextChannel.publish(selectedPlainText(content));
}

/// Selection area that reports its highlight to the iOS Shortcuts action.
class ShortcutSelectionArea extends StatelessWidget {
  const ShortcutSelectionArea({
    super.key,
    this.focusNode,
    this.onSelectionChanged,
    this.contextMenuBuilder,
    required this.child,
  });

  final FocusNode? focusNode;
  final ValueChanged<SelectedContent?>? onSelectionChanged;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      focusNode: focusNode,
      contextMenuBuilder: contextMenuBuilder,
      onSelectionChanged: (SelectedContent? content) {
        publishSelectedContent(content);
        onSelectionChanged?.call(content);
      },
      child: child,
    );
  }
}

/// Sends the current plain-text selection to the iOS runner.
class SelectedTextChannel {
  static const MethodChannel channel = MethodChannel('pixez/selected_text');

  /// Tests set this so the channel can be observed off iOS.
  static bool enabled = Platform.isIOS;

  static String? _last;

  static void publish(String text) {
    if (text == _last) {
      return;
    }
    _last = text;
    if (!enabled) {
      return;
    }
    unawaited(_send(text));
    if (Platform.isIOS) {
      ShortcutTextInput.mirror(text);
    }
  }

  static Future<void> _send(String text) async {
    try {
      await channel.invokeMethod<void>('setSelectedText', text);
    } catch (_) {}
  }

  @visibleForTesting
  static void reset() {
    _last = null;
  }
}

/// Mirrors the highlight into the engine text input the system already queries.
class ShortcutTextInput {
  static final _ShortcutTextClient _client = _ShortcutTextClient();
  static TextInputConnection? _connection;
  static Timer? _clearTimer;

  static void mirror(String text) {
    if (_realEditorFocused()) {
      return;
    }
    if (text.isEmpty) {
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(seconds: 8), _closeIfOurs);
      return;
    }
    _clearTimer?.cancel();
    final TextEditingValue value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _client.value = value;
    final TextInputConnection? current = _connection;
    if (current == null || !current.attached) {
      final TextInputConnection next = TextInput.attach(
        _client,
        _configuration,
      );
      _connection = next;
      next
        ..setEditingState(value)
        ..show();
      return;
    }
    current
      ..setEditingState(value)
      ..show();
  }

  static void _closeIfOurs() {
    final TextInputConnection? current = _connection;
    _connection = null;
    if (current != null && current.attached) {
      current.close();
    }
  }

  static bool _realEditorFocused() {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    return context.findAncestorStateOfType<EditableTextState>() != null;
  }
}

const TextInputConfiguration _configuration = TextInputConfiguration(
  inputType: TextInputType.none,
  autocorrect: false,
  enableSuggestions: false,
  smartDashesType: SmartDashesType.disabled,
  smartQuotesType: SmartQuotesType.disabled,
);

class _ShortcutTextClient with TextInputClient {
  TextEditingValue? value;

  @override
  TextEditingValue? get currentTextEditingValue => value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    this.value = value;
  }

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {}
}

String selectedPlainText(SelectedContent? content) {
  return (content?.plainText ?? '').replaceAll('\uFFFC', '');
}

AdaptiveTextSelectionToolbar buildTextSelectionToolbar({
  required BuildContext context,
  required SelectableRegionState region,
  required String selectedText,
  required bool offerTextAction,
  required String actionLabel,
}) {
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: region.contextMenuAnchors,
    buttonItems: selectionMenuButtons(
      context: context,
      region: region,
      selectedText: selectedText,
      offerTextAction: offerTextAction,
      actionLabel: actionLabel,
    ),
  );
}

List<ContextMenuButtonItem> selectionMenuButtons({
  required BuildContext context,
  required SelectableRegionState region,
  required String selectedText,
  required bool offerTextAction,
  required String actionLabel,
  bool? ios,
}) {
  final useIosActions = ios ?? Platform.isIOS;
  final buttons = <ContextMenuButtonItem>[
    for (final item in region.contextMenuButtonItems)
      if (item.type == ContextMenuButtonType.copy && useIosActions)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () {
            _copyCaptured(selectedText, item.onPressed);
          },
        )
      else
        item,
  ];
  if (offerTextAction && selectedText.trim().isNotEmpty) {
    buttons.add(
      ContextMenuButtonItem(
        label: actionLabel,
        onPressed: () {
          if (useIosActions) {
            shareCapturedText(context, selectedText);
            return;
          }
          SupportorPlugin.start(selectedText);
          ContextMenuController.removeAny();
        },
      ),
    );
  }
  return buttons;
}

void _copyCaptured(String selectedText, VoidCallback? fallback) {
  final text = selectedText.trim();
  if (text.isEmpty) {
    fallback?.call();
    return;
  }
  Clipboard.setData(ClipboardData(text: text));
  ContextMenuController.removeAny();
}

Future<void> shareCapturedText(
  BuildContext context,
  String selectedText,
) async {
  final text = selectedText.trim();
  if (text.isEmpty) {
    return;
  }
  final box = context.findRenderObject();
  Rect? origin;
  if (box is RenderBox && box.hasSize && box.size.longestSide > 0) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }
  origin ??= Rect.fromCenter(
    center: Offset(
      MediaQuery.sizeOf(context).width / 2,
      MediaQuery.sizeOf(context).height / 2,
    ),
    width: 2,
    height: 2,
  );
  ContextMenuController.removeAny();
  await SharePlus.instance.share(
    ShareParams(text: text, sharePositionOrigin: origin),
  );
}
