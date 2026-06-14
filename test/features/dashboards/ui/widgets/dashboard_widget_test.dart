import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockEntitiesCacheService mockCache;
  late MockHealthImport mockHealthImport;

  setUp(() async {
    mockHealthImport = MockHealthImport();
    when(
      () => mockHealthImport.getWorkoutsHealthDataDelta(),
    ).thenAnswer((_) async {});
    when(
      () => mockHealthImport.fetchHealthDataDelta(any()),
    ).thenAnswer((_) async {});

    await setUpTestGetIt(
      additionalSetup: () {
        mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        when(() => mockCache.getDashboardById(any())).thenReturn(null);
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<HealthImport>(mockHealthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('DashboardWidget', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);

    testWidgets('renders nothing when dashboard is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'non-existent',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            dashboardByIdProvider('non-existent').overrideWith((ref) => null),
          ],
        ),
      );
      await tester.pump();

      // DashboardWidget returns SizedBox.shrink() when dashboard is null
      expect(
        find.descendant(
          of: find.byType(DashboardWidget),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 0 && w.height == 0,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders dashboard description', (tester) async {
      final dashboard = DashboardDefinition(
        id: 'test-id',
        name: 'Test Dashboard',
        description: 'A test description',
        items: [],
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        version: '',
        lastReviewed: DateTime(2024, 3, 15),
        active: true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'test-id',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            dashboardByIdProvider('test-id').overrideWith((ref) => dashboard),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('A test description'), findsOneWidget);
    });

    testWidgets('shows title when showTitle is true', (tester) async {
      final dashboard = DashboardDefinition(
        id: 'test-id',
        name: 'My Dashboard',
        description: '',
        items: [],
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        version: '',
        lastReviewed: DateTime(2024, 3, 15),
        active: true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'test-id',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            showTitle: true,
          ),
          overrides: [
            dashboardByIdProvider('test-id').overrideWith((ref) => dashboard),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('My Dashboard'), findsOneWidget);
    });

    testWidgets(
      'builds DashboardHabitsChart for a habit item with propagated range',
      (tester) async {
        // getHabitById returns null so the inner HabitCompletionCard collapses
        // to SizedBox.shrink(), letting us assert on the DashboardWidget's own
        // wiring of the habit item without the habit controller/repository.
        when(() => mockCache.getHabitById(any())).thenReturn(null);

        final dashboard = DashboardDefinition(
          id: 'habit-dash',
          name: 'Habit Dashboard',
          description: 'desc',
          items: const [
            DashboardItem.habitChart(habitId: 'habit-123'),
          ],
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          version: '',
          lastReviewed: DateTime(2024, 3, 15),
          active: true,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardWidget(
              dashboardId: 'habit-dash',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              dashboardByIdProvider(
                'habit-dash',
              ).overrideWith((ref) => dashboard),
            ],
          ),
        );
        await tester.pump();

        // The habit case (lines 70-74) built a DashboardHabitsChart and
        // forwarded the habit id plus the dashboard's date range to it.
        final chart = tester.widget<DashboardHabitsChart>(
          find.byType(DashboardHabitsChart),
        );
        expect(chart.habitId, 'habit-123');
        expect(chart.rangeStart, rangeStart);
        expect(chart.rangeEnd, rangeEnd);
      },
    );

    testWidgets(
      'keys charts by item identity, not range, so stale data cannot cross '
      'items',
      (tester) async {
        when(() => mockCache.getHabitById(any())).thenReturn(null);

        DashboardDefinition twoHabits() => DashboardDefinition(
          id: 'k-dash',
          name: 'K',
          description: '',
          items: const [
            DashboardItem.habitChart(habitId: 'habit-A'),
            DashboardItem.habitChart(habitId: 'habit-B'),
          ],
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          version: '',
          lastReviewed: DateTime(2024, 3, 15),
          active: true,
        );

        Future<void> pumpAt(DateTime start) => tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardWidget(
              dashboardId: 'k-dash',
              rangeStart: start,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              dashboardByIdProvider(
                'k-dash',
              ).overrideWith((ref) => twoHabits()),
            ],
          ),
        );

        Set<Key?> habitChartKeys() => tester
            .widgetList<DashboardHabitsChart>(find.byType(DashboardHabitsChart))
            .map((c) => c.key)
            .toSet();

        await pumpAt(rangeStart);
        await tester.pump();

        // Each item gets a distinct identity key — so an item replaced at the
        // same index can never inherit another item's stale-while-revalidate
        // cache.
        expect(habitChartKeys(), {
          const ValueKey('habit:habit-A'),
          const ValueKey('habit:habit-B'),
        });

        // Changing only the range keeps the keys stable, so the charts keep
        // their State (and last data) across a time-span change.
        await pumpAt(rangeStart.subtract(const Duration(days: 30)));
        await tester.pump();
        expect(habitChartKeys(), {
          const ValueKey('habit:habit-A'),
          const ValueKey('habit:habit-B'),
        });
      },
    );
  });
}
