import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_node_widget.dart';
import 'package:lotti/utils/consts.dart';

/// Scrollable tree of settings sections. Consumes the shared tree
/// published by [SettingsTreeScope] when present (the production
/// path), and falls back to building a local tree from the same
/// gating flags when pumped in isolation (the test path) — so tests
/// that render [SettingsTreeView] without an enclosing
/// `SettingsV2Page` keep working without ceremony.
///
/// Each root node is rendered via [SettingsTreeNodeWidget], which
/// recurses into its children and reads
/// `settingsTreePathProvider` to drive selected / expanded state.
class SettingsTreeView extends ConsumerWidget {
  const SettingsTreeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final scope = SettingsTreeScope.maybeOf(context);
    final tree = scope?.tree ?? _fallbackTree(context, ref);

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step5,
      ),
      children: [
        for (final SettingsNode node in tree)
          SettingsTreeNodeWidget(
            key: ValueKey(node.id),
            node: node,
            depth: 0,
          ),
      ],
    );
  }

  List<SettingsNode> _fallbackTree(BuildContext context, WidgetRef ref) {
    return buildSettingsTree(
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
  }
}
