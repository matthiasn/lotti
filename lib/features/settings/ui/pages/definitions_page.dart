import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

/// Sub-page that groups the entity-definition entries (habits,
/// categories, labels, dashboards, measurables) the v1 settings root
/// previously listed at top level.
///
/// Each row beams to the existing `/settings/<entity>` route — the
/// destination pages are unchanged. Habits and dashboards are still
/// gated behind their feature flags and only appear when enabled.
class DefinitionsPage extends ConsumerWidget {
  const DefinitionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHabits =
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
    final enableDashboards =
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;

    final tokens = context.designTokens;

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
          (
            title: context.messages.settingsCategoriesTitle,
            subtitle: context.messages.settingsCategoriesSubtitle,
            icon: Icons.category_rounded,
            onTap: () => context.beamToNamed('/settings/categories'),
          ),
          (
            title: context.messages.settingsLabelsTitle,
            subtitle: context.messages.settingsLabelsSubtitle,
            icon: Icons.label_rounded,
            onTap: () => context.beamToNamed('/settings/labels'),
          ),
          if (enableHabits)
            (
              title: context.messages.settingsHabitsTitle,
              subtitle: context.messages.settingsHabitsSubtitle,
              icon: Icons.repeat_rounded,
              onTap: () => context.beamToNamed('/settings/habits'),
            ),
          if (enableDashboards)
            (
              title: context.messages.settingsDashboardsTitle,
              subtitle: context.messages.settingsDashboardsSubtitle,
              icon: Icons.dashboard_rounded,
              onTap: () => context.beamToNamed('/settings/dashboards'),
            ),
          (
            title: context.messages.settingsMeasurablesTitle,
            subtitle: context.messages.settingsMeasurablesSubtitle,
            icon: Icons.straighten_rounded,
            onTap: () => context.beamToNamed('/settings/measurables'),
          ),
        ];

    return SliverBoxAdapterPage(
      title: context.messages.settingsDefinitionsTitle,
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
