import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/animated_settings_cards.dart';
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
            subtitle: context.messages.settingsAdvancedShowCaseMatrixSyncTooltip,
            icon: Icons.sync,
            onTap: () => context.beamToNamed('/settings/advanced/matrix_sync'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsSyncOutboxTitle,
            subtitle: context.messages.settingsAdvancedShowCaseSyncOutboxTooltip,
            icon: Icons.mail,
            onTap: () => context.beamToNamed('/settings/advanced/outbox_monitor'),
            trailing: OutboxBadgeIcon(
              icon: Icon(
                MdiIcons.mailboxOutline,
                color: context.colorScheme.primary.withValues(alpha: 0.9),
              ),
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsConflictsTitle,
            subtitle: context.messages.settingsAdvancedShowCaseConflictsTooltip,
            icon: Icons.warning_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/conflicts'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsLogsTitle,
            subtitle: context.messages.settingsAdvancedShowCaseLogsTooltip,
            icon: Icons.article_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/logging'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          if (isMobile)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsHealthImportTitle,
              subtitle: context.messages.settingsAdvancedShowCaseHealthImportTooltip,
              icon: Icons.health_and_safety_rounded,
              onTap: () => context.beamToNamed('/settings/health_import'),
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.cardSpacing / 2,
              ),
            ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsMaintenanceTitle,
            subtitle: context.messages.settingsAdvancedShowCaseMaintenanceTooltip,
            icon: Icons.build_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/maintenance'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsAboutTitle,
            subtitle: context.messages.settingsAdvancedShowCaseAboutLottiTooltip,
            icon: Icons.info_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/about'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
        ],
      ),
    );
  }
}
