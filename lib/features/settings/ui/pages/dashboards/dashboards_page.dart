import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class DashboardsBody extends StatelessWidget {
  const DashboardsBody({super.key});

  @override
  Widget build(BuildContext context) => const DashboardSettingsPage();
}

class DashboardSettingsPage extends StatelessWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<DashboardDefinition>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {dashboardsNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllDashboards,
      ),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/dashboards/create'),
        semanticLabel: 'Add Dashboard',
      ),
      title: context.messages.settingsDashboardsTitle,
      getName: (dashboard) => '${dashboard.name} ${dashboard.description}',
      definitionCard:
          (int index, DashboardDefinition item, {required bool isLast}) {
            return _DashboardListItem(
              dashboard: item,
              showDivider: !isLast,
            );
          },
    );
  }
}

class _DashboardListItem extends StatelessWidget {
  const _DashboardListItem({
    required this.dashboard,
    required this.showDivider,
  });

  static const double _leadingIconSize = 28;

  final DashboardDefinition dashboard;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final description = dashboard.description;

    return DesignSystemListItem(
      title: dashboard.name,
      subtitle: description.isNotEmpty ? description : null,
      leading: CategoryIconCompact(
        dashboard.categoryId,
        size: _leadingIconSize,
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
          tokens.spacing.step5 + _leadingIconSize + tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/dashboards/${dashboard.id}'),
    );
  }
}
