import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';

/// Focus bridge exposed to rows inside a [ListDetailFocusTraversal].
final class ListDetailFocusTraversalController {
  const ListDetailFocusTraversalController._(
    this._focusList,
    this._focusDetails,
    this._listPaneVisible,
    this._canHideListPane,
    this._setListPaneVisible,
  );

  final VoidCallback _focusList;
  final VoidCallback _focusDetails;
  final bool Function() _listPaneVisible;
  final bool Function() _canHideListPane;
  final ValueChanged<bool> _setListPaneVisible;

  /// Whether the browse list is currently visible beside the detail pane.
  bool get listPaneVisible => _listPaneVisible();

  /// Whether the current detail state can safely enter list-free focus mode.
  bool get canHideListPane => _canHideListPane();

  /// Reveals the list pane and transfers keyboard focus back into it.
  void showListPane() {
    if (listPaneVisible) return;
    _setListPaneVisible(true);
    _focusList();
  }

  /// Hides the list pane and transfers keyboard focus into the detail pane.
  void hideListPane() {
    if (!listPaneVisible || !canHideListPane) return;
    _setListPaneVisible(false);
    _focusDetails();
  }

  /// Moves focus from the list pane into the detail pane.
  void focusDetails() => _focusDetails();
}

/// A desktop list/divider/detail layout with explicit pane focus ownership.
///
/// The list and detail panes participate in a private two-region registry, so
/// a focused list row can enter the detail pane without directional traversal
/// landing on the intervening resize handle. The divider remains independently
/// focusable for deliberate keyboard resizing. Hosts may also hide the list
/// and divider offstage without disposing their subtree; the controller then
/// transfers focus to the visible region as focus mode changes.
class ListDetailFocusTraversal extends StatefulWidget {
  const ListDetailFocusTraversal({
    required this.debugLabel,
    required this.listPane,
    required this.divider,
    required this.detailPane,
    this.listPaneVisible = true,
    this.canHideListPane = false,
    this.onListPaneVisibilityChanged,
    super.key,
  });

  final String debugLabel;
  final Widget listPane;
  final Widget divider;
  final Widget detailPane;
  final bool listPaneVisible;
  final bool canHideListPane;
  final ValueChanged<bool>? onListPaneVisibilityChanged;

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
  final _listRegionId = Object();
  final _detailRegionId = Object();
  late final _controller = ListDetailFocusTraversalController._(
    _focusList,
    _focusDetails,
    () => widget.listPaneVisible,
    () => widget.canHideListPane,
    (visible) => widget.onListPaneVisibilityChanged?.call(visible),
  );

  void _focusList() => _focusRegion(_listRegionId);

  void _focusDetails() => _focusRegion(_detailRegionId);

  void _focusRegion(Object regionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusRegionController.focusRegion(regionId);
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
      listPaneVisible: widget.listPaneVisible,
      canHideListPane: widget.canHideListPane,
      child: KeyboardFocusRegionRegistry(
        controller: _focusRegionController,
        child: Row(
          children: [
            KeyboardFocusRegion(
              debugLabel: '${widget.debugLabel}-list',
              regionId: _listRegionId,
              child: Offstage(
                offstage: !widget.listPaneVisible,
                child: ExcludeFocus(
                  excluding: !widget.listPaneVisible,
                  child: ExcludeSemantics(
                    excluding: !widget.listPaneVisible,
                    child: widget.listPane,
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: !widget.listPaneVisible,
              child: widget.divider,
            ),
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
    required this.listPaneVisible,
    required this.canHideListPane,
    required super.child,
  });

  final ListDetailFocusTraversalController controller;
  final bool listPaneVisible;
  final bool canHideListPane;

  @override
  bool updateShouldNotify(_ListDetailFocusTraversalScope oldWidget) =>
      controller != oldWidget.controller ||
      listPaneVisible != oldWidget.listPaneVisible ||
      canHideListPane != oldWidget.canHideListPane;
}
