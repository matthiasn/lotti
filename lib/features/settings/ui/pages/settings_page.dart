import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHabits =
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
    final enableDashboards =
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;

    return SliverBoxAdapterPage(
      title: context.messages.navTabTitleSettings,
      child: Column(
        children: [
          AnimatedModernSettingsCardWithIcon(
            title: 'AI Settings',
            subtitle: 'Configure AI providers, models, and prompts',
            icon: Icons.psychology_rounded,
            onTap: () => context.beamToNamed('/settings/ai'),
          ),
          if (enableHabits)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsHabitsTitle,
              subtitle: 'Manage your habits and routines',
              icon: Icons.repeat_rounded,
              onTap: () => context.beamToNamed('/settings/habits'),
            ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsCategoriesTitle,
            subtitle: 'Categories with AI settings',
            icon: Icons.category_rounded,
            onTap: () => context.beamToNamed('/settings/categories'),
          ),
          // Sync (feature-gated by Matrix flag) — positioned below Categories
          StreamBuilder<bool>(
            stream: getIt<JournalDb>().watchConfigFlag(enableMatrixFlag),
            builder: (context, snap) {
              final enabled = snap.data ?? false;
              if (!enabled) return const SizedBox.shrink();
              return AnimatedModernSettingsCardWithIcon(
                title: context.messages.settingsMatrixTitle,
                subtitle: 'Configure sync and view stats',
                icon: Icons.sync,
                onTap: () => context.beamToNamed('/settings/sync'),
              );
            },
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsTagsTitle,
            subtitle: 'Tag and label your entries',
            icon: Icons.label_rounded,
            onTap: () => context.beamToNamed('/settings/tags'),
          ),
          if (enableDashboards)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsDashboardsTitle,
              subtitle: 'Customize your dashboard views',
              icon: Icons.dashboard_rounded,
              onTap: () => context.beamToNamed('/settings/dashboards'),
            ),
          if (enableDashboards)
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsMeasurablesTitle,
              subtitle: 'Configure measurable data types',
              icon: Icons.trending_up_rounded,
              onTap: () => context.beamToNamed('/settings/measurables'),
            ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsThemingTitle,
            subtitle: 'Customize app appearance and themes',
            icon: Icons.palette_rounded,
            onTap: () => context.beamToNamed('/settings/theming'),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsFlagsTitle,
            subtitle: 'Configure feature flags and options',
            icon: Icons.tune_rounded,
            onTap: () => context.beamToNamed('/settings/flags'),
          ),
          AnimatedModernSettingsCardWithIcon(
            title: context.messages.settingsAdvancedTitle,
            subtitle: 'Advanced settings and maintenance',
            icon: Icons.settings_rounded,
            onTap: () => context.beamToNamed('/settings/advanced'),
          ),
        ],
      ),
    );
  }
}
