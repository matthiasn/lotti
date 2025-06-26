import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/modern_settings_cards.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.navTabTitleSettings,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          children: [
            ModernSettingsCardWithIcon(
              title: 'AI Settings',
              subtitle: 'Configure AI providers, models, and prompts',
              icon: Icons.psychology_rounded,
              onTap: () => context.beamToNamed('/settings/ai'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsHabitsTitle,
              subtitle: 'Manage your habits and routines',
              icon: Icons.repeat_rounded,
              onTap: () => context.beamToNamed('/settings/habits'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsCategoriesTitle,
              subtitle: 'Organize entries with categories',
              icon: Icons.category_rounded,
              onTap: () => context.beamToNamed('/settings/categories'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsTagsTitle,
              subtitle: 'Tag and label your entries',
              icon: Icons.label_rounded,
              onTap: () => context.beamToNamed('/settings/tags'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsDashboardsTitle,
              subtitle: 'Customize your dashboard views',
              icon: Icons.dashboard_rounded,
              onTap: () => context.beamToNamed('/settings/dashboards'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsMeasurablesTitle,
              subtitle: 'Configure measurable data types',
              icon: Icons.trending_up_rounded,
              onTap: () => context.beamToNamed('/settings/measurables'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsThemingTitle,
              subtitle: 'Customize app appearance and themes',
              icon: Icons.palette_rounded,
              onTap: () => context.beamToNamed('/settings/theming'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsFlagsTitle,
              subtitle: 'Configure feature flags and options',
              icon: Icons.tune_rounded,
              onTap: () => context.beamToNamed('/settings/flags'),
            ),
            const SizedBox(height: AppTheme.cardSpacing),
            ModernSettingsCardWithIcon(
              title: context.messages.settingsAdvancedTitle,
              subtitle: 'Advanced settings and maintenance',
              icon: Icons.settings_rounded,
              onTap: () => context.beamToNamed('/settings/advanced'),
            ),
            const SizedBox(height: AppTheme.cardPadding),
          ],
        ),
      ),
    );
  }
}
