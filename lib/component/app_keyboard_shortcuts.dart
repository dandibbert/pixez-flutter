import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 应用内统一的桌面键盘快捷键作用域。
class AppKeyboardShortcuts extends StatelessWidget {
  const AppKeyboardShortcuts({
    super.key,
    required this.child,
    this.onEscape,
    this.onMetaI,
    this.onArrowLeft,
    this.onArrowRight,
  });

  final Widget child;
  final VoidCallback? onEscape;
  final VoidCallback? onMetaI;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      if (onEscape != null)
        const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
            onEscape!,
      if (onMetaI != null)
        const SingleActivator(
          LogicalKeyboardKey.keyI,
          meta: true,
          includeRepeats: false,
        ): onMetaI!,
      if (onArrowLeft != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          includeRepeats: false,
        ): onArrowLeft!,
      if (onArrowRight != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          includeRepeats: false,
        ): onArrowRight!,
    };
    if (bindings.isEmpty) return child;
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}
