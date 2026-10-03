import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/domain/settings_tree_index.dart';
import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';
import 'package:lotti/features/settings/state/settings_tree_controller.dart';
import 'package:lotti/features/settings/ui/detail/category_empty.dart';
import 'package:lotti/features/settings/ui/detail/empty_root.dart';
import 'package:lotti/features/settings/ui/detail/leaf_panel.dart';
import 'package:lotti/features/settings/ui/settings_tree_builder.dart';
import 'package:lotti/features/settings/ui/settings_tree_scope.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Cross-fade duration between detail-pane states.
const Duration kSettingsDetailPaneSwap = Duration(milliseconds: 180);

/// Dispatches the right-hand detail surface of the desktop settings page
/// from the current `settingsTreePathProvider` state:
///
/// - Empty path → [EmptyRoot] placeholder.
/// - Path ends on a branch → [CategoryEmpty] hint.
/// - Path ends on a node with a panel → [LeafPanel] hosting it. A
///   branch with a landing panel (`ai`, `agents`) renders it too, even
///   while it has children.
///
/// Consumes the shared tree + index published by [SettingsTreeScope]
/// when present (the production path), and falls back to building a
/// local copy from the same gating flags when pumped in isolation
/// (the test path).
class SettingsDetailPane extends ConsumerWidget {
  const SettingsDetailPane({this.table, this.listenable, super.key});

  /// Test-only overrides passed through to [LeafPanel].
  @visibleForTesting
  final SettingsRouteTable? table;
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(settingsTreePathProvider);
    final index =
        SettingsTreeScope.maybeOf(context)?.index ??
        SettingsTreeIndex.build(watchSettingsTree(context, ref));

    final focused = path.isEmpty ? null : index.findById(path.last);
    final hasPanel =
        focused != null &&
        (table ?? settingsRoutes).routes[focused.id]?.panel != null;
    final Widget child;
    // Stable per-mode keys: `'empty'`, `'branch:<id>'`, `'leaf'`. We
    // deliberately drop the leaf id from the key so sibling leaf
    // switches don't tear down `LeafPanel` (which internally caches
    // visited bodies via IndexedStack to preserve scroll/filter
    // state). Empty and branch keys stay per-state because those
    // transitions are visual cross-fades the user expects to see.
    final String keyId;
    if (focused == null || (!focused.hasChildren && !hasPanel)) {
      // Nothing selected, or a leaf this platform has no panel for — a
      // mobile-only leaf reached through a desktop URL.
      child = const EmptyRoot();
      keyId = 'empty';
    } else if (!hasPanel) {
      // Branch without a landing panel → the "pick a child" hint.
      child = CategoryEmpty(node: focused);
      keyId = 'branch:${focused.id}';
    } else {
      child = LeafPanel(
        nodeId: focused.id,
        table: table,
        listenable: listenable,
      );
      keyId = 'leaf';
    }

    return AnimatedSwitcher(
      duration: kSettingsDetailPaneSwap,
      transitionBuilder: (current, animation) =>
          FadeTransition(opacity: animation, child: current),
      child: KeyedSubtree(key: ValueKey(keyId), child: child),
    );
  }
}
