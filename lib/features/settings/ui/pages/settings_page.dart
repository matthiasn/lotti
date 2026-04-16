import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ritual_pending_indicator.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

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
    final enableMatrix =
        ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false;

    final tokens = context.designTokens;

    final items = <_SettingsItem>[
      if (enableWhatsNew)
        _SettingsItem(
          title: context.messages.settingsWhatsNewTitle,
          subtitle: context.messages.settingsWhatsNewSubtitle,
          icon: Icons.new_releases_outlined,
          onTap: () => WhatsNewModal.show(context, ref),
        ),
      _SettingsItem(
        title: context.messages.settingsAiTitle,
        subtitle: context.messages.settingsAiSubtitle,
        icon: Icons.psychology_rounded,
        routePrefix: '/settings/ai',
        onTap: () => context.beamToNamed('/settings/ai'),
      ),
      if (enableAgents)
        _SettingsItem(
          title: context.messages.agentSettingsTitle,
          subtitle: context.messages.agentSettingsSubtitle,
          icon: Icons.smart_toy_outlined,
          routePrefix: '/settings/agents',
          onTap: () => context.beamToNamed('/settings/agents'),
          trailingExtra: const RitualPendingIndicator(),
        ),
      if (enableHabits)
        _SettingsItem(
          title: context.messages.settingsHabitsTitle,
          subtitle: context.messages.settingsHabitsSubtitle,
          icon: Icons.repeat_rounded,
          routePrefix: '/settings/habits',
          onTap: () => context.beamToNamed('/settings/habits'),
        ),
      _SettingsItem(
        title: context.messages.settingsCategoriesTitle,
        subtitle: context.messages.settingsCategoriesSubtitle,
        icon: Icons.category_rounded,
        routePrefix: '/settings/categories',
        onTap: () => context.beamToNamed('/settings/categories'),
      ),
      _SettingsItem(
        title: context.messages.settingsLabelsTitle,
        subtitle: context.messages.settingsLabelsSubtitle,
        icon: Icons.label_rounded,
        routePrefix: '/settings/labels',
        onTap: () => context.beamToNamed('/settings/labels'),
      ),
      if (enableMatrix)
        _SettingsItem(
          title: context.messages.settingsMatrixTitle,
          subtitle: context.messages.settingsSyncSubtitle,
          icon: Icons.sync,
          routePrefix: '/settings/sync',
          onTap: () => context.beamToNamed('/settings/sync'),
        ),
      if (enableDashboards)
        _SettingsItem(
          title: context.messages.settingsDashboardsTitle,
          subtitle: context.messages.settingsDashboardsSubtitle,
          icon: Icons.dashboard_rounded,
          routePrefix: '/settings/dashboards',
          onTap: () => context.beamToNamed('/settings/dashboards'),
        ),
      if (enableDashboards)
        _SettingsItem(
          title: context.messages.settingsMeasurablesTitle,
          subtitle: context.messages.settingsMeasurablesSubtitle,
          icon: Icons.trending_up_rounded,
          routePrefix: '/settings/measurables',
          onTap: () => context.beamToNamed('/settings/measurables'),
        ),
      _SettingsItem(
        title: context.messages.settingsThemingTitle,
        subtitle: context.messages.settingsThemingSubtitle,
        icon: Icons.palette_rounded,
        routePrefix: '/settings/theming',
        onTap: () => context.beamToNamed('/settings/theming'),
      ),
      _SettingsItem(
        title: context.messages.settingsFlagsTitle,
        subtitle: context.messages.settingsFlagsSubtitle,
        icon: Icons.tune_rounded,
        routePrefix: '/settings/flags',
        onTap: () => context.beamToNamed('/settings/flags'),
      ),
      _SettingsItem(
        title: context.messages.settingsAdvancedTitle,
        subtitle: context.messages.settingsAdvancedSubtitle,
        icon: Icons.settings_rounded,
        routePrefix: '/settings/advanced',
        onTap: () => context.beamToNamed('/settings/advanced'),
      ),
    ];

    final isDesktop = isDesktopLayout(context);

    Widget buildList({required String? activeRoute}) {
      return DecoratedBox(
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
                  trailingExtra: item.trailingExtra,
                  activated:
                      isDesktop &&
                      item.routePrefix != null &&
                      activeRoute != null &&
                      (activeRoute == item.routePrefix ||
                          activeRoute.startsWith('${item.routePrefix}/')),
                  showDivider: index < items.length - 1,
                  dividerIndent: SettingsIcon.dividerIndent(tokens),
                  onTap: item.onTap,
                ),
            ],
          ),
        ),
      );
    }

    final listWidget = isDesktop
        ? ValueListenableBuilder<DesktopSettingsRoute?>(
            valueListenable: getIt<NavService>().desktopSelectedSettingsRoute,
            builder: (context, settingsRoute, _) =>
                buildList(activeRoute: settingsRoute?.path),
          )
        : buildList(activeRoute: null);

    return SliverBoxAdapterPage(
      title: context.messages.navTabTitleSettings,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
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
      child: listWidget,
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.routePrefix,
    this.trailingExtra,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Route prefix used to determine whether this item is active on desktop,
  /// e.g. `/settings/ai`. `null` for items that open modals instead of routes.
  final String? routePrefix;
  final Widget? trailingExtra;
}
