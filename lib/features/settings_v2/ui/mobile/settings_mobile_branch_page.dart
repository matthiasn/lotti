import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_nav.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_builder.dart';

/// Mobile drill-down hub for a pure-navigation branch (no landing panel
/// of its own) — currently `definitions` and `advanced`.
///
/// Lists the branch's children from the shared settings tree, so it
/// replaces the hand-maintained `DefinitionsPage` / `AdvancedSettingsPage`
/// item lists: the entries, icons, copy, and feature-flag gating all come
/// from `buildSettingsTree`. Branches that carry their own landing page
/// (AI / Agents / Sync) are not rendered here — tapping them beams
/// straight to that page.
class SettingsMobileBranchPage extends ConsumerWidget {
  const SettingsMobileBranchPage({required this.branchId, super.key});

  /// Tree node id of the branch to render, e.g. `definitions`.
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = watchSettingsTree(context, ref);
    final node = SettingsTreeIndex.build(tree).findById(branchId);
    return SettingsMobileTreePage(
      title: node?.title ?? '',
      nodes: node?.children ?? const <SettingsNode>[],
      showBack: true,
      onNodeTap: (child) => handleSettingsNodeTap(context, ref, child),
    );
  }
}
