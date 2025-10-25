import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixTitle,
        subtitle: context.messages.settingsSyncSubtitle,
        child: Column(
          children: [
            // 1) Matrix sync setup modal (top-level)
            const MatrixSettingsCard(),
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsMatrixMaintenanceTitle,
              subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
              icon: Icons.build_outlined,
              onTap: () =>
                  context.beamToNamed('/settings/sync/matrix/maintenance'),
            ),

            // 2) Outbox Monitor
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsSyncOutboxTitle,
              subtitle: context.messages.settingsAdvancedOutboxSubtitle,
              icon: Icons.mail,
              onTap: () => context.beamToNamed('/settings/sync/outbox'),
              trailing: OutboxBadgeIcon(
                icon: Icon(
                  MdiIcons.mailboxOutline,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.9),
                ),
              ),
            ),

            // 3) Conflicts (routes remain under advanced for now)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsConflictsTitle,
              subtitle: context.messages.settingsAdvancedConflictsSubtitle,
              icon: Icons.warning_rounded,
              onTap: () => context.beamToNamed('/settings/advanced/conflicts'),
            ),

            // 4) Sync Stats (full page)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsMatrixStatsTitle,
              subtitle: context.messages.settingsSyncStatsSubtitle,
              icon: Icons.bar_chart_rounded,
              onTap: () => context.beamToNamed('/settings/sync/stats'),
            ),
          ],
        ),
      ),
    );
  }
}
