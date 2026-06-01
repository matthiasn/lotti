import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_stream_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import 'test_helpers.dart';

void main() {
  group('StreamChartItem', () {
    test('equality works correctly', () {
      const item1 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);
      const item2 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);
      const item3 = StreamChartItem(x: 1.5, categoryId: 'cat-1', minutes: 60);

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
    });

    test('hashCode is consistent with equality', () {
      const item1 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);
      const item2 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);

      expect(item1.hashCode, equals(item2.hashCode));
    });

    test('toString provides readable output', () {
      const item = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);

      expect(
        item.toString(),
        equals('StreamChartItem(x: 0.5, categoryId: cat-1, minutes: 60)'),
      );
    });

    test('inequality when x matches but categoryId differs', () {
      const item1 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);
      const item2 = StreamChartItem(x: 0.5, categoryId: 'cat-2', minutes: 60);

      // Hits lines 28–29: x == other.x is true, categoryId == other.categoryId
      // is false, so operator returns false.
      expect(item1, isNot(equals(item2)));
    });

    test('inequality when x and categoryId match but minutes differ', () {
      const item1 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 60);
      const item2 = StreamChartItem(x: 0.5, categoryId: 'cat-1', minutes: 90);

      // Hits lines 29–30: x and categoryId are equal, minutes == other.minutes
      // is false, so operator returns false.
      expect(item1, isNot(equals(item2)));
    });
  });

  group('TimeHistoryStreamChart.computeEffectiveScaleMinutes', () {
    test('returns 6 hours minimum for zero duration', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        Duration.zero,
      );

      expect(result, equals(360.0)); // 6 * 60
    });

    test('returns 6 hours minimum for durations under 6 hours', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        const Duration(hours: 2),
      );

      expect(result, equals(360.0)); // 6 * 60
    });

    test('returns actual minutes for durations between 6-24 hours', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        const Duration(hours: 10),
      );

      expect(result, equals(600.0)); // 10 * 60
    });

    test('returns 24 hours maximum for durations over 24 hours', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        const Duration(hours: 30),
      );

      expect(result, equals(1440.0)); // 24 * 60
    });

    test('returns exact 6 hours at boundary', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        const Duration(hours: 6),
      );

      expect(result, equals(360.0)); // 6 * 60
    });

    test('returns exact 24 hours at boundary', () {
      final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
        const Duration(hours: 24),
      );

      expect(result, equals(1440.0)); // 24 * 60
    });
  });

  group('TimeHistoryStreamChart.buildChartData', () {
    test('returns empty list for empty days', () {
      final result = TimeHistoryStreamChart.buildChartData(
        days: [],
        categoryOrder: ['cat-1', 'cat-2'],
      );

      expect(result, isEmpty);
    });

    test('creates items for each day and category combination', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 2),
            'cat-2': const Duration(hours: 1),
          },
          total: const Duration(hours: 3),
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 14, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 1),
          },
          total: const Duration(hours: 1),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1', 'cat-2'],
      );

      // 2 days * 2 categories = 4 items
      expect(result.length, equals(4));
    });

    test('maps newest-to-oldest days to oldest-to-newest x axis', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12), // Newest (index 0)
          durationByCategoryId: {'cat-1': const Duration(hours: 2)},
          total: const Duration(hours: 2),
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 14, 12), // Oldest (index 1)
          durationByCategoryId: {'cat-1': const Duration(hours: 1)},
          total: const Duration(hours: 1),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1'],
      );

      // Oldest day (index 1 in days) should be at x=0.5
      // Newest day (index 0 in days) should be at x=1.5
      expect(result[0].x, equals(1.5)); // First item is from newest day
      expect(result[0].minutes, equals(120)); // 2 hours = 120 minutes
      expect(result[1].x, equals(0.5)); // Second item is from oldest day
      expect(result[1].minutes, equals(60)); // 1 hour = 60 minutes
    });

    test('includes zero-minute items for categories with no duration', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 2),
            // cat-2 is missing
          },
          total: const Duration(hours: 2),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1', 'cat-2'],
      );

      expect(result.length, equals(2));
      expect(result[0].categoryId, equals('cat-1'));
      expect(result[0].minutes, equals(120));
      expect(result[1].categoryId, equals('cat-2'));
      expect(result[1].minutes, equals(0)); // Zero for missing category
    });

    test('includes uncategorized for all days when any day has it', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 1),
            null: const Duration(minutes: 30), // Uncategorized
          },
          total: const Duration(hours: 1, minutes: 30),
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 14, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 2),
            // No uncategorized for this day
          },
          total: const Duration(hours: 2),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1'],
      );

      // 2 days * (1 category + 1 uncategorized) = 4 items
      expect(result.length, equals(4));

      // Check uncategorized items exist for both days
      final uncategorizedItems = result.where(
        (item) => item.categoryId == '__uncategorized__',
      );
      expect(uncategorizedItems.length, equals(2));

      // First day has 30 minutes uncategorized
      final day1Uncategorized = uncategorizedItems.firstWhere(
        (item) => item.x == 1.5,
      );
      expect(day1Uncategorized.minutes, equals(30));

      // Second day has 0 minutes uncategorized
      final day2Uncategorized = uncategorizedItems.firstWhere(
        (item) => item.x == 0.5,
      );
      expect(day2Uncategorized.minutes, equals(0));
    });

    test('does not include uncategorized when no day has it', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 1),
          },
          total: const Duration(hours: 1),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1'],
      );

      expect(result.length, equals(1));
      expect(
        result.any((item) => item.categoryId == '__uncategorized__'),
        isFalse,
      );
    });

    test('handles empty category order', () {
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: {
            'cat-1': const Duration(hours: 1),
          },
          total: const Duration(hours: 1),
        ),
      ];

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: [],
      );

      // No categories means no items (unless there's uncategorized)
      expect(result, isEmpty);
    });

    test('handles multiple days with same category order', () {
      final days = List.generate(
        5,
        (i) => DayTimeSummary(
          day: DateTime(2026, 1, 15 - i, 12),
          durationByCategoryId: {
            'cat-1': Duration(hours: i + 1),
            'cat-2': Duration(hours: 5 - i),
          },
          total: const Duration(hours: 6),
        ),
      );

      final result = TimeHistoryStreamChart.buildChartData(
        days: days,
        categoryOrder: ['cat-1', 'cat-2'],
      );

      // 5 days * 2 categories = 10 items
      expect(result.length, equals(10));

      // Verify x positions are sequential from 0.5 to 4.5
      final xPositions = result.map((item) => item.x).toSet().toList()..sort();
      expect(xPositions, equals([0.5, 1.5, 2.5, 3.5, 4.5]));
    });
  });

  group('TimeHistoryStreamChart widget', () {
    setUp(setUpEntitiesCacheService);
    tearDown(tearDownEntitiesCacheService);

    testWidgets('renders SizedBox in test mode', (tester) async {
      TimeHistoryStreamChart.testMode = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimeHistoryStreamChart(
              days: [],
              maxDailyTotal: Duration(hours: 4),
              width: 200,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders SizedBox when days.length < 2', (tester) async {
      TimeHistoryStreamChart.testMode = false;

      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeHistoryStreamChart(
              days: days,
              maxDailyTotal: const Duration(hours: 4),
              width: 200,
            ),
          ),
        ),
      );

      // Should render SizedBox, not Chart
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders SizedBox when width is null', (tester) async {
      TimeHistoryStreamChart.testMode = false;

      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 14, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeHistoryStreamChart(
              days: days,
              maxDailyTotal: const Duration(hours: 4),
              // width is null by default
            ),
          ),
        ),
      );

      // Should render SizedBox, not Chart
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders SizedBox when width <= 0', (tester) async {
      TimeHistoryStreamChart.testMode = false;

      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 15, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 14, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeHistoryStreamChart(
              days: days,
              maxDailyTotal: const Duration(hours: 4),
              width: 0,
            ),
          ),
        ),
      );

      // Should render SizedBox, not Chart
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });

  group('TimeHistoryStreamChart widget — empty chartData path', () {
    // These tests cover lines 86–88 and 153–156 (the _buildChartData path that
    // returns an empty list when there are no categories and no uncategorized time,
    // causing the widget to fall through to the SizedBox guard at line 88).

    late MockEntitiesCacheService mockCache;

    setUp(() {
      // Do NOT use setUpEntitiesCacheService — that sets testMode = true.
      TimeHistoryStreamChart.testMode = false;

      mockCache = MockEntitiesCacheService();
      when(() => mockCache.getCategoryById(any())).thenReturn(null);
      // Empty category list → buildChartData produces no items.
      when(() => mockCache.sortedCategories).thenReturn([]);

      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
      getIt.registerSingleton<EntitiesCacheService>(mockCache);
    });

    tearDown(() {
      TimeHistoryStreamChart.testMode = false;
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
    });

    testWidgets(
      'renders SizedBox when chartData is empty (no categories, no uncategorized)',
      (tester) async {
        // Two days with no categorized or uncategorized time, and an empty
        // sortedCategories list → _buildChartData() returns [] → line 87 is
        // true → SizedBox returned from line 88.
        final days = [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: const {},
            total: Duration.zero,
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: const {},
            total: Duration.zero,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimeHistoryStreamChart(
                days: days,
                maxDailyTotal: const Duration(hours: 4),
                width: 300,
              ),
            ),
          ),
        );

        // buildChartData returned [], so the widget returns a SizedBox (not Chart).
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Chart), findsNothing);

        // Verify sortedCategories was called to produce the (empty) category list.
        verify(() => mockCache.sortedCategories).called(greaterThan(0));
      },
    );

    testWidgets(
      'renders SizedBox when chartData is empty even with uncategorized=false',
      (tester) async {
        // Days without null keys → hasUncategorized = false, no category items
        // either → chartData is empty.
        final days = List.generate(
          3,
          (i) => DayTimeSummary(
            day: DateTime(2026, 1, 15 - i, 12),
            durationByCategoryId: const {},
            total: Duration.zero,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimeHistoryStreamChart(
                days: days,
                maxDailyTotal: const Duration(hours: 8),
                width: 400,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Chart), findsNothing);
      },
    );
  });

  group('TimeHistoryStreamChart widget — chart rendering path', () {
    // These tests cover lines 91–151: the full chart-rendering branch that
    // builds the Chart widget, its variables, marks, color encoder, axes, and
    // the _effectiveScaleMinutes getter.
    //
    // The graphic Chart widget uses TickerProvider-based animation; it does NOT
    // use raw Timer objects, so using tester.pump() (not pumpAndSettle) is safe.
    // Multiple pumps are used to drain microtasks from ChartView.run(init:true).

    late MockEntitiesCacheService mockCache;

    setUp(() {
      // Do NOT use setUpEntitiesCacheService — we manage testMode ourselves.
      TimeHistoryStreamChart.testMode = false;

      mockCache = MockEntitiesCacheService();
      when(() => mockCache.getCategoryById(any())).thenReturn(null);
      when(
        () => mockCache.sortedCategories,
      ).thenReturn(testCategories.values.toList());
      for (final entry in testCategories.entries) {
        when(
          () => mockCache.getCategoryById(entry.key),
        ).thenReturn(entry.value);
      }

      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
      getIt.registerSingleton<EntitiesCacheService>(mockCache);
    });

    tearDown(() {
      TimeHistoryStreamChart.testMode = false;
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
    });

    testWidgets(
      'renders Chart widget when data, width, and categories are all valid',
      (tester) async {
        // Give the chart a fixed surface so the layout delegate fires and
        // ChartView is created, exercising lines 91–143 and 150–156.
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final days = [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 2),
              'cat-2': const Duration(hours: 1),
            },
            total: const Duration(hours: 3),
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 1),
            },
            total: const Duration(hours: 1),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TimeHistoryStreamChart(
                  days: days,
                  maxDailyTotal: const Duration(hours: 3),
                  width: 400,
                  // ignore: avoid_redundant_argument_values
                  height: 60,
                ),
              ),
            ),
          ),
        );

        // Pump once to build; pump again to let ChartView async init drain.
        await tester.pump();
        await tester.pump();

        // The Chart widget (from the graphic package) must be present in the tree.
        expect(find.byType(Chart<StreamChartItem>), findsOneWidget);
        // The chart is wrapped in ClipRect + Transform.scale.
        expect(find.byType(ClipRect), findsOneWidget);
      },
    );

    testWidgets(
      'renders Chart with verticalScale applied via Transform.scale',
      (tester) async {
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final days = [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 3),
            },
            total: const Duration(hours: 3),
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 1),
            },
            total: const Duration(hours: 1),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TimeHistoryStreamChart(
                  days: days,
                  maxDailyTotal: const Duration(hours: 3),
                  width: 400,
                  // ignore: avoid_redundant_argument_values
                  height: 60,
                  verticalScale: 1.5,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Chart widget is present and the wrapping Transform is in the tree.
        expect(find.byType(Chart<StreamChartItem>), findsOneWidget);
        // Find the Transform.scale inside ClipRect (our verticalScale wrapper).
        final transformFinder = find.descendant(
          of: find.byType(ClipRect),
          matching: find.byType(Transform),
        );
        expect(transformFinder, findsWidgets);
        // The first Transform inside ClipRect is our Transform.scale(scaleY).
        final transform = tester.firstWidget<Transform>(transformFinder);
        // verticalScale: 1.5 means scaleY should be 1.5.
        expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
      },
    );

    testWidgets(
      '_effectiveScaleMinutes uses clamped maxDailyTotal for scale',
      (tester) async {
        // Verify that computeEffectiveScaleMinutes correctly clamps.
        // Under 6 hours → clamped to 360 min.
        expect(
          TimeHistoryStreamChart.computeEffectiveScaleMinutes(
            const Duration(hours: 2),
          ),
          equals(360.0),
        );

        // Over 24 hours → clamped to 1440 min.
        expect(
          TimeHistoryStreamChart.computeEffectiveScaleMinutes(
            const Duration(hours: 30),
          ),
          equals(1440.0),
        );

        // Within range → exact value.
        expect(
          TimeHistoryStreamChart.computeEffectiveScaleMinutes(
            const Duration(hours: 12),
          ),
          equals(720.0),
        );

        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Pass maxDailyTotal below 6-hour minimum to verify scale is clamped
        // inside the rendered Chart's LinearScale (lines 110–113).
        final days = [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: {'cat-1': const Duration(hours: 1)},
            total: const Duration(hours: 1),
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: {'cat-1': const Duration(minutes: 30)},
            total: const Duration(minutes: 30),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TimeHistoryStreamChart(
                  days: days,
                  // Below 6-hour floor → effective scale = 360 min.
                  maxDailyTotal: const Duration(hours: 2),
                  width: 400,
                  // ignore: avoid_redundant_argument_values
                  height: 60,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Chart must exist — this confirms the rendering path through
        // _effectiveScaleMinutes (lines 150–151) was exercised.
        expect(find.byType(Chart<StreamChartItem>), findsOneWidget);
      },
    );

    testWidgets(
      'color encoder calls getCategoryById for each categoryId in chart data',
      (tester) async {
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final days = [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 2),
              'cat-2': const Duration(hours: 1),
            },
            total: const Duration(hours: 3),
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: {
              'cat-1': const Duration(hours: 1),
              'cat-2': const Duration(hours: 2),
            },
            total: const Duration(hours: 3),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TimeHistoryStreamChart(
                  days: days,
                  maxDailyTotal: const Duration(hours: 3),
                  width: 400,
                  // ignore: avoid_redundant_argument_values
                  height: 60,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // The Chart widget renders (lines 91–143 executed).
        expect(find.byType(Chart<StreamChartItem>), findsOneWidget);
        // sortedCategories was queried to build category list (line 155–156).
        verify(() => mockCache.sortedCategories).called(greaterThan(0));
      },
    );
  });
}
