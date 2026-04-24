import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_node_widget.dart';
import 'package:lotti/utils/consts.dart';

/// Scrollable tree of settings sections. Rebuilds the tree data
/// whenever any of the gating feature flags flips, using
/// [buildSettingsTree] with a locale-aware label resolver from
/// [settingsTreeLabelsFor].
///
/// Each root node is rendered via [SettingsTreeNodeWidget], which
/// recurses into its children and reads
/// `settingsTreePathProvider` to drive selected / expanded state.
class SettingsTreeView extends ConsumerWidget {
  const SettingsTreeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
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
}
