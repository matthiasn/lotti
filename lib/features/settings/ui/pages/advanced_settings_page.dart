import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsAdvancedTitle,
      child: Column(
        children: [
          // Matrix sync card
          AnimatedModernSettingsCardWithIcon(
            title: 'Matrix Sync',
            subtitle: context.messages.settingsAdvancedMatrixSyncSubtitle,
            icon: Icons.sync,
            onTap: () => context.beamToNamed('/settings/advanced/matrix_sync'),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsSyncOutboxTitle,
            subtitle: context.messages.settingsAdvancedOutboxSubtitle,
            icon: Icons.mail,
            onTap: () =>
                context.beamToNamed('/settings/advanced/outbox_monitor'),
            trailing: OutboxBadgeIcon(
              icon: Icon(
                MdiIcons.mailboxOutline,
                color: context.colorScheme.primary.withValues(alpha: 0.9),
              ),
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsConflictsTitle,
            subtitle: context.messages.settingsAdvancedConflictsSubtitle,
            icon: Icons.warning_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/conflicts'),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsLogsTitle,
            subtitle: context.messages.settingsAdvancedLogsSubtitle,
            icon: Icons.article_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/logging'),
          ),
          if (isMobile)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsHealthImportTitle,
              subtitle: context.messages.settingsAdvancedHealthImportSubtitle,
              icon: Icons.health_and_safety_rounded,
              onTap: () => context.beamToNamed('/settings/health_import'),
            ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsMaintenanceTitle,
            subtitle: context.messages.settingsAdvancedMaintenanceSubtitle,
            icon: Icons.build_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/maintenance'),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsAboutTitle,
            subtitle: context.messages.settingsAdvancedAboutSubtitle,
            icon: Icons.info_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/about'),
          ),
        ],
      ),
    );
  }
}
