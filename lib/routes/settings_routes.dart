import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/settings/advanced_settings_page.dart';
import 'package:lotti/pages/settings/conflicts.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/health_import_page.dart';
import 'package:lotti/pages/settings/logging_page.dart';
import 'package:lotti/pages/settings/maintenance_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_create_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/pages/settings/measurables/measurables_page.dart';
import 'package:lotti/pages/settings/outbox/outbox_monitor.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_page.dart';
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
      path: 'tags/:tagEntityId',
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
      //page: SyncSettingsPage,
      page: SyncAssistantPage,
    ),
    AutoRoute(
      path: 'measurables',
      page: MeasurablesPage,
    ),
    AutoRoute(
      path: 'create_measurable',
      page: CreateMeasurablePage,
    ),
    AutoRoute(
      path: 'measurables/:measurableId',
      page: EditMeasurablePage,
    ),
    AutoRoute(
      path: 'outbox_monitor',
      page: OutboxMonitorPage,
    ),
    AutoRoute(
      path: 'logging',
      page: LoggingPage,
    ),
    AutoRoute(
      path: 'logging/:logEntryId',
      page: LogDetailPage,
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
    AutoRoute(
      path: 'advanced',
      page: AdvancedSettingsPage,
    ),
  ],
);
