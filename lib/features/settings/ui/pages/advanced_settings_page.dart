import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsAdvancedTitle,
      showBackButton: true,
      child: Column(
        children: [
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
