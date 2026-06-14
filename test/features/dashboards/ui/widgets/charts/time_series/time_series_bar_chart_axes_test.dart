import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

import 'time_series_bar_chart_test_helpers.dart';

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

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

    testWidgets('right, top and bottom titles are not shown', (tester) async {
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
      // The bottom date axis is rendered by the shared DashboardChartDateAxis
      // widget, not by fl_chart, so the chart's own bottom titles are disabled.
      expect(
        titlesData.bottomTitles.sideTitles.showTitles,
        isFalse,
        reason:
            'bottom titles should be hidden (shared date axis renders them)',
      );
    });

    testWidgets('left titles are shown with the shared gutter width', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final leftTitles = barChart.data.titlesData.leftTitles.sideTitles;
      expect(leftTitles.showTitles, isTrue);
      expect(leftTitles.reservedSize, kChartLeftAxisWidth);
      // The min tick is suppressed (it overlaps the bottom axis), but the top
      // nice-number bound is labelled so the value scale's ceiling is readable.
      expect(leftTitles.minIncluded, isFalse);
      expect(leftTitles.maxIncluded, isTrue);
    });

    testWidgets(
      'grid data draws only horizontal lines with a finite nice interval',
      (tester) async {
        await hPumpChart(
          tester,
          data: [Observation(DateTime(2024, 3, 10), 10)],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final gridData = barChart.data.gridData;
        // Gridlines are drawn (default show == true), horizontally only.
        expect(gridData.show, isTrue);
        expect(gridData.drawVerticalLine, isFalse);
        // The horizontal interval is the nice-axis tick interval, a finite
        // rounded number — never double.maxFinite.
        expect(gridData.horizontalInterval, isNot(double.maxFinite));
        expect(gridData.horizontalInterval, greaterThan(0));
        expect(
          gridData.horizontalInterval,
          niceAxis(0, 10, zeroBased: true).interval,
        );
      },
    );

    testWidgets('value axis is zero-based with a nice maxY', (tester) async {
      // maxData = 10 → niceAxis(0, 10, zeroBased: true) → min 0, max 10.
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 10)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final axis = niceAxis(0, 10, zeroBased: true);
      expect(barChart.data.minY, 0);
      expect(barChart.data.maxY, axis.max);
      // The bar (toY 10) fits inside the nice axis.
      expect(barChart.data.maxY, greaterThanOrEqualTo(10));
    });
  });
}
