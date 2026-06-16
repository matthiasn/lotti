import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';

/// Loads the dashboard [dashboardId] and opens it in
/// [DashboardDefinitionPage].
///
/// Subscribes to a notification-driven stream so edits / sync updates push
/// the latest definition into the editor; renders an
/// `EmptyScaffoldWithTitle` "not found" page while the lookup is null
/// (missing or still loading).
class EditDashboardPage extends StatelessWidget {
  EditDashboardPage({
    required this.dashboardId,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String dashboardId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardDefinition?>(
      stream: notificationDrivenItemStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {dashboardsNotification, privateToggleNotification},
        fetcher: () => _db.getDashboardById(dashboardId),
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DashboardDefinition?> snapshot,
          ) {
            final dashboard = snapshot.data;

            if (dashboard == null) {
              return EmptyScaffoldWithTitle(context.messages.dashboardNotFound);
            }

            return DashboardDefinitionPage(dashboard: dashboard);
          },
    );
  }
}
