import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
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
import 'package:lotti/features/settings/ui/pages/settings_content_pane.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockUserActivityService extends Mock implements UserActivityService {}

class FakeConfigFlag extends Fake implements ConfigFlag {}

DesktopSettingsRoute _route(
  String path, {
  Map<String, String> pathParameters = const {},
  Map<String, String> queryParameters = const {},
}) => (
  path: path,
  pathParameters: pathParameters,
  queryParameters: queryParameters,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() {
    registerFallbackValue(FakeConfigFlag());
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockSyncDb = MockSyncDatabase();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockDb.watchConfigFlags(),
    ).thenAnswer((_) => Stream.value(<ConfigFlag>{}));
    when(
      () => mockDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
    when(mockSyncDb.watchOutboxCount).thenAnswer((_) => Stream.value(0));
    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<SyncDatabase>(mockSyncDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UserActivityService>(MockUserActivityService());

    ensureThemingServicesRegistered();
  });

  tearDown(getIt.reset);

  group('SettingsContentPane fully renderable routes', () {
    testWidgets('renders FlagsPage for /settings/flags', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(route: _route('/settings/flags')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlagsPage), findsOneWidget);
    });

    testWidgets('renders ThemingPage for /settings/theming', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(route: _route('/settings/theming')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThemingPage), findsOneWidget);
    });

    testWidgets('renders AdvancedSettingsPage for /settings/advanced', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(route: _route('/settings/advanced')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdvancedSettingsPage), findsOneWidget);
    });

    testWidgets(
      'renders LoggingSettingsPage for /settings/advanced/logging_domains',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            SettingsContentPane(
              route: _route('/settings/advanced/logging_domains'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoggingSettingsPage), findsOneWidget);
      },
    );

    testWidgets('renders SizedBox.shrink for unknown route', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(
            route: _route('/settings/nonexistent'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  // These tests verify the routing logic via resolveRoute() — a pure function
  // that returns the correct widget type without mounting it into the tree.
  // This avoids needing complex service registrations for each page.
  group('SettingsContentPane resolveRoute unit tests', () {
    // Advanced sub-pages
    test('advanced/logging_domains → LoggingSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/advanced/logging_domains'),
      );
      expect(widget, isA<LoggingSettingsPage>());
    });

    test('advanced/about → AboutPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/advanced/about'),
      );
      expect(widget, isA<AboutPage>());
    });

    test('advanced/maintenance → MaintenancePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/advanced/maintenance'),
      );
      expect(widget, isA<MaintenancePage>());
    });

    test('advanced/conflicts → ConflictsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/advanced/conflicts'),
      );
      expect(widget, isA<ConflictsPage>());
    });

    test('advanced/conflicts/:conflictId → ConflictDetailRoute', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/advanced/conflicts/c-1',
          pathParameters: {'conflictId': 'c-1'},
        ),
      );
      expect(widget, isA<ConflictDetailRoute>());
    });

    test('advanced/conflicts/:conflictId/edit → EntryDetailsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/advanced/conflicts/c-1/edit',
          pathParameters: {'conflictId': 'c-1'},
        ),
      );
      expect(widget, isA<EntryDetailsPage>());
    });

    test('advanced → AdvancedSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/advanced'),
      );
      expect(widget, isA<AdvancedSettingsPage>());
    });

    // AI
    test('ai/profiles → InferenceProfilePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/ai/profiles'),
      );
      expect(widget, isA<InferenceProfilePage>());
    });

    test('ai → AiSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/ai'),
      );
      expect(widget, isA<AiSettingsPage>());
    });

    // Sync
    test('sync/matrix/maintenance → MatrixSyncMaintenancePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/sync/matrix/maintenance'),
      );
      expect(widget, isA<MatrixSyncMaintenancePage>());
    });

    test('sync/backfill → BackfillSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/sync/backfill'),
      );
      expect(widget, isA<BackfillSettingsPage>());
    });

    test('sync/stats → SyncStatsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/sync/stats'),
      );
      expect(widget, isA<SyncStatsPage>());
    });

    test('sync/outbox → OutboxMonitorPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/sync/outbox'),
      );
      expect(widget, isA<OutboxMonitorPage>());
    });

    test('sync → SyncSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/sync'),
      );
      expect(widget, isA<SyncSettingsPage>());
    });

    // Labels
    test('labels/create → LabelDetailsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/labels/create', queryParameters: {'name': 'test'}),
      );
      expect(widget, isA<LabelDetailsPage>());
    });

    test('labels/:labelId → LabelDetailsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/labels/lbl-1',
          pathParameters: {'labelId': 'lbl-1'},
        ),
      );
      expect(widget, isA<LabelDetailsPage>());
    });

    test('labels → LabelsListPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/labels'),
      );
      expect(widget, isA<LabelsListPage>());
    });

    // Categories
    test('categories/create → CategoryDetailsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/categories/create'),
      );
      expect(widget, isA<CategoryDetailsPage>());
    });

    test('categories/:categoryId → CategoryDetailsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/categories/cat-1',
          pathParameters: {'categoryId': 'cat-1'},
        ),
      );
      expect(widget, isA<CategoryDetailsPage>());
    });

    test('categories → CategoriesListPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/categories'),
      );
      expect(widget, isA<CategoriesListPage>());
    });

    // Projects
    test('projects/create → ProjectCreatePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/projects/create'),
      );
      expect(widget, isA<ProjectCreatePage>());
    });

    test('projects/:projectId → ProjectDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/projects/prj-1',
          pathParameters: {'projectId': 'prj-1'},
        ),
      );
      expect(widget, isA<ProjectDetailPage>());
    });

    // Dashboards
    test('dashboards/create → CreateDashboardPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/dashboards/create'),
      );
      expect(widget, isA<CreateDashboardPage>());
    });

    test('dashboards/:dashboardId → EditDashboardPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/dashboards/d-1',
          pathParameters: {'dashboardId': 'd-1'},
        ),
      );
      expect(widget, isA<EditDashboardPage>());
    });

    test('dashboards → DashboardSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/dashboards'),
      );
      expect(widget, isA<DashboardSettingsPage>());
    });

    // Measurables
    test('measurables/create → CreateMeasurablePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/measurables/create'),
      );
      expect(widget, isA<CreateMeasurablePage>());
    });

    test('measurables/:measurableId → EditMeasurablePage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/measurables/m-1',
          pathParameters: {'measurableId': 'm-1'},
        ),
      );
      expect(widget, isA<EditMeasurablePage>());
    });

    test('measurables → MeasurablesPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/measurables'),
      );
      expect(widget, isA<MeasurablesPage>());
    });

    // Habits
    test('habits/create → CreateHabitPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/habits/create'),
      );
      expect(widget, isA<CreateHabitPage>());
    });

    test('habits/by_id/:habitId → EditHabitPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/habits/by_id/h-1',
          pathParameters: {'habitId': 'h-1'},
        ),
      );
      expect(widget, isA<EditHabitPage>());
    });

    test('habits/search/:searchTerm → HabitsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/habits/search/foo',
          pathParameters: {'searchTerm': 'foo'},
        ),
      );
      expect(widget, isA<HabitsPage>());
    });

    test('habits → HabitsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/habits'),
      );
      expect(widget, isA<HabitsPage>());
    });

    // Agents
    test('agents/templates/create → AgentTemplateDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/agents/templates/create'),
      );
      expect(widget, isA<AgentTemplateDetailPage>());
    });

    test('agents/templates/:templateId/review → EvolutionReviewPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/agents/templates/t-1/review',
          pathParameters: {'templateId': 't-1'},
        ),
      );
      expect(widget, isA<EvolutionReviewPage>());
    });

    test('agents/templates/:templateId → AgentTemplateDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/agents/templates/t-1',
          pathParameters: {'templateId': 't-1'},
        ),
      );
      expect(widget, isA<AgentTemplateDetailPage>());
    });

    test('agents/souls/create → AgentSoulDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/agents/souls/create'),
      );
      expect(widget, isA<AgentSoulDetailPage>());
    });

    test('agents/souls/:soulId/review → SoulEvolutionReviewPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/agents/souls/s-1/review',
          pathParameters: {'soulId': 's-1'},
        ),
      );
      expect(widget, isA<SoulEvolutionReviewPage>());
    });

    test('agents/souls/:soulId → AgentSoulDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/agents/souls/s-1',
          pathParameters: {'soulId': 's-1'},
        ),
      );
      expect(widget, isA<AgentSoulDetailPage>());
    });

    test('agents/instances/:agentId → AgentDetailPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route(
          '/settings/agents/instances/a-1',
          pathParameters: {'agentId': 'a-1'},
        ),
      );
      expect(widget, isA<AgentDetailPage>());
    });

    test('agents → AgentSettingsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/agents'),
      );
      expect(widget, isA<AgentSettingsPage>());
    });

    // Flags, Theming, Health Import
    test('flags → FlagsPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/flags'),
      );
      expect(widget, isA<FlagsPage>());
    });

    test('theming → ThemingPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/theming'),
      );
      expect(widget, isA<ThemingPage>());
    });

    test('health_import → HealthImportPage', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/health_import'),
      );
      expect(widget, isA<HealthImportPage>());
    });

    // Fallback
    test('unknown route → SizedBox', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/settings/nonexistent'),
      );
      expect(widget, isA<SizedBox>());
    });
  });

  group('SettingsContentPane routing correctness', () {
    testWidgets(
      '/settings/advanced does not match /settings/advanced_foo',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            SettingsContentPane(
              route: _route('/settings/advanced_foo'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // startsWith('/settings/advanced') matches — acceptable since
        // Beamer only produces real routes, but documents the boundary.
        expect(find.byType(AdvancedSettingsPage), findsOneWidget);
      },
    );

    testWidgets('deeply nested advanced route resolves correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(
            route: _route('/settings/advanced/logging_domains'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must match the deeper route, not fall through to AdvancedSettingsPage
      expect(find.byType(LoggingSettingsPage), findsOneWidget);
      expect(find.byType(AdvancedSettingsPage), findsNothing);
    });

    testWidgets('/settings/flags does not render for /other/flags', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsContentPane(
            route: _route('/other/flags'),
          ),
        ),
      );
      await tester.pump();

      // Should hit fallback because startsWith prevents substring matching
      expect(find.byType(FlagsPage), findsNothing);
    });

    test('resolveRoute: /other/flags hits fallback', () {
      final widget = SettingsContentPane.resolveRoute(
        _route('/other/flags'),
      );
      expect(widget, isA<SizedBox>());
    });
  });
}
