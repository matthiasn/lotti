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
          id: 'whats-new',
          title: context.messages.settingsWhatsNewTitle,
          subtitle: context.messages.settingsWhatsNewSubtitle,
          icon: Icons.new_releases_outlined,
          onTap: () => WhatsNewModal.show(context, ref),
        ),
      _SettingsItem(
        id: '/settings/ai',
        title: context.messages.settingsAiTitle,
        subtitle: context.messages.settingsAiSubtitle,
        icon: Icons.psychology_rounded,
        routePrefix: '/settings/ai',
        onTap: () => context.beamToNamed('/settings/ai'),
      ),
      if (enableAgents)
        _SettingsItem(
          id: '/settings/agents',
          title: context.messages.agentSettingsTitle,
          subtitle: context.messages.agentSettingsSubtitle,
          icon: Icons.smart_toy_outlined,
          routePrefix: '/settings/agents',
          onTap: () => context.beamToNamed('/settings/agents'),
          trailingExtra: const RitualPendingIndicator(),
        ),
      if (enableHabits)
        _SettingsItem(
          id: '/settings/habits',
          title: context.messages.settingsHabitsTitle,
          subtitle: context.messages.settingsHabitsSubtitle,
          icon: Icons.repeat_rounded,
          routePrefix: '/settings/habits',
          onTap: () => context.beamToNamed('/settings/habits'),
        ),
      _SettingsItem(
        id: '/settings/categories',
        title: context.messages.settingsCategoriesTitle,
        subtitle: context.messages.settingsCategoriesSubtitle,
        icon: Icons.category_rounded,
        routePrefix: '/settings/categories',
        onTap: () => context.beamToNamed('/settings/categories'),
      ),
      _SettingsItem(
        id: '/settings/labels',
        title: context.messages.settingsLabelsTitle,
        subtitle: context.messages.settingsLabelsSubtitle,
        icon: Icons.label_rounded,
        routePrefix: '/settings/labels',
        onTap: () => context.beamToNamed('/settings/labels'),
      ),
      if (enableMatrix)
        _SettingsItem(
          id: '/settings/sync',
          title: context.messages.settingsMatrixTitle,
          subtitle: context.messages.settingsSyncSubtitle,
          icon: Icons.sync,
          routePrefix: '/settings/sync',
          onTap: () => context.beamToNamed('/settings/sync'),
        ),
      if (enableDashboards)
        _SettingsItem(
          id: '/settings/dashboards',
          title: context.messages.settingsDashboardsTitle,
          subtitle: context.messages.settingsDashboardsSubtitle,
          icon: Icons.dashboard_rounded,
          routePrefix: '/settings/dashboards',
          onTap: () => context.beamToNamed('/settings/dashboards'),
        ),
      if (enableDashboards)
        _SettingsItem(
          id: '/settings/measurables',
          title: context.messages.settingsMeasurablesTitle,
          subtitle: context.messages.settingsMeasurablesSubtitle,
          icon: Icons.trending_up_rounded,
          routePrefix: '/settings/measurables',
          onTap: () => context.beamToNamed('/settings/measurables'),
        ),
      _SettingsItem(
        id: '/settings/theming',
        title: context.messages.settingsThemingTitle,
        subtitle: context.messages.settingsThemingSubtitle,
        icon: Icons.palette_rounded,
        routePrefix: '/settings/theming',
        onTap: () => context.beamToNamed('/settings/theming'),
      ),
      _SettingsItem(
        id: '/settings/flags',
        title: context.messages.settingsFlagsTitle,
        subtitle: context.messages.settingsFlagsSubtitle,
        icon: Icons.tune_rounded,
        routePrefix: '/settings/flags',
        onTap: () => context.beamToNamed('/settings/flags'),
      ),
      _SettingsItem(
        id: '/settings/advanced',
        title: context.messages.settingsAdvancedTitle,
        subtitle: context.messages.settingsAdvancedSubtitle,
        icon: Icons.settings_rounded,
        routePrefix: '/settings/advanced',
        onTap: () => context.beamToNamed('/settings/advanced'),
      ),
    ];

    final isDesktop = isDesktopLayout(context);

    Widget buildList({required String? activeRoute}) {
      return _SettingsListCard(
        items: items,
        activeRoute: activeRoute,
        isDesktop: isDesktop,
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
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.routePrefix,
    this.trailingExtra,
  });

  /// Stable identity used for keying the widget and tracking cross-row
  /// state (hover, activation). Must be unique within a single settings
  /// list and stable across rebuilds even when feature flags reorder
  /// the items around it.
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Route prefix used to determine whether this item is active on desktop,
  /// e.g. `/settings/ai`. `null` for items that open modals instead of routes.
  final String? routePrefix;
  final Widget? trailingExtra;
}

/// Settings menu card that renders [_SettingsItem]s as a column of
/// [DesignSystemListItem]s inside a rounded, bordered container.
///
/// Tracks which row the pointer is currently hovering so the divider
/// between two rows can be visually suppressed whenever either of them
/// is hovered or active — matching the task-list behaviour where an
/// interacting row is never bisected by a partial-width divider. The
/// divider keeps its 1 px of vertical space (just turns transparent)
/// so hover never causes the column to jitter.
///
/// Hover tracking is keyed by [_SettingsItem.id], not by list index, so
/// toggling a feature flag (which reorders the list) does not leave the
/// suppression pointing at the wrong row.
class _SettingsListCard extends StatefulWidget {
  const _SettingsListCard({
    required this.items,
    required this.activeRoute,
    required this.isDesktop,
  });

  final List<_SettingsItem> items;
  final String? activeRoute;
  final bool isDesktop;

  @override
  State<_SettingsListCard> createState() => _SettingsListCardState();
}

class _SettingsListCardState extends State<_SettingsListCard> {
  String? _hoveredId;

  @override
  void didUpdateWidget(covariant _SettingsListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop hover state if the hovered item was removed (e.g. a feature
    // flag toggle reordered the list and removed its row). Without
    // this, divider suppression could stay stuck on a stale id — and
    // if the same id reappeared later, it would come back pre-hovered.
    final hoveredId = _hoveredId;
    if (hoveredId != null &&
        !widget.items.any((item) => item.id == hoveredId)) {
      _hoveredId = null;
    }
  }

  bool _isActive(_SettingsItem item) {
    if (!widget.isDesktop) return false;
    final prefix = item.routePrefix;
    final route = widget.activeRoute;
    if (prefix == null || route == null) return false;
    return route == prefix || route.startsWith('$prefix/');
  }

  bool _isInteracting(_SettingsItem item) =>
      _hoveredId == item.id || _isActive(item);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dividerIndent = SettingsIcon.dividerIndent(tokens);
    final trailingChevron = SettingsIcon.trailingChevron(tokens);
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
            for (final (index, item) in widget.items.indexed)
              DesignSystemListItem(
                key: ValueKey(item.id),
                title: item.title,
                subtitle: item.subtitle,
                leading: SettingsIcon(icon: item.icon),
                trailing: trailingChevron,
                trailingExtra: item.trailingExtra,
                activated: _isActive(item),
                selected: _isActive(item),
                showDivider: index < widget.items.length - 1,
                dividerIndent: dividerIndent,
                dividerColor:
                    index < widget.items.length - 1 &&
                        (_isInteracting(item) ||
                            _isInteracting(widget.items[index + 1]))
                    ? Colors.transparent
                    : null,
                onTap: item.onTap,
                onHoverChanged: (hovered) {
                  setState(() {
                    if (hovered) {
                      _hoveredId = item.id;
                    } else if (_hoveredId == item.id) {
                      _hoveredId = null;
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
