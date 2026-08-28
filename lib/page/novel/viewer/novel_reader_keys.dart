import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum NovelReaderKeyAction {
  prevPage,
  nextPage,
  firstPage,
  lastPage,
  jumpToPage,
  goBack,
  scrollUp,
  scrollDown,
}

/// Maps desktop keys to reader actions. Typing in a dialog/field is ignored.
/// Space / PageDown scroll the article first, then turn the page.
NovelReaderKeyAction? resolveNovelReaderKey({
  required LogicalKeyboardKey key,
  required bool isEditingText,
  required bool hasModifier,
  required bool canScrollUp,
  required bool canScrollDown,
  bool isRepeat = false,
}) {
  if (isEditingText || hasModifier) {
    return null;
  }

  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.pageDown ||
      key == LogicalKeyboardKey.arrowDown) {
    return canScrollDown
        ? NovelReaderKeyAction.scrollDown
        : NovelReaderKeyAction.nextPage;
  }
  if (key == LogicalKeyboardKey.pageUp ||
      key == LogicalKeyboardKey.arrowUp) {
    return canScrollUp
        ? NovelReaderKeyAction.scrollUp
        : NovelReaderKeyAction.prevPage;
  }

  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.keyA ||
      key == LogicalKeyboardKey.keyH ||
      key == LogicalKeyboardKey.keyK ||
      key == LogicalKeyboardKey.bracketLeft) {
    return NovelReaderKeyAction.prevPage;
  }
  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.keyD ||
      key == LogicalKeyboardKey.keyL ||
      key == LogicalKeyboardKey.keyJ ||
      key == LogicalKeyboardKey.bracketRight) {
    return NovelReaderKeyAction.nextPage;
  }

  if (isRepeat) {
    return null;
  }
  if (key == LogicalKeyboardKey.home) {
    return NovelReaderKeyAction.firstPage;
  }
  if (key == LogicalKeyboardKey.end) {
    return NovelReaderKeyAction.lastPage;
  }
  if (key == LogicalKeyboardKey.keyG) {
    return NovelReaderKeyAction.jumpToPage;
  }
  if (key == LogicalKeyboardKey.escape) {
    return NovelReaderKeyAction.goBack;
  }
  return null;
}

bool novelReaderCanScroll(ScrollMetrics? metrics, double direction) {
  if (metrics == null || !metrics.hasContentDimensions) {
    return false;
  }
  if (direction > 0) {
    return metrics.pixels < metrics.maxScrollExtent - 1;
  }
  return metrics.pixels > metrics.minScrollExtent + 1;
}

bool novelReaderHasModifier(Set<LogicalKeyboardKey> pressed) {
  return pressed.contains(LogicalKeyboardKey.controlLeft) ||
      pressed.contains(LogicalKeyboardKey.controlRight) ||
      pressed.contains(LogicalKeyboardKey.metaLeft) ||
      pressed.contains(LogicalKeyboardKey.metaRight) ||
      pressed.contains(LogicalKeyboardKey.altLeft) ||
      pressed.contains(LogicalKeyboardKey.altRight) ||
      pressed.contains(LogicalKeyboardKey.shiftLeft) ||
      pressed.contains(LogicalKeyboardKey.shiftRight);
}

bool novelReaderIsEditingText(FocusNode? primaryFocus) {
  var node = primaryFocus;
  while (node != null) {
    final context = node.context;
    if (context != null) {
      if (context.widget is EditableText ||
          context.findAncestorWidgetOfExactType<EditableText>() != null) {
        return true;
      }
    }
    node = node.parent;
  }
  return false;
}
