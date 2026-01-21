import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/gamey/gamey_settings_card.dart';

class AdvancedSettingsPage extends ConsumerWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final useGamey = themingState.isUsingGameyTheme;

    Widget settingsCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      if (useGamey) {
        return GameySettingsCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
        );
      }
      return AnimatedModernSettingsCardWithIcon(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
      );
    }

    return SliverBoxAdapterPage(
      title: context.messages.settingsAdvancedTitle,
      showBackButton: true,
      child: Column(
        children: [
          settingsCard(
            title: context.messages.settingsLogsTitle,
            subtitle: context.messages.settingsAdvancedLogsSubtitle,
            icon: Icons.article_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/logging'),
          ),
          if (isMobile)
            settingsCard(
              title: context.messages.settingsHealthImportTitle,
              subtitle: context.messages.settingsAdvancedHealthImportSubtitle,
              icon: Icons.health_and_safety_rounded,
              onTap: () => context.beamToNamed('/settings/health_import'),
            ),
          settingsCard(
            title: context.messages.settingsMaintenanceTitle,
            subtitle: context.messages.settingsAdvancedMaintenanceSubtitle,
            icon: Icons.build_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/maintenance'),
          ),
          settingsCard(
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
