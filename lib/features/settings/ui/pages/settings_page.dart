import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/gamey/gamey_settings_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHabits =
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
    final enableDashboards =
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final useGamey = themingState.isGameyThemeForBrightness(brightness);

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
      title: context.messages.navTabTitleSettings,
      actions: [
        GestureDetector(
          onTap: () => WhatsNewModal.show(context, ref),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: WhatsNewIndicator(),
          ),
        ),
      ],
      child: Column(
        children: [
          settingsCard(
            title: "What's New",
            subtitle: 'See the latest updates and features',
            icon: Icons.new_releases_outlined,
            onTap: () => WhatsNewModal.show(context, ref),
          ),
          settingsCard(
            title: 'AI Settings',
            subtitle: 'Configure AI providers, models, and prompts',
            icon: Icons.psychology_rounded,
            onTap: () => context.beamToNamed('/settings/ai'),
          ),
          if (enableAgents)
            settingsCard(
              title: context.messages.agentTemplatesTitle,
              subtitle: context.messages.agentTemplateSettingsSubtitle,
              icon: Icons.smart_toy_outlined,
              onTap: () => context.beamToNamed('/settings/templates'),
            ),
          if (enableHabits)
            settingsCard(
              title: context.messages.settingsHabitsTitle,
              subtitle: 'Manage your habits and routines',
              icon: Icons.repeat_rounded,
              onTap: () => context.beamToNamed('/settings/habits'),
            ),
          settingsCard(
            title: context.messages.settingsCategoriesTitle,
            subtitle: 'Categories with AI settings',
            icon: Icons.category_rounded,
            onTap: () => context.beamToNamed('/settings/categories'),
          ),
          settingsCard(
            title: 'Labels',
            subtitle: 'Organize tasks with colored labels',
            icon: Icons.label_rounded,
            onTap: () => context.beamToNamed('/settings/labels'),
          ),
          // Sync (feature-gated by Matrix flag) — positioned below Categories
          StreamBuilder<bool>(
            stream: getIt<JournalDb>().watchConfigFlag(enableMatrixFlag),
            builder: (context, snap) {
              final enabled = snap.data ?? false;
              if (!enabled) return const SizedBox.shrink();
              return settingsCard(
                title: context.messages.settingsMatrixTitle,
                subtitle: context.messages.settingsSyncSubtitle,
                icon: Icons.sync,
                onTap: () => context.beamToNamed('/settings/sync'),
              );
            },
          ),
          settingsCard(
            title: context.messages.settingsTagsTitle,
            subtitle: 'Tag and label your entries',
            icon: Icons.label_rounded,
            onTap: () => context.beamToNamed('/settings/tags'),
          ),
          if (enableDashboards)
            settingsCard(
              title: context.messages.settingsDashboardsTitle,
              subtitle: 'Customize your dashboard views',
              icon: Icons.dashboard_rounded,
              onTap: () => context.beamToNamed('/settings/dashboards'),
            ),
          if (enableDashboards)
            settingsCard(
              title: context.messages.settingsMeasurablesTitle,
              subtitle: 'Configure measurable data types',
              icon: Icons.trending_up_rounded,
              onTap: () => context.beamToNamed('/settings/measurables'),
            ),
          settingsCard(
            title: context.messages.settingsThemingTitle,
            subtitle: 'Customize app appearance and themes',
            icon: Icons.palette_rounded,
            onTap: () => context.beamToNamed('/settings/theming'),
          ),
          settingsCard(
            title: context.messages.settingsFlagsTitle,
            subtitle: 'Configure feature flags and options',
            icon: Icons.tune_rounded,
            onTap: () => context.beamToNamed('/settings/flags'),
          ),
          settingsCard(
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
