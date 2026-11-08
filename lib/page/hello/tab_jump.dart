import 'package:material_ui/material_ui.dart';

/// A one-shot request to show a tab of a page that may not be built yet,
/// e.g. a bottom bar shortcut opening the rank page on its weekly tab.
class TabJumpRequest extends ChangeNotifier {
  int? _pending;

  void request(int index) {
    _pending = index;
    notifyListeners();
  }

  /// Returns the pending index once, then forgets it.
  int? take() {
    final index = _pending;
    _pending = null;
    return index;
  }
}

class TabJumps {
  static final illustRank = TabJumpRequest();
  static final illustNews = TabJumpRequest();
  static final novelRank = TabJumpRequest();
  static final novelNews = TabJumpRequest();
}

/// Moves [controller], or the enclosing [DefaultTabController], to the tabs
/// [request] asks for, including one asked for before this was built.
class TabJumpListener extends StatefulWidget {
  const TabJumpListener({
    super.key,
    required this.request,
    required this.child,
    this.controller,
    this.onJump,
  });

  final TabJumpRequest request;
  final TabController? controller;
  final ValueChanged<int>? onJump;
  final Widget child;

  @override
  State<TabJumpListener> createState() => _TabJumpListenerState();
}

class _TabJumpListenerState extends State<TabJumpListener> {
  @override
  void initState() {
    super.initState();
    widget.request.addListener(_jump);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  @override
  void didUpdateWidget(TabJumpListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) {
      oldWidget.request.removeListener(_jump);
      widget.request.addListener(_jump);
    }
  }

  @override
  void dispose() {
    widget.request.removeListener(_jump);
    super.dispose();
  }

  void _jump() {
    if (!mounted) return;
    final controller =
        widget.controller ?? DefaultTabController.maybeOf(context);
    if (controller == null) return;
    final index = widget.request.take();
    if (index == null || index < 0 || index >= controller.length) return;
    controller.animateTo(index);
    widget.onJump?.call(index);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
