import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_nav.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_builder.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile Settings landing — the top level of the unified drill-down.
///
/// Renders the root of the shared settings tree (the same nodes the
/// desktop tree-nav shows at depth 0). Replaces the legacy `SettingsPage`
/// + its hand-maintained `_SettingsItem` list and the collapsing
/// `SliverBoxAdapterPage` header.
class SettingsMobileRootPage extends ConsumerWidget {
  const SettingsMobileRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = watchSettingsTree(context, ref);
    return SettingsMobileTreePage(
      title: context.messages.navTabTitleSettings,
      nodes: tree,
      onNodeTap: (node) => handleSettingsNodeTap(context, ref, node),
    );
  }
}
