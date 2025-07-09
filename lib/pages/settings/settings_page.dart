import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/animated_settings_cards.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.navTabTitleSettings,
      child: Column(
        children: [
          AnimatedModernSettingsCardWithIcon(
            title: 'AI Settings',
            subtitle: 'Configure AI providers, models, and prompts',
            icon: Icons.psychology_rounded,
            onTap: () => context.beamToNamed('/settings/ai'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsHabitsTitle,
            subtitle: 'Manage your habits and routines',
            icon: Icons.repeat_rounded,
            onTap: () => context.beamToNamed('/settings/habits'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsCategoriesTitle,
            subtitle: 'Organize entries with categories',
            icon: Icons.category_rounded,
            onTap: () => context.beamToNamed('/settings/categories'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsTagsTitle,
            subtitle: 'Tag and label your entries',
            icon: Icons.label_rounded,
            onTap: () => context.beamToNamed('/settings/tags'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsDashboardsTitle,
            subtitle: 'Customize your dashboard views',
            icon: Icons.dashboard_rounded,
            onTap: () => context.beamToNamed('/settings/dashboards'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsMeasurablesTitle,
            subtitle: 'Configure measurable data types',
            icon: Icons.trending_up_rounded,
            onTap: () => context.beamToNamed('/settings/measurables'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsThemingTitle,
            subtitle: 'Customize app appearance and themes',
            icon: Icons.palette_rounded,
            onTap: () => context.beamToNamed('/settings/theming'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsFlagsTitle,
            subtitle: 'Configure feature flags and options',
            icon: Icons.tune_rounded,
            onTap: () => context.beamToNamed('/settings/flags'),
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
              vertical: AppTheme.cardSpacing / 2,
            ),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsAdvancedTitle,
            subtitle: 'Advanced settings and maintenance',
            icon: Icons.settings_rounded,
            onTap: () => context.beamToNamed('/settings/advanced'),
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
