import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

/// All dashboards (active and inactive) for the settings list. The
/// dashboards feature's own `dashboardsProvider` filters to active ones,
/// so the management list keeps its own watcher.
final StreamProvider<List<DashboardDefinition>> allDashboardsStreamProvider =
    StreamProvider.autoDispose<List<DashboardDefinition>>(
      (ref) => notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {dashboardsNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllDashboards,
      ),
    );

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class DashboardsBody extends StatelessWidget {
  const DashboardsBody({super.key});

  @override
  Widget build(BuildContext context) => const DashboardSettingsPage();
}

class DashboardSettingsPage extends ConsumerWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DefinitionsListPage<DashboardDefinition>(
      itemsAsync: ref.watch(allDashboardsStreamProvider),
      title: messages.settingsDashboardsTitle,
      searchHint: messages.settingsDashboardsSearchHint,
      displayName: (dashboard) => dashboard.name,
      searchText: (dashboard) => '${dashboard.name} ${dashboard.description}',
      emptyIcon: Icons.dashboard_customize_outlined,
      emptyTitle: messages.settingsDashboardsEmptyState,
      emptyHint: messages.settingsDashboardsEmptyStateHint,
      noMatchMessage: messages.settingsDashboardsNoMatchQuery,
      errorTitle: messages.settingsDashboardsErrorLoading,
      createLabel: messages.settingsDashboardsCreateTitle,
      onCreate: () => beamToNamed('/settings/dashboards/create'),
      itemBuilder: (context, dashboard, {required bool showDivider}) =>
          _DashboardListItem(dashboard: dashboard, showDivider: showDivider),
    );
  }
}

class _DashboardListItem extends StatelessWidget {
  const _DashboardListItem({
    required this.dashboard,
    required this.showDivider,
  });

  final DashboardDefinition dashboard;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final description = dashboard.description;

    return DesignSystemListItem(
      title: dashboard.name,
      subtitle: description.isNotEmpty ? description : null,
      // Item letter on the category color: the initial matches the row's
      // name while the chip color carries the category.
      leading: CategoryIconChip.fromId(
        dashboard.categoryId,
        letterFrom: dashboard.name,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dashboard.private)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/dashboards/${dashboard.id}'),
    );
  }
}
