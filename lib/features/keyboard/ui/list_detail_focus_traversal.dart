import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';

/// Focus bridge exposed to rows inside a [ListDetailFocusTraversal].
final class ListDetailFocusTraversalController {
  const ListDetailFocusTraversalController._(this._focusDetails);

  final VoidCallback _focusDetails;

  /// Moves focus from the list pane into the detail pane.
  void focusDetails() => _focusDetails();
}

/// A desktop list/divider/detail layout with explicit pane focus ownership.
///
/// The list and detail panes participate in a private two-region registry, so
/// a focused list row can enter the detail pane without directional traversal
/// landing on the intervening resize handle. The divider remains independently
/// focusable for deliberate keyboard resizing.
class ListDetailFocusTraversal extends StatefulWidget {
  const ListDetailFocusTraversal({
    required this.debugLabel,
    required this.listPane,
    required this.divider,
    required this.detailPane,
    super.key,
  });

  final String debugLabel;
  final Widget listPane;
  final Widget divider;
  final Widget detailPane;

  static ListDetailFocusTraversalController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ListDetailFocusTraversalScope>()
          ?.controller;

  @override
  State<ListDetailFocusTraversal> createState() =>
      _ListDetailFocusTraversalState();
}

class _ListDetailFocusTraversalState extends State<ListDetailFocusTraversal> {
  final _focusRegionController = KeyboardFocusRegionController();
  final _detailRegionId = Object();
  late final _controller = ListDetailFocusTraversalController._(_focusDetails);

  void _focusDetails() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusRegionController.focusRegion(_detailRegionId);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _focusRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ListDetailFocusTraversalScope(
      controller: _controller,
      child: KeyboardFocusRegionRegistry(
        controller: _focusRegionController,
        child: Row(
          children: [
            KeyboardFocusRegion(
              debugLabel: '${widget.debugLabel}-list',
              child: widget.listPane,
            ),
            widget.divider,
            Expanded(
              child: KeyboardFocusRegion(
                debugLabel: '${widget.debugLabel}-detail',
                regionId: _detailRegionId,
                child: widget.detailPane,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListDetailFocusTraversalScope extends InheritedWidget {
  const _ListDetailFocusTraversalScope({
    required this.controller,
    required super.child,
  });

  final ListDetailFocusTraversalController controller;

  @override
  bool updateShouldNotify(_ListDetailFocusTraversalScope oldWidget) =>
      controller != oldWidget.controller;
}
