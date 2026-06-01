import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesBarChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> _pumpChart(
  WidgetTester tester, {
  required List<Observation> data,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  String unit = '',
  bool valueInHours = false,
  ColorByValue? colorByValue,
  Size physicalSize = const Size(800, 600),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SizedBox(
          width: physicalSize.width,
          height: physicalSize.height,
          child: TimeSeriesBarChart(
            data: data,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            unit: unit,
            valueInHours: valueInHours,
            colorByValue: colorByValue ?? (_) => Colors.blue,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Returns a minimal [TitleMeta] for testing bottom title widget callbacks.
TitleMeta makeMeta() {
  return TitleMeta(
    min: 0,
    max: 100,
    appliedInterval: 1,
    axisPosition: 0,
    formattedValue: '',
    parentAxisSize: 400,
    sideTitles: const SideTitles(showTitles: true),
    axisSide: AxisSide.bottom,
    rotationQuarterTurns: 0,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesBarChart — widget structure', () {
    testWidgets('renders a BarChart widget', (tester) async {
      await _pumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 5),
          Observation(DateTime(2024, 3, 20), 10),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('wraps chart in a Padding widget', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(Padding), findsWidgets);
    });
  });

  group('TimeSeriesBarChart — bar group mapping', () {
    testWidgets('maps each observation to a BarChartGroupData with correct x', (
      tester,
    ) async {
      final obs1 = Observation(DateTime(2024, 3, 5), 42);
      final obs2 = Observation(DateTime(2024, 3, 15), 88);

      await _pumpChart(
        tester,
        data: [obs1, obs2],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final groups = barChart.data.barGroups;

      // The range fills in empty days; obs1 and obs2 must appear in the groups.
      final xs = groups.map((g) => g.x).toSet();
      expect(
        xs,
        contains(obs1.dateTime.millisecondsSinceEpoch),
        reason: 'obs1 x must be present',
      );
      expect(
        xs,
        contains(obs2.dateTime.millisecondsSinceEpoch),
        reason: 'obs2 x must be present',
      );
    });

    testWidgets('each bar group has exactly one rod', (tester) async {
      await _pumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 7),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      for (final group in barChart.data.barGroups) {
        expect(
          group.barRods,
          hasLength(1),
          reason: 'every group must have exactly one rod',
        );
      }
    });

    testWidgets('bar rod toY matches the observation value', (tester) async {
      final obs = Observation(DateTime(2024, 3, 10), 99);
      await _pumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      expect(group.barRods.first.toY, 99.0);
    });

    testWidgets('colorByValue callback is applied to each rod', (tester) async {
      const redColor = Colors.red;
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        colorByValue: (_) => redColor,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final targetX = DateTime(2024, 3, 10).millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      expect(group.barRods.first.color, redColor);
    });

    testWidgets('empty data yields bar groups only for in-range empty days', (
      tester,
    ) async {
      // A 30-day range with no real observations still generates a group for
      // every day in range (filled with value=0).
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      // 31 days in [Mar 1, Mar 31] inclusive.
      expect(barChart.data.barGroups, hasLength(31));
    });

    testWidgets('empty-day placeholder has rod value 0', (tester) async {
      // With no real data every rod should have toY == 0.
      await _pumpChart(
        tester,
        data: [],
        rangeStart: DateTime(2024, 3),
        rangeEnd: DateTime(2024, 3, 5),
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      for (final group in barChart.data.barGroups) {
        expect(
          group.barRods.first.toY,
          0.0,
          reason: 'placeholder bar rod must be 0',
        );
      }
    });
  });

  group('TimeSeriesBarChart — grid interval by range length', () {
    for (final testCase in [
      (
        label: '>182 days → gridInterval=30',
        start: DateTime(2024),
        end: DateTime(2024, 8), // ~213 days
        expectedFactor: 30,
      ),
      (
        label: '93–182 days → gridInterval=14',
        start: DateTime(2024),
        end: DateTime(2024, 4, 15), // ~105 days
        expectedFactor: 14,
      ),
      (
        label: '31–92 days → gridInterval=7',
        start: DateTime(2024),
        end: DateTime(2024, 3), // ~60 days
        expectedFactor: 7,
      ),
      (
        label: '<=30 days → gridInterval=1',
        start: DateTime(2024, 3),
        end: DateTime(2024, 3, 15), // 14 days
        expectedFactor: 1,
      ),
    ]) {
      testWidgets(testCase.label, (tester) async {
        await _pumpChart(
          tester,
          data: [],
          rangeStart: testCase.start,
          rangeEnd: testCase.end,
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final expectedInterval =
            Duration.millisecondsPerDay.toDouble() * testCase.expectedFactor;
        expect(
          barChart.data.gridData.verticalInterval,
          expectedInterval,
          reason: testCase.label,
        );
      });
    }
  });

  group('TimeSeriesBarChart — grid line callbacks', () {
    testWidgets('getDrawingHorizontalLine returns gridLine', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final result = barChart.data.gridData.getDrawingHorizontalLine(0);
      expect(result, equals(gridLine));
    });

    testWidgets('getDrawingVerticalLine returns gridLine', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final result = barChart.data.gridData.getDrawingVerticalLine(0);
      expect(result, equals(gridLine));
    });
  });

  group('TimeSeriesBarChart — tooltip callbacks', () {
    testWidgets('getTooltipColor returns a Color', (tester) async {
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      // Pass a BarChartGroupData to satisfy the callback signature.
      final group = barChart.data.barGroups.first;
      final color = tooltipData.getTooltipColor(group);
      expect(color, isA<Color>());
    });

    testWidgets('getTooltipItem formats numeric value with unit', (
      tester,
    ) async {
      final obs = Observation(DateTime(2024, 3, 10), 1234.5);
      await _pumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: 'kg',
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      final rod = group.barRods.first;

      final item = tooltipData.getTooltipItem(group, 0, rod, 0);

      expect(item, isNotNull);
      expect(item!.text, contains('1,234.5'));
      expect(item.text, contains('kg'));
    });

    testWidgets('getTooltipItem includes formatted date', (tester) async {
      final obs = Observation(DateTime(2024, 3, 15), 42);
      await _pumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      final rod = group.barRods.first;

      final item = tooltipData.getTooltipItem(group, 0, rod, 0);

      expect(item, isNotNull);
      // chartDateFormatterYMD uses DateFormat.yMMMd() → e.g. "Mar 15, 2024"
      expect(item!.text, contains('Mar'));
      expect(item.text, contains('15'));
    });

    testWidgets(
      'getTooltipItem formats hours as HH:MM when valueInHours is true',
      (
        tester,
      ) async {
        // 1.5 hours → "01:30"
        final obs = Observation(DateTime(2024, 3, 10), 1.5);
        await _pumpChart(
          tester,
          data: [obs],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          valueInHours: true,
          unit: 'h',
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final tooltipData = barChart.data.barTouchData.touchTooltipData;

        final targetX = obs.dateTime.millisecondsSinceEpoch;
        final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
        final rod = group.barRods.first;

        final item = tooltipData.getTooltipItem(group, 0, rod, 0);

        expect(item, isNotNull);
        // hoursToHhMm(1.5) == "01:30"
        expect(item!.text, contains('01:30'));
      },
    );
  });

  group('TimeSeriesBarChart — bottom title widgets', () {
    testWidgets('day=1 renders a SideTitleWidget with a date label', (
      tester,
    ) async {
      // Use a range ≥30 days so that only day=1 triggers the label.
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 30);
      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day1 = DateTime(2024, 3).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day1, makeMeta());

      expect(widget, isA<SideTitleWidget>());
    });

    testWidgets(
      'non-label day (e.g., day 7) in >=30-day range returns SizedBox',
      (
        tester,
      ) async {
        final start = DateTime(2024, 3);
        final end = DateTime(2024, 4, 30);
        await _pumpChart(
          tester,
          data: [],
          rangeStart: start,
          rangeEnd: end,
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final getTitles =
            barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

        // day=7 is NOT 1, 8, 15, or 22 — should return SizedBox.shrink.
        final day7 = DateTime(2024, 3, 7).millisecondsSinceEpoch.toDouble();
        final widget = getTitles(day7, makeMeta());

        expect(widget, isA<SizedBox>());
      },
    );

    testWidgets('day=15 shows label when rangeInDays < 92', (tester) async {
      // Short range (< 92 days): day=15 should render a label.
      final shortStart = DateTime(2024, 3);
      final shortEnd = DateTime(2024, 4, 30); // ~60 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: shortStart,
        rangeEnd: shortEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetShort = getTitles(day15, makeMeta());
      expect(
        widgetShort,
        isA<SideTitleWidget>(),
        reason: 'day=15 should show in <92-day range',
      );
    });

    testWidgets('day=15 returns SizedBox in a >=92-day range', (tester) async {
      // Long range (>=92 days): day=15 should NOT render a label.
      final longStart = DateTime(2024);
      final longEnd = DateTime(2024, 5, 15); // ~135 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: longStart,
        rangeEnd: longEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetLong = getTitles(day15, makeMeta());
      expect(
        widgetLong,
        isA<SizedBox>(),
        reason: 'day=15 should NOT show in >=92-day range',
      );
    });

    testWidgets('day=8 shows label when rangeInDays < 30', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day8 = DateTime(2024, 3, 8).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day8, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=8 should show in <30-day range',
      );
    });

    testWidgets('day=8 returns SizedBox when rangeInDays >= 30', (
      tester,
    ) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 15); // 45 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day8 = DateTime(2024, 3, 8).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day8, makeMeta());
      expect(
        widget,
        isA<SizedBox>(),
        reason: 'day=8 should NOT show in >=30-day range',
      );
    });

    testWidgets('day=22 shows label when rangeInDays < 30', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day22 = DateTime(2024, 3, 22).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day22, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=22 should show in <30-day range',
      );
    });

    testWidgets('day=22 returns SizedBox when rangeInDays >= 30', (
      tester,
    ) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 15); // 45 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final getTitles =
          barChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day22 = DateTime(2024, 3, 22).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day22, makeMeta());
      expect(
        widget,
        isA<SizedBox>(),
        reason: 'day=22 should NOT show in >=30-day range',
      );
    });
  });

  group('TimeSeriesBarChart — bar data configuration', () {
    testWidgets('border data is shown', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.borderData.show, isTrue);
    });

    testWidgets('right and top titles are not shown', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final titlesData = barChart.data.titlesData;
      expect(
        titlesData.rightTitles.sideTitles.showTitles,
        isFalse,
        reason: 'right titles should be hidden',
      );
      expect(
        titlesData.topTitles.sideTitles.showTitles,
        isFalse,
        reason: 'top titles should be hidden',
      );
    });

    testWidgets('left titles are shown with reservedSize 40', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final leftTitles = barChart.data.titlesData.leftTitles.sideTitles;
      expect(leftTitles.showTitles, isTrue);
      expect(leftTitles.reservedSize, 40);
    });

    testWidgets('bottom titles are shown with reservedSize 30', (tester) async {
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final bottomTitles = barChart.data.titlesData.bottomTitles.sideTitles;
      expect(bottomTitles.showTitles, isTrue);
      expect(bottomTitles.reservedSize, 30);
    });

    testWidgets(
      'grid data is not shown but has valid horizontal/vertical intervals',
      (tester) async {
        await _pumpChart(
          tester,
          data: [],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final gridData = barChart.data.gridData;
        expect(gridData.show, isFalse);
        expect(
          gridData.horizontalInterval,
          double.maxFinite,
          reason: 'horizontal interval should be maxFinite',
        );
        expect(
          gridData.verticalInterval,
          isNotNull,
          reason: 'vertical interval should be set',
        );
      },
    );
  });
}
