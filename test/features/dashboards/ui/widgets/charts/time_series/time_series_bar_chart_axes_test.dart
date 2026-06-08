import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'time_series_bar_chart_test_helpers.dart';

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesBarChart — bottom title widgets', () {
    testWidgets('day=1 renders a SideTitleWidget with a date label', (
      tester,
    ) async {
      // Use a range ≥30 days so that only day=1 triggers the label.
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 30);
      await hPumpChart(
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
        await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.borderData.show, isTrue);
    });

    testWidgets('right and top titles are not shown', (tester) async {
      await hPumpChart(
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
      await hPumpChart(
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
      await hPumpChart(
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
        await hPumpChart(
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
