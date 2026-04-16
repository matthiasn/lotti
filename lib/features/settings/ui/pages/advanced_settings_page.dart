import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';

class AdvancedSettingsPage extends ConsumerWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
          (
            title: context.messages.settingsLoggingDomainsTitle,
            subtitle: context.messages.settingsLoggingDomainsSubtitle,
            icon: Icons.tune_rounded,
            onTap: () =>
                context.beamToNamed('/settings/advanced/logging_domains'),
          ),
          if (isMobile)
            (
              title: context.messages.settingsHealthImportTitle,
              subtitle: context.messages.settingsAdvancedHealthImportSubtitle,
              icon: Icons.health_and_safety_rounded,
              onTap: () => context.beamToNamed('/settings/health_import'),
            ),
          (
            title: context.messages.settingsMaintenanceTitle,
            subtitle: context.messages.settingsAdvancedMaintenanceSubtitle,
            icon: Icons.build_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/maintenance'),
          ),
          (
            title: context.messages.settingsAboutTitle,
            subtitle: context.messages.settingsAdvancedAboutSubtitle,
            icon: Icons.info_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/about'),
          ),
        ];

    return SliverBoxAdapterPage(
      title: context.messages.settingsAdvancedTitle,
      showBackButton: true,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, item) in items.indexed)
                DesignSystemListItem(
                  title: item.title,
                  subtitle: item.subtitle,
                  leading: SettingsIcon(icon: item.icon),
                  trailing: SettingsIcon.trailingChevron(tokens),
                  showDivider: index < items.length - 1,
                  dividerIndent: SettingsIcon.dividerIndent(tokens),
                  onTap: item.onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
