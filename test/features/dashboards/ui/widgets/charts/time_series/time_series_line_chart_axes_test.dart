import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

import 'time_series_line_chart_test_helpers.dart';

void main() {
  // Fixed range used across most tests (30 days).
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesLineChart — bottom title widgets', () {
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

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      // day=1 of any month must show a label regardless of range.
      final day1 = DateTime(2024, 3).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day1, makeMeta());

      // Must be a SideTitleWidget wrapping a ChartLabel, not SizedBox.shrink.
      expect(widget, isA<SideTitleWidget>());
    });

    testWidgets(
      'non-label day (e.g., day 7) in >=30-day range returns SizedBox',
      (tester) async {
        final start = DateTime(2024, 3);
        final end = DateTime(2024, 4, 30);
        await hPumpChart(
          tester,
          data: [],
          rangeStart: start,
          rangeEnd: end,
        );

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final getTitles =
            lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

        // day=7 is NOT 1, 8, 15, or 22 — should return SizedBox.shrink.
        final day7 = DateTime(2024, 3, 7).millisecondsSinceEpoch.toDouble();
        final widget = getTitles(day7, makeMeta());

        expect(widget, isA<SizedBox>());
      },
    );

    testWidgets('day=15 shows label when rangeInDays < 90', (tester) async {
      // Short range (< 90 days): day=15 should render a label.
      final shortStart = DateTime(2024, 3);
      final shortEnd = DateTime(2024, 4, 30); // ~60 days

      await hPumpChart(
        tester,
        data: [],
        rangeStart: shortStart,
        rangeEnd: shortEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetShort = getTitles(day15, makeMeta());
      expect(
        widgetShort,
        isA<SideTitleWidget>(),
        reason: 'day=15 should show in <90-day range',
      );
    });

    testWidgets('day=15 returns SizedBox in a >=90-day range', (tester) async {
      // Long range (>=90 days): day=15 should NOT render a label.
      final longStart = DateTime(2024);
      final longEnd = DateTime(2024, 5, 15); // ~135 days

      await hPumpChart(
        tester,
        data: [],
        rangeStart: longStart,
        rangeEnd: longEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetLong = getTitles(day15, makeMeta());
      expect(
        widgetLong,
        isA<SizedBox>(),
        reason: 'day=15 should NOT show in >=90-day range',
      );
    });

    testWidgets('day=8 shows label when rangeInDays < 30', (tester) async {
      // Short range (< 30 days): day=8 should show a label.
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await hPumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

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

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

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

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day22 = DateTime(2024, 3, 22).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day22, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=22 should show in <30-day range',
      );
    });
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
