import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('DashboardDefinitionPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      final mockEntitiesCacheService = MockEntitiesCacheService();

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness],
        ]),
      );

      when(mockJournalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          [habitFlossing],
        ]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDown(getIt.reset);

    testWidgets('dashboard list page is displayed with two test dashboards',
        (tester) async {
      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      verify(mockJournalDb.watchDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);

      final categoryFilterFinder =
          find.byKey(const Key('dashboard_category_filter'));
      expect(categoryFilterFinder, findsOneWidget);

      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('dashboards are sorted alphabetically by name', (tester) async {
      final dashboardZ = testDashboardConfig.copyWith(
        id: 'dashboard-z',
        name: 'Zebra Dashboard',
      );
      final dashboardA = testDashboardConfig.copyWith(
        id: 'dashboard-a',
        name: 'Alpha Dashboard',
      );

      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [dashboardZ, dashboardA],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Alpha should appear before Zebra
      final alphaFinder = find.text('Alpha Dashboard');
      final zebraFinder = find.text('Zebra Dashboard');

      expect(alphaFinder, findsOneWidget);
      expect(zebraFinder, findsOneWidget);

      // Verify ordering by checking positions
      final alphaPosition = tester.getCenter(alphaFinder);
      final zebraPosition = tester.getCenter(zebraFinder);
      expect(alphaPosition.dy, lessThan(zebraPosition.dy));
    });

    testWidgets('filter modal shows category chips', (tester) async {
      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [testDashboardConfig],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap filter button to open modal
      final categoryFilterFinder =
          find.byKey(const Key('dashboard_category_filter'));
      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();

      // Modal should show category chip
      expect(find.text(categoryMindfulness.name), findsOneWidget);
    });

    testWidgets('tapping category chip toggles filter selection',
        (tester) async {
      final dashboardWithCategory = testDashboardConfig.copyWith(
        categoryId: categoryMindfulness.id,
      );
      final dashboardWithoutCategory = emptyTestDashboardConfig.copyWith(
        categoryId: null,
      );

      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [dashboardWithCategory, dashboardWithoutCategory],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both dashboards should be visible initially
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Test Dashboard #2 - empty'), findsOneWidget);

      // Open filter modal
      final categoryFilterFinder =
          find.byKey(const Key('dashboard_category_filter'));
      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();

      // Tap the category chip to filter
      final categoryChip = find.text(categoryMindfulness.name);
      expect(categoryChip, findsOneWidget);
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();

      // Close the modal
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Only dashboard with category should be visible
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Test Dashboard #2 - empty'), findsNothing);
    });

    testWidgets('only active dashboards are displayed', (tester) async {
      final activeDashboard = testDashboardConfig.copyWith(active: true);
      final inactiveDashboard = emptyTestDashboardConfig.copyWith(
        active: false,
        name: 'Inactive Dashboard',
      );

      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [activeDashboard, inactiveDashboard],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only active dashboard should be visible
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Inactive Dashboard'), findsNothing);
    });
  });
}
