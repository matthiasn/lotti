import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/utils/consts.dart';

/// Shared tree + index for Settings V2.
///
/// `SettingsV2Page` hosts a [SettingsTreeScopeHost] that watches the
/// gating feature flags once, calls [buildSettingsTree] with the
/// locale-aware label resolver, and publishes the resulting tree and
/// [SettingsTreeIndex] through this inherited widget. Descendant
/// consumers (`SettingsTreeView`, `SettingsDetailPane`) read both
/// values via [SettingsTreeScope.of] instead of rebuilding their own
/// copy.
///
/// Widgets pumped outside this scope (e.g. in unit tests that pump
/// the tree view in isolation) can fall back to building the tree
/// locally by calling [SettingsTreeScope.maybeOf] and constructing
/// fresh data when it returns `null`.
@immutable
class SettingsTreeScope extends InheritedWidget {
  const SettingsTreeScope({
    required this.tree,
    required this.index,
    required super.child,
    super.key,
  });

  final List<SettingsNode> tree;
  final SettingsTreeIndex index;

  static SettingsTreeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsTreeScope>();

  static SettingsTreeScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No SettingsTreeScope found in this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(SettingsTreeScope oldWidget) =>
      !identical(tree, oldWidget.tree) || !identical(index, oldWidget.index);
}

/// Riverpod-aware host that subscribes to the gating flags once and
/// exposes the resulting tree + index through [SettingsTreeScope].
///
/// Rebuilds [child] whenever a flag toggles or the localized label
/// map changes — both descendants observe the same snapshot, so the
/// tree view and detail pane can never disagree about what the tree
/// looks like.
class SettingsTreeScopeHost extends ConsumerWidget {
  const SettingsTreeScopeHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;
    final enableHabits =
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
    final enableDashboards =
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;
    final enableMatrix =
        ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false;
    final enableWhatsNew =
        ref.watch(configFlagProvider(enableWhatsNewFlag)).value ?? false;

    final tree = buildSettingsTree(
      labels: settingsTreeLabelsFor(context),
      enableAgents: enableAgents,
      enableHabits: enableHabits,
      enableDashboards: enableDashboards,
      enableMatrix: enableMatrix,
      enableWhatsNew: enableWhatsNew,
    );
    final index = SettingsTreeIndex.build(tree);

    return SettingsTreeScope(
      tree: tree,
      index: index,
      child: child,
    );
  }
}
