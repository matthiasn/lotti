import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
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
    // Tests use the light theme, so the tokens are dsTokensLight.
    const tokens = dsTokensLight;
    final systolicColor = tokens.colors.alert.error.defaultColor;
    final diastolicColor = tokens.colors.alert.info.defaultColor;
    final plainGridColor = tokens.colors.decorative.level01;

    testWidgets('vertical gridlines are disabled', (tester) async {
      final lineChart = await hPumpBpChart(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(lineChart.data.gridData.drawVerticalLine, isFalse);
    });

    testWidgets(
      'horizontal line at 80 is the dashed diastolic reference line',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final result = lineChart.data.gridData.getDrawingHorizontalLine(80);
        // 80 mmHg → dashed emphasis line tinted by the diastolic (info) token.
        expect(result.color, diastolicColor.withValues(alpha: 0.5));
        expect(result.dashArray, [5, 3]);
      },
    );

    testWidgets(
      'horizontal line at 120 is the dashed systolic reference line',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final result = lineChart.data.gridData.getDrawingHorizontalLine(120);
        // 120 mmHg → dashed emphasis line tinted by the systolic (error) token.
        expect(result.color, systolicColor.withValues(alpha: 0.5));
        expect(result.dashArray, [5, 3]);
      },
    );

    testWidgets(
      'horizontal lines other than 80/120 use the plain tokenized gridline',
      (tester) async {
        final lineChart = await hPumpBpChart(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        for (final value in [0.0, 60.0, 100.0, 140.0]) {
          final result = lineChart.data.gridData.getDrawingHorizontalLine(
            value,
          );
          expect(result.color, plainGridColor, reason: 'value=$value');
          expect(result.strokeWidth, 1, reason: 'value=$value');
          // Plain gridlines are solid, not dashed.
          expect(result.dashArray, isNull, reason: 'value=$value');
        }
      },
    );
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
