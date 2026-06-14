import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

import 'time_series_line_chart_test_helpers.dart';

void main() {
  // Fixed range used across most tests (30 days).
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesLineChart — value axis configuration', () {
    testWidgets('bottom titles are disabled (shared date axis renders them)', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        lineChart.data.titlesData.bottomTitles.sideTitles.showTitles,
        isFalse,
      );
    });

    testWidgets(
      'left titles use the shared gutter width and label the top bound only',
      (tester) async {
        await hPumpChart(
          tester,
          data: [Observation(DateTime(2024, 3, 10), 5)],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final leftTitles = lineChart.data.titlesData.leftTitles.sideTitles;
        expect(leftTitles.reservedSize, kChartLeftAxisWidth);
        // The min tick is suppressed (it overlaps the bottom axis), but the top
        // nice-number bound is labelled so the value scale's ceiling is read.
        expect(leftTitles.minIncluded, isFalse);
        expect(leftTitles.maxIncluded, isTrue);
      },
    );
  });

  group('TimeSeriesLineChart — bar data configuration', () {
    testWidgets('lineBarsData contains exactly one series', (tester) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(1));
    });

    testWidgets('dot data is hidden (show: false)', (tester) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      expect(bar.dotData.show, isFalse);
    });

    testWidgets('belowBarData is visible (show: true)', (tester) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      expect(bar.belowBarData.show, isTrue);
    });

    testWidgets('line uses the solid interactive-enabled token colour', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final tokens = tester.element(find.byType(LineChart)).designTokens;
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      // No gradient any more — a single solid stroke colour.
      expect(bar.gradient, isNull);
      expect(bar.color, tokens.colors.interactive.enabled);
    });

    testWidgets('belowBarData is a translucent interactive-enabled fill', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final tokens = tester.element(find.byType(LineChart)).designTokens;
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      // The fill is a solid colour (not a gradient) at 0.12 alpha.
      expect(bar.belowBarData.gradient, isNull);
      expect(
        bar.belowBarData.color,
        tokens.colors.interactive.enabled.withValues(alpha: 0.12),
      );
    });
  });
}
