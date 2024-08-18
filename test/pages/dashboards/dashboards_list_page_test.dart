import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

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
  });
}
