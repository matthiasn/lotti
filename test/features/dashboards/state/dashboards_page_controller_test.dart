import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  group('DashboardsPageController', () {
    late MockJournalDb mockDb;
    late StreamController<List<DashboardDefinition>> streamController;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockJournalDb();
      streamController =
          StreamController<List<DashboardDefinition>>.broadcast();

      when(() => mockDb.watchDashboards())
          .thenAnswer((_) => streamController.stream);

      getIt.registerSingleton<JournalDb>(mockDb);

      container = ProviderContainer();
    });

    tearDown(() async {
      await streamController.close();
      container.dispose();
      await getIt.reset();
    });

    group('dashboardsProvider', () {
      test('initial state is loading', () {
        final state = container.read(dashboardsProvider);
        expect(state, const AsyncValue<List<DashboardDefinition>>.loading());
      });

      test('emits only active dashboards', () {
        fakeAsync((async) {
          final activeDashboard = testDashboardConfig;
          final inactiveDashboard = testDashboardConfig.copyWith(
            id: 'inactive-dashboard',
            active: false,
          );

          final states = <AsyncValue<List<DashboardDefinition>>>[];
          container.listen(
            dashboardsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([activeDashboard, inactiveDashboard]);
          async.flushMicrotasks();

          expect(states.length, greaterThanOrEqualTo(2));
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

          final states = <AsyncValue<List<DashboardDefinition>>>[];
          container.listen(
            dashboardsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([inactiveDashboard]);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, isEmpty);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Database error');
        final completer = Completer<void>();

        container.listen(
          dashboardsProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        streamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(dashboardsProvider);
        expect(state.hasError, isTrue);
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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboard1, dashboard2]);
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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboardB, dashboardA]);
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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboardUpper, dashboardLower]);
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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboard1, dashboard2, dashboard3]);
          async.flushMicrotasks();

          // Select category-1 filter
          container
              .read(selectedCategoryIdsProvider.notifier)
              .toggle('category-1');
          async.flushMicrotasks();

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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboard1, dashboard2, dashboard3]);
          async.flushMicrotasks();

          // Select multiple categories
          container.read(selectedCategoryIdsProvider.notifier)
            ..toggle('category-1')
            ..toggle('category-2');
          async.flushMicrotasks();

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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboard1, dashboardNoCategory]);
          async.flushMicrotasks();

          // Select category-1 filter
          container
              .read(selectedCategoryIdsProvider.notifier)
              .toggle('category-1');
          async.flushMicrotasks();

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

          container.listen(
            dashboardsProvider,
            (_, __) {},
            fireImmediately: true,
          );

          async.flushMicrotasks();

          streamController.add([dashboard1, dashboardNoCategory]);
          async.flushMicrotasks();

          final state = container.read(filteredSortedDashboardsProvider);
          expect(state.length, 2);
        });
      });
    });

    group('dashboardCategoriesProvider', () {
      late StreamController<List<CategoryDefinition>> categoryStreamController;

      setUp(() {
        categoryStreamController =
            StreamController<List<CategoryDefinition>>.broadcast();

        when(() => mockDb.watchCategories())
            .thenAnswer((_) => categoryStreamController.stream);
      });

      tearDown(() async {
        await categoryStreamController.close();
      });

      test('initial state is loading', () {
        final state = container.read(dashboardCategoriesProvider);
        expect(state, const AsyncValue<List<CategoryDefinition>>.loading());
      });

      test('emits categories from database stream', () {
        fakeAsync((async) {
          final states = <AsyncValue<List<CategoryDefinition>>>[];
          container.listen(
            dashboardCategoriesProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          categoryStreamController.add([categoryMindfulness]);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, [categoryMindfulness]);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Categories error');
        final completer = Completer<void>();

        container.listen(
          dashboardCategoriesProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        categoryStreamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(dashboardCategoriesProvider);
        expect(state.hasError, isTrue);
      });
    });
  });
}
