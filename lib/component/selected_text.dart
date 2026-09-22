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
    if (next.isEmpty) {
      return;
    }
    value = next;
  }
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
