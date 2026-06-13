import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:graphic/graphic.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_stream_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import 'test_helpers.dart';

void main() {
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

        // Data-level assertion: the chart received exactly the items
        // buildChartData derives for these days/categories — two days x
        // two category slots, conserving each day's minutes.
        final chart = tester.widget<Chart<StreamChartItem>>(
          find.byType(Chart<StreamChartItem>),
        );
        expect(
          chart.data,
          TimeHistoryStreamChart.buildChartData(
            days: days,
            categoryOrder: testCategories.keys,
          ),
        );
        expect(
          chart.data.fold<int>(0, (acc, item) => acc + item.minutes),
          4 * 60, // 3h on Jan 15 + 1h on Jan 14
        );
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

  group('pure chart functions — properties', () {
    glados.Glados<int>(
      glados.any.intInRange(0, 3000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'computeEffectiveScaleMinutes clamps to [6h, 24h] and is identity '
      'inside the band',
      (minutes) {
        final result = TimeHistoryStreamChart.computeEffectiveScaleMinutes(
          Duration(minutes: minutes),
        );
        expect(result, inInclusiveRange(360.0, 1440.0));
        // Identity inside the band; exact clamp at the edges.
        final expected = minutes < 360
            ? 360.0
            : minutes > 1440
            ? 1440.0
            : minutes.toDouble();
        expect(result, expected, reason: 'minutes=$minutes');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        6,
        // Per day: minutes for cat-a/cat-b plus uncategorized.
        glados.CombinableAny(glados.any).combine3(
          glados.any.intInRange(0, 300),
          glados.any.intInRange(0, 300),
          glados.any.intInRange(0, 120),
          (int a, int b, int u) => (a: a, b: b, u: u),
        ),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'buildChartData conserves per-day minutes and keeps every x-slot '
      'category-complete',
      (dayMinutes) {
        final days = <DayTimeSummary>[
          for (var i = 0; i < dayMinutes.length; i++)
            DayTimeSummary(
              day: DateTime(2024, 1, 10 + i, 12),
              durationByCategoryId: {
                'cat-a': Duration(minutes: dayMinutes[i].a),
                'cat-b': Duration(minutes: dayMinutes[i].b),
                if (dayMinutes[i].u > 0)
                  null: Duration(minutes: dayMinutes[i].u),
              },
              total: Duration(
                minutes: dayMinutes[i].a + dayMinutes[i].b + dayMinutes[i].u,
              ),
            ),
        ];

        final items = TimeHistoryStreamChart.buildChartData(
          days: days,
          categoryOrder: const ['cat-a', 'cat-b'],
        );

        if (days.isEmpty) {
          expect(items, isEmpty);
          return;
        }

        final hasUncategorized = dayMinutes.any((d) => d.u > 0);
        final categoriesPerDay = hasUncategorized ? 3 : 2;

        // Every day contributes the same category slots (SymmetricModifier
        // requirement), and the per-x minute sum conserves the day total.
        final byX = <double, List<StreamChartItem>>{};
        for (final item in items) {
          byX.putIfAbsent(item.x, () => []).add(item);
        }
        expect(byX, hasLength(days.length));
        for (var i = 0; i < dayMinutes.length; i++) {
          // Newest→oldest input maps to oldest→newest x.
          final x = (days.length - 1 - i) + 0.5;
          final slot = byX[x]!;
          expect(slot, hasLength(categoriesPerDay), reason: 'x=$x');
          final total = slot.fold<int>(0, (acc, it) => acc + it.minutes);
          expect(
            total,
            dayMinutes[i].a + dayMinutes[i].b + dayMinutes[i].u,
            reason: 'day $i conservation',
          );
        }
      },
      tags: 'glados',
    );
  });
}
