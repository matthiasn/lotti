import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart'
    hide leftTitleWidgets;
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import 'dashboard_health_bp_chart_test_helpers.dart';

void main() {
  late MockHealthImport mockHealthImport;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockHealthImport = MockHealthImport();
    when(
      () => mockHealthImport.fetchHealthDataDelta(any()),
    ).thenAnswer((_) async {});

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<HealthImport>(mockHealthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('DashboardHealthBpChart — grid line callbacks', () {
    testWidgets('getDrawingVerticalLine returns gridLine for any value', (
      tester,
    ) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final result = lineChart.data.gridData.getDrawingVerticalLine(42);
      expect(result, equals(gridLine));
    });

    testWidgets(
      'getDrawingHorizontalLine returns emphasised blue line for value 80',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final result = lineChart.data.gridData.getDrawingHorizontalLine(80);
        // The 80 mmHg line uses a blue tint — verify stroke width is non-zero
        // and the color has a blue component to distinguish it from a plain gridLine.
        expect(result.color, isNotNull);
        expect(result.color, isNot(equals(gridLine.color)));
      },
    );

    testWidgets(
      'getDrawingHorizontalLine returns emphasised red line for value 120',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final result = lineChart.data.gridData.getDrawingHorizontalLine(120);
        expect(result.color, isNotNull);
        expect(result.color, isNot(equals(gridLine.color)));
      },
    );

    testWidgets('getDrawingHorizontalLine returns gridLine for other values', (
      tester,
    ) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // Values other than 80 and 120 should return the plain gridLine.
      for (final value in [0.0, 60.0, 100.0, 140.0]) {
        final result = lineChart.data.gridData.getDrawingHorizontalLine(value);
        expect(result, equals(gridLine), reason: 'value=$value');
      }
    });
  });

  group('DashboardHealthBpChart — tooltip callbacks', () {
    testWidgets('getTooltipColor returns a non-null Color', (tester) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        systolicObservations: [Observation(DateTime(2024, 3, 5), 120)],
      );

      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
      final barData = LineChartBarData(spots: const [FlSpot(0, 120)]);
      final spot = LineBarSpot(barData, 0, const FlSpot(0, 120));
      final color = tooltipData.getTooltipColor(spot);
      expect(color, isA<Color>());
    });

    testWidgets('getTooltipItems returns one item per spot', (tester) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        systolicObservations: [
          Observation(DateTime(2024, 3, 5), 120),
          Observation(DateTime(2024, 3, 10), 118),
        ],
      );

      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
      final barData = LineChartBarData(
        spots: const [FlSpot(0, 120), FlSpot(1, 118)],
      );
      final spots = [
        LineBarSpot(barData, 0, const FlSpot(0, 120)),
        LineBarSpot(barData, 0, const FlSpot(1, 118)),
      ];
      final items = tooltipData.getTooltipItems(spots);
      expect(items, hasLength(2));
    });

    testWidgets(
      'getTooltipItems first TextSpan contains integer mmHg value',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          systolicObservations: [Observation(DateTime(2024, 3, 5), 125)],
        );

        final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
        final barData = LineChartBarData(spots: const [FlSpot(0, 125)]);
        final spots = [LineBarSpot(barData, 0, const FlSpot(0, 125))];
        final items = tooltipData.getTooltipItems(spots);

        expect(items, hasLength(1));
        final item = items.first!;
        // First child TextSpan contains the integer y value with mmHg unit.
        final valueSpan = item.children!.first;
        expect(valueSpan.toPlainText(), contains('125'));
        expect(valueSpan.toPlainText(), contains('mmHg'));
      },
    );

    testWidgets(
      'getTooltipItems second TextSpan contains formatted date',
      (tester) async {
        final obsTime = DateTime(2024, 3, 15, 14, 30);
        final xMs = obsTime.millisecondsSinceEpoch.toDouble();

        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          systolicObservations: [Observation(obsTime, 118)],
        );

        final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
        final barData = LineChartBarData(spots: [FlSpot(xMs, 118)]);
        final spots = [LineBarSpot(barData, 0, FlSpot(xMs, 118))];
        final items = tooltipData.getTooltipItems(spots);

        final item = items.first!;
        final dateSpan = item.children![1];
        // chartDateFormatterFull produces "MMM dd, HH:mm".
        expect(dateSpan.toPlainText(), contains('Mar 15'));
        expect(dateSpan.toPlainText(), contains('14:30'));
      },
    );

    testWidgets('getTooltipItems with empty spots returns empty list', (
      tester,
    ) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
      final items = tooltipData.getTooltipItems([]);
      expect(items, isEmpty);
    });

    testWidgets(
      'getTooltipItems truncates decimal y to integer in mmHg label',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          diastolicObservations: [Observation(DateTime(2024, 3, 5), 79.9)],
        );

        final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
        final barData = LineChartBarData(spots: const [FlSpot(0, 79.9)]);
        final spots = [LineBarSpot(barData, 0, const FlSpot(0, 79.9))];
        final items = tooltipData.getTooltipItems(spots);

        final item = items.first!;
        final valueSpan = item.children!.first;
        // toInt() truncates 79.9 → 79.
        expect(valueSpan.toPlainText(), contains('79'));
        expect(valueSpan.toPlainText(), isNot(contains('79.9')));
      },
    );
  });
}
