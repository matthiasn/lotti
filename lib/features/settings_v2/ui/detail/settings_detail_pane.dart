import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/category_empty.dart';
import 'package:lotti/features/settings_v2/ui/detail/empty_root.dart';
import 'package:lotti/features/settings_v2/ui/detail/leaf_panel.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/utils/consts.dart';

/// Cross-fade duration between detail-pane states (spec §7
/// "Detail pane swap").
const Duration kSettingsDetailPaneSwap = Duration(milliseconds: 180);

/// Dispatches the right-hand detail surface of Settings V2 based on
/// the current `settingsTreePathProvider` state:
///
/// - Empty path → [EmptyRoot] with the disable-V2 escape hatch.
/// - Path ends on a branch → [CategoryEmpty] hint.
/// - Path ends on a leaf → [LeafPanel] with its registered panel,
///   falling back to `DefaultPanel` (also with escape hatch) when
///   no panel is registered.
///
/// Consumes the shared tree + index published by [SettingsTreeScope]
/// when present (the production path), and falls back to building a
/// local copy from the same gating flags when pumped in isolation
/// (the test path).
class SettingsDetailPane extends ConsumerWidget {
  const SettingsDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(settingsTreePathProvider);
    final index =
        SettingsTreeScope.maybeOf(context)?.index ??
        _fallbackIndex(context, ref);

    final focused = path.isEmpty ? null : index.findById(path.last);
    final Widget child;
    // Stable per-mode keys: `'empty'`, `'branch:<id>'`, `'leaf'`. We
    // deliberately drop the leaf id from the key so sibling leaf
    // switches don't tear down `LeafPanel` (which internally caches
    // visited bodies via IndexedStack to preserve scroll/filter
    // state). Empty and branch keys stay per-state because those
    // transitions are visual cross-fades the user expects to see.
    final String keyId;
    if (focused == null) {
      child = const EmptyRoot();
      keyId = 'empty';
    } else if (focused.hasChildren && focused.panel == null) {
      // Branch without a landing panel → render the "pick a child"
      // hint. Branches that carry their own panel id (e.g. `ai`,
      // `agents`) fall through to the LeafPanel dispatch below so
      // the landing page renders even while children exist.
      child = CategoryEmpty(node: focused);
      keyId = 'branch:${focused.id}';
    } else {
      final ancestorIds = index.ancestors(focused.id);
      // `ancestors` returns null only for ids that aren't in the
      // index — but we just resolved `focused` from it, so the entry
      // must be present. The assert catches any future divergence.
      assert(
        ancestorIds != null,
        'SettingsTreeIndex.ancestors returned null for an id that '
        'findById just resolved: ${focused.id}',
      );
      final ancestorNodes = <SettingsNode>[
        for (final id in ancestorIds ?? [focused.id])
          // `index.findById(id)!` is safe by the same invariant: every
          // ancestor id appears in `_byId` (see `SettingsTreeIndex.build`).
          // Assert explicitly so a regression fails loud instead of
          // silently rendering the leaf title at every depth.
          _requireNode(index, id),
      ];
      child = LeafPanel(ancestors: ancestorNodes);
      keyId = 'leaf';
    }

    return AnimatedSwitcher(
      duration: kSettingsDetailPaneSwap,
      transitionBuilder: (current, animation) =>
          FadeTransition(opacity: animation, child: current),
      child: KeyedSubtree(key: ValueKey(keyId), child: child),
    );
  }

  SettingsTreeIndex _fallbackIndex(BuildContext context, WidgetRef ref) {
    final tree = buildSettingsTree(
      labels: settingsTreeLabelsFor(context),
      enableAgents:
          ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false,
      enableHabits:
          ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false,
      enableDashboards:
          ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ??
          false,
      enableMatrix:
          ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false,
      enableWhatsNew:
          ref.watch(configFlagProvider(enableWhatsNewFlag)).value ?? false,
    );
    return SettingsTreeIndex.build(tree);
  }
}

SettingsNode _requireNode(SettingsTreeIndex index, String id) {
  final node = index.findById(id);
  assert(
    node != null,
    'SettingsTreeIndex is missing an ancestor id it claims to know: $id',
  );
  return node!;
}
