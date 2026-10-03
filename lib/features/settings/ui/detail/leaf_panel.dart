import 'package:flutter/foundation.dart';
import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:lotti/features/settings/ui/detail/settings_panel_host.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Detail-pane wrapper for the selected node's panel.
///
/// Hosts the panel through [SettingsPanelHost] and keeps every panel visited
/// since the pane mounted alive in an [IndexedStack], so switching between
/// siblings preserves their state — scroll position, a typed filter, loaders
/// in flight. Without it, the `AnimatedSwitcher` above in
/// `SettingsDetailPane` would tear a body down on every selection change.
///
/// The body fills the whole pane: no breadcrumb, title or gutter is added
/// here. The breadcrumb in the desktop page header is the only "where am I",
/// and each panel owns its own padding; anything added here would come out of
/// the panel's usable width.
class LeafPanel extends StatefulWidget {
  const LeafPanel({
    required this.nodeId,
    this.table,
    this.listenable,
    super.key,
  });

  /// Tree node id of the selected node.
  final String nodeId;

  /// Test-only overrides passed through to every [SettingsPanelHost].
  @visibleForTesting
  final SettingsRouteTable? table;
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  State<LeafPanel> createState() => _LeafPanelState();
}

class _LeafPanelState extends State<LeafPanel> {
  /// Node ids in first-visit order; a node's position is its child index in
  /// the [IndexedStack].
  final List<String> _visitedIds = <String>[];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = _visit(widget.nodeId);
  }

  @override
  void didUpdateWidget(LeafPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = _visit(widget.nodeId);
  }

  int _visit(String id) {
    final index = _visitedIds.indexOf(id);
    if (index != -1) return index;
    _visitedIds.add(id);
    return _visitedIds.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _current,
      sizing: StackFit.expand,
      children: [
        for (final id in _visitedIds)
          KeyedSubtree(
            key: ValueKey('leaf-body:$id'),
            child: SettingsPanelHost(
              nodeId: id,
              table: widget.table,
              listenable: widget.listenable,
            ),
          ),
      ],
    );
  }
}
