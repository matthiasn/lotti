part of 'dashboard_definition_page.dart';

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
