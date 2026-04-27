import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: tokens.spacing.step6,
      color: tokens.colors.text.lowEmphasis,
    );

    final items =
        <
          ({
            String title,
            String subtitle,
            IconData icon,
            Widget trailing,
            VoidCallback onTap,
          })
        >[
          (
            title: context.messages.settingsMatrixMaintenanceTitle,
            subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
            icon: Icons.build_outlined,
            trailing: chevron,
            onTap: () =>
                context.beamToNamed('/settings/sync/matrix/maintenance'),
          ),
          (
            title: context.messages.settingsSyncOutboxTitle,
            subtitle: context.messages.settingsAdvancedOutboxSubtitle,
            icon: Icons.mail,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutboxBadgeIcon(
                  icon: Icon(
                    MdiIcons.mailboxOutline,
                    color: tokens.colors.interactive.enabled,
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                chevron,
              ],
            ),
            onTap: () => context.beamToNamed('/settings/sync/outbox'),
          ),
          (
            title: context.messages.settingsConflictsTitle,
            subtitle: context.messages.settingsSyncConflictsSubtitle,
            icon: Icons.warning_rounded,
            trailing: chevron,
            onTap: () => context.beamToNamed('/settings/advanced/conflicts'),
          ),
          (
            title: context.messages.settingsMatrixStatsTitle,
            subtitle: context.messages.settingsSyncStatsSubtitle,
            icon: Icons.bar_chart_rounded,
            trailing: chevron,
            onTap: () => context.beamToNamed('/settings/sync/stats'),
          ),
          (
            title: context.messages.backfillSettingsTitle,
            subtitle: context.messages.backfillSettingsSubtitle,
            icon: Icons.history_rounded,
            trailing: chevron,
            onTap: () => context.beamToNamed('/settings/sync/backfill'),
          ),
        ];

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixTitle,
        showBackButton: true,
        subtitle: context.messages.settingsSyncSubtitle,
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
        child: DesignSystemGroupedList(
          children: [
            const ProvisionedSyncSettingsCard(showDivider: true),
            for (final (index, item) in items.indexed)
              DesignSystemListItem(
                title: item.title,
                subtitle: item.subtitle,
                leading: SettingsIcon(icon: item.icon),
                trailing: item.trailing,
                showDivider: index < items.length - 1,
                dividerIndent: SettingsIcon.dividerIndent(tokens),
                onTap: item.onTap,
              ),
          ],
        ),
      ),
    );
  }
}
