import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 为局部横向分页视图补充桌面鼠标拖动，同时保留当前主题的滚动行为。
class MouseDragScrollConfiguration extends StatelessWidget {
  const MouseDragScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: child,
    );
  }
}
