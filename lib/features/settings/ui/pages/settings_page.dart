import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ritual_pending_indicator.dart';
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
    final enableWhatsNew =
        ref.watch(configFlagProvider(enableWhatsNewFlag)).value ?? false;
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
        if (enableWhatsNew)
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
          if (enableWhatsNew)
            settingsCard(
              title: context.messages.settingsWhatsNewTitle,
              subtitle: context.messages.settingsWhatsNewSubtitle,
              icon: Icons.new_releases_outlined,
              onTap: () => WhatsNewModal.show(context, ref),
            ),
          settingsCard(
            title: context.messages.settingsAiTitle,
            subtitle: context.messages.settingsAiSubtitle,
            icon: Icons.psychology_rounded,
            onTap: () => context.beamToNamed('/settings/ai'),
          ),
          if (enableAgents)
            Stack(
              children: [
                settingsCard(
                  title: context.messages.agentSettingsTitle,
                  subtitle: context.messages.agentSettingsSubtitle,
                  icon: Icons.smart_toy_outlined,
                  onTap: () => context.beamToNamed('/settings/agents'),
                ),
                const Positioned(
                  top: 12,
                  right: 16,
                  child: RitualPendingIndicator(),
                ),
              ],
            ),
          if (enableHabits)
            settingsCard(
              title: context.messages.settingsHabitsTitle,
              subtitle: context.messages.settingsHabitsSubtitle,
              icon: Icons.repeat_rounded,
              onTap: () => context.beamToNamed('/settings/habits'),
            ),
          settingsCard(
            title: context.messages.settingsCategoriesTitle,
            subtitle: context.messages.settingsCategoriesSubtitle,
            icon: Icons.category_rounded,
            onTap: () => context.beamToNamed('/settings/categories'),
          ),
          settingsCard(
            title: context.messages.settingsLabelsTitle,
            subtitle: context.messages.settingsLabelsSubtitle,
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
          if (enableDashboards)
            settingsCard(
              title: context.messages.settingsDashboardsTitle,
              subtitle: context.messages.settingsDashboardsSubtitle,
              icon: Icons.dashboard_rounded,
              onTap: () => context.beamToNamed('/settings/dashboards'),
            ),
          if (enableDashboards)
            settingsCard(
              title: context.messages.settingsMeasurablesTitle,
              subtitle: context.messages.settingsMeasurablesSubtitle,
              icon: Icons.trending_up_rounded,
              onTap: () => context.beamToNamed('/settings/measurables'),
            ),
          settingsCard(
            title: context.messages.settingsThemingTitle,
            subtitle: context.messages.settingsThemingSubtitle,
            icon: Icons.palette_rounded,
            onTap: () => context.beamToNamed('/settings/theming'),
          ),
          settingsCard(
            title: context.messages.settingsFlagsTitle,
            subtitle: context.messages.settingsFlagsSubtitle,
            icon: Icons.tune_rounded,
            onTap: () => context.beamToNamed('/settings/flags'),
          ),
          settingsCard(
            title: context.messages.settingsAdvancedTitle,
            subtitle: context.messages.settingsAdvancedSubtitle,
            icon: Icons.settings_rounded,
            onTap: () => context.beamToNamed('/settings/advanced'),
          ),
        ],
      ),
    );
  }
}
