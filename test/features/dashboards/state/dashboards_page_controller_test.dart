import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class _MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  group('DashboardsPageController', () {
    late MockJournalDb mockDb;
    late _MockUpdateNotifications mockNotifications;
    late StreamController<Set<String>> notificationController;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockJournalDb();
      mockNotifications = _MockUpdateNotifications();
      notificationController = StreamController<Set<String>>.broadcast();

      when(() => mockNotifications.updateStream)
          .thenAnswer((_) => notificationController.stream);

      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<UpdateNotifications>(mockNotifications);

      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await notificationController.close();
      await getIt.reset();
    });

    group('dashboardsProvider', () {
      test('emits only active dashboards from initial fetch', () {
        fakeAsync((async) {
          final activeDashboard = testDashboardConfig;
          final inactiveDashboard = testDashboardConfig.copyWith(
            id: 'inactive-dashboard',
            active: false,
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [activeDashboard, inactiveDashboard]);

          final states = <AsyncValue<List<DashboardDefinition>>>[];
          container.listen(
            dashboardsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, [activeDashboard]);
          expect(
            states.last.value!.any((d) => d.id == 'inactive-dashboard'),
            isFalse,
          );
        });
      });

      test('emits empty list when all dashboards are inactive', () {
        fakeAsync((async) {
          final inactiveDashboard = testDashboardConfig.copyWith(active: false);

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [inactiveDashboard]);

          final states = <AsyncValue<List<DashboardDefinition>>>[];
          container.listen(
            dashboardsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, isEmpty);
        });
      });

      test('handles fetcher errors', () {
        fakeAsync((async) {
          final error = Exception('Database error');

          when(() => mockDb.getAllDashboards()).thenThrow(error);

          container.listen(dashboardsProvider, (_, __) {});

          async.flushMicrotasks();

          final state = container.read(dashboardsProvider);
          expect(state.hasError, isTrue);
        });
      });
    });

    group('selectedCategoryIdsProvider', () {
      test('initial state is empty set', () {
        final state = container.read(selectedCategoryIdsProvider);
        expect(state, isEmpty);
      });

      test('toggle adds category id when not present', () {
        container
            .read(selectedCategoryIdsProvider.notifier)
            .toggle('category-1');

        final state = container.read(selectedCategoryIdsProvider);
        expect(state, {'category-1'});
      });

      test('toggle removes category id when already present', () {
        container.read(selectedCategoryIdsProvider.notifier)
          ..toggle('category-1')
          ..toggle('category-1');

        final state = container.read(selectedCategoryIdsProvider);
        expect(state, isEmpty);
      });

      test('toggle handles multiple categories', () {
        container.read(selectedCategoryIdsProvider.notifier)
          ..toggle('category-1')
          ..toggle('category-2');

        var state = container.read(selectedCategoryIdsProvider);
        expect(state, {'category-1', 'category-2'});

        container
            .read(selectedCategoryIdsProvider.notifier)
            .toggle('category-1');
        state = container.read(selectedCategoryIdsProvider);
        expect(state, {'category-2'});
      });

      test('clear removes all category ids', () {
        container.read(selectedCategoryIdsProvider.notifier)
          ..toggle('category-1')
          ..toggle('category-2')
          ..clear();

        final state = container.read(selectedCategoryIdsProvider);
        expect(state, isEmpty);
      });
    });

    group('filteredSortedDashboardsProvider', () {
      test('returns empty list when dashboards are loading', () {
        // Don't stub getAllDashboards — the provider won't have data yet
        when(() => mockDb.getAllDashboards())
            .thenAnswer((_) => Completer<List<DashboardDefinition>>().future);

        final state = container.read(filteredSortedDashboardsProvider);
        expect(state, isEmpty);
      });

      test('returns all dashboards when no category filter selected', () {
        fakeAsync((async) {
          final dashboard1 = testDashboardConfig.copyWith(
            id: 'dashboard-b',
            name: 'B Dashboard',
          );
          final dashboard2 = testDashboardConfig.copyWith(
            id: 'dashboard-a',
            name: 'A Dashboard',
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard1, dashboard2]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
        });
      });

      test('sorts dashboards by name alphabetically', () {
        fakeAsync((async) {
          final dashboardB = testDashboardConfig.copyWith(
            id: 'dashboard-b',
            name: 'Zulu Dashboard',
          );
          final dashboardA = testDashboardConfig.copyWith(
            id: 'dashboard-a',
            name: 'Alpha Dashboard',
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboardB, dashboardA]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
          expect(state[0].name, 'Alpha Dashboard');
          expect(state[1].name, 'Zulu Dashboard');
        });
      });

      test('sorts case-insensitively', () {
        fakeAsync((async) {
          final dashboardLower = testDashboardConfig.copyWith(
            id: 'dashboard-1',
            name: 'alpha Dashboard',
          );
          final dashboardUpper = testDashboardConfig.copyWith(
            id: 'dashboard-2',
            name: 'Beta Dashboard',
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboardUpper, dashboardLower]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state[0].name, 'alpha Dashboard');
          expect(state[1].name, 'Beta Dashboard');
        });
      });

      test('filters dashboards by selected category', () {
        fakeAsync((async) {
          final dashboard1 = testDashboardConfig.copyWith(
            id: 'dashboard-1',
            name: 'Dashboard 1',
            categoryId: 'category-1',
          );
          final dashboard2 = testDashboardConfig.copyWith(
            id: 'dashboard-2',
            name: 'Dashboard 2',
            categoryId: 'category-2',
          );
          final dashboard3 = testDashboardConfig.copyWith(
            id: 'dashboard-3',
            name: 'Dashboard 3',
            categoryId: 'category-1',
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard1, dashboard2, dashboard3]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          // Select category-1 filter
          container
              .read(selectedCategoryIdsProvider.notifier)
              .toggle('category-1');

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
          expect(state.every((d) => d.categoryId == 'category-1'), isTrue);
        });
      });

      test('filters by multiple selected categories', () {
        fakeAsync((async) {
          final dashboard1 = testDashboardConfig.copyWith(
            id: 'dashboard-1',
            name: 'Dashboard 1',
            categoryId: 'category-1',
          );
          final dashboard2 = testDashboardConfig.copyWith(
            id: 'dashboard-2',
            name: 'Dashboard 2',
            categoryId: 'category-2',
          );
          final dashboard3 = testDashboardConfig.copyWith(
            id: 'dashboard-3',
            name: 'Dashboard 3',
            categoryId: 'category-3',
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard1, dashboard2, dashboard3]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          // Select multiple categories
          container.read(selectedCategoryIdsProvider.notifier)
            ..toggle('category-1')
            ..toggle('category-2');

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
          expect(
            state.every(
              (d) =>
                  d.categoryId == 'category-1' || d.categoryId == 'category-2',
            ),
            isTrue,
          );
        });
      });

      test('excludes dashboards with null categoryId when filter is active',
          () {
        fakeAsync((async) {
          final dashboard1 = testDashboardConfig.copyWith(
            id: 'dashboard-1',
            name: 'Dashboard 1',
            categoryId: 'category-1',
          );
          final dashboardNoCategory = testDashboardConfig.copyWith(
            id: 'dashboard-2',
            name: 'Dashboard 2',
            categoryId: null,
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard1, dashboardNoCategory]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          // Select category-1 filter
          container
              .read(selectedCategoryIdsProvider.notifier)
              .toggle('category-1');

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 1);
          expect(state[0].id, 'dashboard-1');
        });
      });

      test('includes dashboards with null categoryId when no filter is active',
          () {
        fakeAsync((async) {
          final dashboard1 = testDashboardConfig.copyWith(
            id: 'dashboard-1',
            name: 'Dashboard 1',
            categoryId: 'category-1',
          );
          final dashboardNoCategory = testDashboardConfig.copyWith(
            id: 'dashboard-2',
            name: 'Dashboard 2',
            categoryId: null,
          );

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard1, dashboardNoCategory]);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
        });
      });
    });

    group('dashboardCategoriesProvider', () {
      test('emits categories from initial fetch', () {
        fakeAsync((async) {
          when(() => mockDb.getAllCategories())
              .thenAnswer((_) async => [categoryMindfulness]);

          final states = <AsyncValue<List<CategoryDefinition>>>[];
          container.listen(
            dashboardCategoriesProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, [categoryMindfulness]);
        });
      });

      test('handles fetcher errors', () {
        fakeAsync((async) {
          final error = Exception('Categories error');

          when(() => mockDb.getAllCategories()).thenThrow(error);

          container.listen(dashboardCategoriesProvider, (_, __) {});

          async.flushMicrotasks();

          final state = container.read(dashboardCategoriesProvider);
          expect(state.hasError, isTrue);
        });
      });
    });

    group('dashboardByIdProvider', () {
      late MockEntitiesCacheService mockEntitiesCacheService;

      setUp(() {
        mockEntitiesCacheService = MockEntitiesCacheService();
        getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      });

      test('returns dashboard from cache when found', () {
        fakeAsync((async) {
          final dashboard = testDashboardConfig;

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard]);
          when(() => mockEntitiesCacheService.getDashboardById(dashboard.id))
              .thenReturn(dashboard);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final result = container.read(dashboardByIdProvider(dashboard.id));
          expect(result, dashboard);
        });
      });

      test('returns null when dashboard not found in cache', () {
        fakeAsync((async) {
          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [testDashboardConfig]);
          when(() => mockEntitiesCacheService.getDashboardById('unknown-id'))
              .thenReturn(null);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          final result = container.read(dashboardByIdProvider('unknown-id'));
          expect(result, isNull);
        });
      });

      test('rebuilds when dashboards stream updates via notification', () {
        fakeAsync((async) {
          final dashboard = testDashboardConfig;
          final updatedDashboard = dashboard.copyWith(name: 'Updated Name');

          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [dashboard]);
          when(() => mockEntitiesCacheService.getDashboardById(dashboard.id))
              .thenReturn(dashboard);

          container.listen(dashboardsProvider, (_, __) {});
          async.flushMicrotasks();

          var result = container.read(dashboardByIdProvider(dashboard.id));
          expect(result?.name, dashboard.name);

          // Update stubs for the next fetch
          when(() => mockDb.getAllDashboards())
              .thenAnswer((_) async => [updatedDashboard]);
          when(() => mockEntitiesCacheService.getDashboardById(dashboard.id))
              .thenReturn(updatedDashboard);

          // Fire notification to trigger refetch
          notificationController.add({dashboardsNotification});
          async
            ..elapse(const Duration(milliseconds: 50))
            ..flushMicrotasks();

          result = container.read(dashboardByIdProvider(dashboard.id));
          expect(result?.name, 'Updated Name');
        });
      });
    });
  });
}
