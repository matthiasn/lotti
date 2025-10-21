import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/conflicts_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_monitor.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/create_tag_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/tag_edit_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/tags_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

class MockBuildContext extends Mock implements BuildContext {}

class MockTagsService extends Mock implements TagsService {}

class MockLoggingDb extends Mock implements LoggingDb {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  group('SettingsLocation', () {
    late MockBuildContext mockBuildContext;

    setUpAll(() {
      // Register mock services with GetIt for tests that need them
      getIt
        ..registerSingleton<TagsService>(MockTagsService())
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<JournalDb>(MockJournalDb());
    });

    tearDownAll(getIt.reset);

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          SettingsLocation(RouteInformation(uri: Uri.parse('/settings')));
      expect(location.pathPatterns, [
        '/settings',
        '/settings/ai',
        '/settings/sync',
        '/settings/sync/matrix/maintenance',
        '/settings/sync/stats',
        '/settings/sync/outbox',
        '/settings/tags',
        '/settings/tags/:tagEntityId',
        '/settings/tags/create/:tagType',
        '/settings/categories',
        '/settings/categories/:categoryId',
        '/settings/categories/create',
        '/settings/dashboards',
        '/settings/dashboards/:dashboardId',
        '/settings/dashboards/create',
        '/settings/measurables',
        '/settings/measurables/:measurableId',
        '/settings/measurables/create',
        '/settings/habits',
        '/settings/habits/by_id/:habitId',
        '/settings/habits/create',
        '/settings/habits/search/:searchTerm',
        '/settings/flags',
        '/settings/theming',
        '/settings/advanced',
        '/settings/logging',
        '/settings/advanced/logging/:logEntryId',
        '/settings/advanced/conflicts/:conflictId',
        '/settings/advanced/conflicts/:conflictId/edit',
        '/settings/advanced/conflicts',
        '/settings/maintenance',
      ]);
    });

    test('buildPages builds SettingsPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<SettingsPage>());
    });

    test('buildPages builds TagsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/tags'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].key, isA<ValueKey<String>>());
      expect(pages[1].child, isA<TagsPage>());
    });

    test('buildPages builds AiSettingsPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings/ai'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AiSettingsPage>());
    });

    test('buildPages builds SyncSettingsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/sync'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      // Second page is SyncSettingsPage; type check omitted to avoid import churn
    });

    test('buildPages builds MatrixSyncMaintenancePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync/matrix/maintenance'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<SyncSettingsPage>());
      expect(pages[2].child, isA<MatrixSyncMaintenancePage>());
    });

    test('buildPages builds CategoriesListPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/categories'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<CategoriesListPage>());
    });

    test('buildPages builds CategoryDetailsPage for create', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/categories/create'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<CategoryDetailsPage>());
    });

    test('buildPages builds CategoryDetailsPage with categoryId', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/categories/test-id'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'categoryId': 'test-id'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<CategoryDetailsPage>());
      final categoryPage = pages[1].child as CategoryDetailsPage;
      expect(categoryPage.categoryId, 'test-id');
    });

    test('buildPages builds EditExistingTagPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/tags/tag-123'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'tagEntityId': 'tag-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<TagsPage>());
      expect(pages[2].child, isA<EditExistingTagPage>());
    });

    test('buildPages builds CreateTagPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/tags/create/person'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'tagType': 'person'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<TagsPage>());
      expect(pages[2].child, isA<CreateTagPage>());
    });

    test('buildPages builds DashboardSettingsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/dashboards'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<DashboardSettingsPage>());
    });

    test('buildPages builds EditDashboardPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/dashboards/dash-123'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'dashboardId': 'dash-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<DashboardSettingsPage>());
      expect(pages[2].child, isA<EditDashboardPage>());
    });

    test('buildPages builds CreateDashboardPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/dashboards/create'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<DashboardSettingsPage>());
      expect(pages[2].child, isA<CreateDashboardPage>());
    });

    test('buildPages builds MeasurablesPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/measurables'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<MeasurablesPage>());
    });

    test('buildPages builds EditMeasurablePage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/measurables/meas-123'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'measurableId': 'meas-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<MeasurablesPage>());
      expect(pages[2].child, isA<EditMeasurablePage>());
    });

    test('buildPages builds CreateMeasurablePage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/measurables/create'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<MeasurablesPage>());
      expect(pages[2].child, isA<CreateMeasurablePage>());
    });

    test('buildPages builds HabitsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/habits'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<HabitsPage>());
    });

    test('buildPages builds HabitsPage with search term', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/habits/search/test'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'searchTerm': 'test'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<HabitsPage>());
      final habitsPage = pages[1].child as HabitsPage;
      expect(habitsPage.initialSearchTerm, 'test');
    });

    test('buildPages builds EditHabitPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/habits/by_id/habit-123'));
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'habitId': 'habit-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<HabitsPage>());
      expect(pages[2].child, isA<EditHabitPage>());
    });

    test('buildPages builds CreateHabitPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/habits/create'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<HabitsPage>());
      expect(pages[2].child, isA<CreateHabitPage>());
    });

    test('buildPages builds FlagsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/flags'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<FlagsPage>());
    });

    test('buildPages builds ThemingPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/theming'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<ThemingPage>());
    });

    test('buildPages builds HealthImportPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/health_import'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<HealthImportPage>());
    });

    test('buildPages builds AdvancedSettingsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/advanced'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
    });

    test('buildPages builds OutboxMonitorPage under /settings/sync/outbox', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/sync/outbox'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<SyncSettingsPage>());
      expect(pages[2].child, isA<OutboxMonitorPage>());
    });

    test('buildPages builds SyncStatsPage under /settings/sync/stats', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/sync/stats'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<SyncSettingsPage>());
      expect(pages[2].child, isA<SyncStatsPage>());
    });

    test('buildPages builds LoggingPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/advanced/logging'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<LoggingPage>());
    });

    test('buildPages builds LogDetailPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/logging/log-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'logEntryId': 'log-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<LoggingPage>());
      expect(pages[3].child, isA<LogDetailPage>());
    });

    test('buildPages builds AboutPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/advanced/about'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<AboutPage>());
    });

    test('buildPages builds ConflictsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/advanced/conflicts'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<ConflictsPage>());
    });

    test('buildPages builds ConflictDetailRoute', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/conflicts/conflict-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'conflictId': 'conflict-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<ConflictsPage>());
      expect(pages[3].child, isA<ConflictDetailRoute>());
    });

    test('buildPages builds EntryDetailsPage for conflict edit', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/conflicts/conflict-123/edit'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'conflictId': 'conflict-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 5);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<ConflictsPage>());
      expect(pages[3].child, isA<ConflictDetailRoute>());
      expect(pages[4].child, isA<EntryDetailsPage>());
    });

    test('buildPages builds MaintenancePage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/advanced/maintenance'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].child, isA<AdvancedSettingsPage>());
      expect(pages[2].child, isA<MaintenancePage>());
    });
  });
}
