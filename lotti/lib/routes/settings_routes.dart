import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/settings/conflicts.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_details_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/health_import_page.dart';
import 'package:lotti/pages/settings/insights_page.dart';
import 'package:lotti/pages/settings/maintenance_page.dart';
import 'package:lotti/pages/settings/measurables_page.dart';
import 'package:lotti/pages/settings/outbox_monitor.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/settings/sync_settings.dart';
import 'package:lotti/pages/settings/tags/create_tag_page.dart';
import 'package:lotti/pages/settings/tags/tag_edit_page.dart';
import 'package:lotti/pages/settings/tags/tags_page.dart';

const AutoRoute settingsRoutes = AutoRoute(
  path: 'settings',
  name: 'SettingsRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: SettingsPage,
    ),
    AutoRoute(
      path: 'tags',
      page: TagsPage,
    ),
    AutoRoute(
      path: 'tags/:tagId',
      page: EditExistingTagPage,
    ),
    AutoRoute(
      path: 'tags/create/:tagType',
      page: CreateTagPage,
    ),
    AutoRoute(
      path: 'dashboards',
      page: DashboardSettingsPage,
    ),
    AutoRoute(
      path: 'dashboards/:dashboardId',
      page: EditDashboardPage,
    ),
    AutoRoute(
      path: 'dashboards/create',
      page: CreateDashboardPage,
    ),
    AutoRoute(
      path: 'health_import',
      page: HealthImportPage,
    ),
    AutoRoute(
      path: 'sync_settings',
      page: SyncSettingsPage,
    ),
    AutoRoute(
      path: 'measurables',
      page: MeasurablesPage,
    ),
    AutoRoute(
      path: 'outbox_monitor',
      page: OutboxMonitorPage,
    ),
    AutoRoute(
      path: 'insights',
      page: InsightsPage,
    ),
    AutoRoute(
      path: 'conflicts',
      page: ConflictsPage,
    ),
    AutoRoute(
      path: 'flags',
      page: FlagsPage,
    ),
    AutoRoute(
      path: 'maintenance',
      page: MaintenancePage,
    ),
  ],
);
