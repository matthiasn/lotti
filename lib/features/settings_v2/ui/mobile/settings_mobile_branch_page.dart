import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_nav.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_builder.dart';

/// Mobile drill-down hub for a branch node — currently `definitions`,
/// `advanced`, and `sync`.
///
/// Lists the branch's children from the shared settings tree, so it
/// replaces the hand-maintained `DefinitionsPage` / `AdvancedSettingsPage`
/// / `SyncSettingsPage` item lists: the entries, icons, copy, ordering,
/// and feature-flag gating all come from `buildSettingsTree` — one
/// definition shared with desktop V2.
///
/// When the branch carries its own landing [SettingsNode.panel] (only
/// `sync` today), that panel body is rendered as a header above the child
/// rows, so the provisioned-sync QR card surfaces here exactly as it does
/// in the desktop detail pane. AI / Agents keep their own rich mobile
/// pages and are not rendered through this hub — tapping them beams
/// straight to that page.
class SettingsMobileBranchPage extends ConsumerWidget {
  const SettingsMobileBranchPage({required this.branchId, super.key});

  /// Tree node id of the branch to render, e.g. `definitions`.
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = watchSettingsTree(context, ref);
    final node = SettingsTreeIndex.build(tree).findById(branchId);
    final panelSpec = panelSpecFor(node?.panel);
    // The header is dropped into the hub's `ListView` directly, which gives
    // its child an unbounded height. A self-scrolling panel body (its own
    // `ListView` / `CustomScrollView` / `Scaffold`, registered with
    // `scrollable: false`) would panic with the unbounded-height assertion
    // here — unlike the desktop `LeafPanel`, the mobile path can't wrap it.
    // So a branch landing panel reused as a mobile header must be a flat,
    // non-self-scrolling body (`scrollable: true`). Today only `sync`
    // qualifies; this guards the next contributor who adds a branch panel.
    assert(
      panelSpec == null || panelSpec.scrollable,
      'Branch "$branchId" landing panel "${node?.panel}" is reused as a '
      'mobile header but is registered with scrollable: false. A '
      'self-scrolling body crashes inside the hub ListView — make it a flat '
      '(non-self-scrolling) body or do not attach it to a navigable branch.',
    );
    return SettingsMobileTreePage(
      title: node?.title ?? '',
      nodes: node?.children ?? const <SettingsNode>[],
      header: panelSpec == null ? null : panelSpec.build(context),
      showBack: true,
      onNodeTap: (child) => handleSettingsNodeTap(context, ref, child),
    );
  }
}
