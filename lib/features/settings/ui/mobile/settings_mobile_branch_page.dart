import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/domain/settings_tree_index.dart';
import 'package:lotti/features/settings/ui/mobile/settings_mobile_nav.dart';
import 'package:lotti/features/settings/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/features/settings/ui/settings_tree_builder.dart';

/// Mobile drill-down hub for a pure-navigation branch — `definitions`,
/// `preferences`, `advanced` and `sync`.
///
/// Lists the branch's children from the shared settings tree: the entries,
/// icons, copy, ordering and feature-flag gating all come from
/// `buildSettingsTree`, the one definition the desktop tree-nav renders too.
/// AI and Agents have pages of their own and are not rendered through here.
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
      // Sync keeps the teal icon treatment its standalone page had before
      // it was folded into the shared tree (other branches stay grey).
      accentIcons: branchId == 'sync',
      onNodeTap: (child) => handleSettingsNodeTap(context, ref, child),
    );
  }
}
