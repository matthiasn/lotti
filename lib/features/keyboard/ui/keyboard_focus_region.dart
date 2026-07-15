import 'package:flutter/widgets.dart';

/// Ordered registry used by F6/Shift+F6 desktop pane traversal.
class KeyboardFocusRegionController extends ChangeNotifier {
  final List<_KeyboardFocusRegionNode> _regions = [];

  void _register(_KeyboardFocusRegionNode node) {
    if (_regions.contains(node)) return;
    _regions.add(node);
  }

  void _unregister(_KeyboardFocusRegionNode node) {
    _regions.remove(node);
  }

  bool focusNext({bool reverse = false}) {
    final active = _regions.where((region) => region.enabled).toList();
    if (active.isEmpty) return false;
    final currentIndex = active.indexWhere((region) => region.containsFocus);
    var nextIndex = currentIndex == -1
        ? (reverse ? active.length - 1 : 0)
        : reverse
        ? (currentIndex - 1 + active.length) % active.length
        : (currentIndex + 1) % active.length;
    for (var i = 0; i < active.length; i++) {
      if (active[nextIndex].requestFocus()) return true;
      nextIndex = reverse
          ? (nextIndex - 1 + active.length) % active.length
          : (nextIndex + 1) % active.length;
    }
    return false;
  }
}

class KeyboardFocusRegionRegistry
    extends InheritedNotifier<KeyboardFocusRegionController> {
  const KeyboardFocusRegionRegistry({
    required KeyboardFocusRegionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static KeyboardFocusRegionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<KeyboardFocusRegionRegistry>()
      ?.notifier;
}

/// A desktop pane that participates in F6 traversal and remembers its last
/// focused descendant.
class KeyboardFocusRegion extends StatefulWidget {
  const KeyboardFocusRegion({
    required this.debugLabel,
    required this.child,
    this.preferredFocusNode,
    this.enabled = true,
    super.key,
  });

  final String debugLabel;
  final Widget child;
  final FocusNode? preferredFocusNode;
  final bool enabled;

  @override
  State<KeyboardFocusRegion> createState() => _KeyboardFocusRegionState();
}

class _KeyboardFocusRegionState extends State<KeyboardFocusRegion> {
  late final FocusScopeNode _scopeNode = FocusScopeNode(
    debugLabel: widget.debugLabel,
  );
  late final _KeyboardFocusRegionNode _node = _KeyboardFocusRegionNode(
    scopeNode: _scopeNode,
    preferredFocusNode: widget.preferredFocusNode,
    enabled: widget.enabled,
  );
  KeyboardFocusRegionController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = KeyboardFocusRegionRegistry.maybeOf(context);
    if (_controller != controller) {
      _controller?._unregister(_node);
      _controller = controller;
      controller?._register(_node);
    }
  }

  @override
  void didUpdateWidget(covariant KeyboardFocusRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _node
      ..enabled = widget.enabled
      ..preferredFocusNode = widget.preferredFocusNode;
  }

  @override
  void dispose() {
    _controller?._unregister(_node);
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: !widget.enabled,
      child: FocusTraversalGroup(
        child: FocusScope(node: _scopeNode, child: widget.child),
      ),
    );
  }
}

class _KeyboardFocusRegionNode {
  _KeyboardFocusRegionNode({
    required this.scopeNode,
    required this.preferredFocusNode,
    required this.enabled,
  });

  final FocusScopeNode scopeNode;
  FocusNode? preferredFocusNode;
  bool enabled;

  bool get containsFocus {
    final primary = FocusManager.instance.primaryFocus;
    return primary == scopeNode ||
        (primary?.ancestors.contains(scopeNode) ?? false);
  }

  bool requestFocus() {
    final preferred = preferredFocusNode;
    if (preferred != null && preferred.canRequestFocus) {
      preferred.requestFocus();
      return true;
    }
    final previous = scopeNode.focusedChild;
    if (previous != null && previous.canRequestFocus) {
      previous.requestFocus();
      return true;
    }
    for (final descendant in scopeNode.traversalDescendants) {
      if (descendant.canRequestFocus && !descendant.skipTraversal) {
        descendant.requestFocus();
        return true;
      }
    }
    return false;
  }
}
