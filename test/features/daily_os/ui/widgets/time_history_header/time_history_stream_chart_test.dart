import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_stream_chart.dart';

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
      final uncategorizedItems =
          result.where((item) => item.categoryId == '__uncategorized__');
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
}
