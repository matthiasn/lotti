import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/health_bmi_data.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

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

  const chartConfig =
      DashboardItem.healthChart(
            color: '#FF0000',
            healthType: 'HealthDataType.WEIGHT',
          )
          as DashboardHealthItem;

  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  List<Observation> makeObservations(List<double> values) {
    return [
      for (var i = 0; i < values.length; i++)
        Observation(rangeStart.add(Duration(days: i)), values[i]),
    ];
  }

  group('BmiRangeLegend', () {
    // BmiRangeLegend returns a Positioned, so it must live inside a Stack.
    testWidgets('renders all BMI category labels from bmiRanges', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(children: [BmiRangeLegend()]),
          ),
        ),
      );

      for (final range in bmiRanges) {
        expect(
          find.text(range.name),
          findsOneWidget,
          reason: 'Expected BMI range "${range.name}" to be displayed',
        );
      }
    });

    testWidgets('renders colour swatch for every BMI range', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(children: [BmiRangeLegend()]),
          ),
        ),
      );

      // Each range row contains one ColoredBox (the colour swatch).
      expect(
        find.descendant(
          of: find.byType(BmiRangeLegend),
          matching: find.byType(ColoredBox),
        ),
        findsNWidgets(bmiRanges.length),
      );
    });
  });

  group('BmiChartInfoWidget', () {
    testWidgets('shows health type display name when configured', (
      tester,
    ) async {
      // 'HealthDataType.WEIGHT' maps to displayName 'Weight' in healthTypes.
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [
                BmiChartInfoWidget(
                  chartConfig,
                  minInRange: 70,
                  maxInRange: 80,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Weight'), findsOneWidget);
    });

    testWidgets('falls back to raw health type when not in healthTypes', (
      tester,
    ) async {
      const unknownConfig =
          DashboardItem.healthChart(
                color: '#00FF00',
                healthType: 'UnknownType',
              )
              as DashboardHealthItem;

      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [
                BmiChartInfoWidget(
                  unknownConfig,
                  minInRange: 60,
                  maxInRange: 90,
                ),
              ],
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );

      expect(find.text('UnknownType'), findsOneWidget);
    });

    testWidgets('formats min/max range with kg suffix', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [
                BmiChartInfoWidget(
                  chartConfig,
                  minInRange: 68.3,
                  maxInRange: 82.7,
                ),
              ],
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );

      // NumberFormat('#,###.#') keeps one decimal place.
      expect(find.text('68.3 kg – 82.7 kg'), findsOneWidget);
    });

    testWidgets('shows zero values formatted correctly when data is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [
                BmiChartInfoWidget(
                  chartConfig,
                  minInRange: 0,
                  maxInRange: 0,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('0 kg – 0 kg'), findsOneWidget);
    });

    testWidgets('range text uses an emphasised (semibold) font weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [
                BmiChartInfoWidget(
                  chartConfig,
                  minInRange: 75,
                  maxInRange: 85,
                ),
              ],
            ),
          ),
        ),
      );

      final rangeText = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('kg') &&
              w.style?.fontWeight == FontWeight.w600,
        ),
      );
      expect(rangeText.data, '75 kg – 85 kg');
    });
  });

  group('DashboardHealthBmiChart', () {
    testWidgets('renders TimeSeriesLineChart and BmiRangeLegend with data', (
      tester,
    ) async {
      final observations = makeObservations([72.0, 73.5, 74.0]);

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBmiChart(
            chartConfig: chartConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.WEIGHT',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(TimeSeriesLineChart), findsOneWidget);
      expect(find.byType(BmiRangeLegend), findsOneWidget);
    });

    testWidgets('shows weight display name in header', (tester) async {
      final observations = makeObservations([72.0]);

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBmiChart(
            chartConfig: chartConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.WEIGHT',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      // BmiChartInfoWidget shows the resolved display name.
      expect(find.text('Weight'), findsOneWidget);
    });

    testWidgets(
      'shows min/max weight range derived from provider data in header',
      (tester) async {
        final observations = makeObservations([68.0, 74.5, 80.2]);

        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthBmiChart(
              chartConfig: chartConfig,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.WEIGHT',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => observations),
            ],
          ),
        );

        await tester.pump();

        // findMin=68.0 → "68 kg", findMax=80.2 → "80.2 kg"
        expect(find.text('68 kg – 80.2 kg'), findsOneWidget);
      },
    );

    testWidgets('shows 0 kg - 0 kg range when provider returns empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBmiChart(
            chartConfig: chartConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.WEIGHT',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      // findMin and findMax return 0 when list is empty.
      expect(find.text('0 kg – 0 kg'), findsOneWidget);
    });

    testWidgets('DashboardChart has height 320', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBmiChart(
            chartConfig: chartConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.WEIGHT',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 320),
        isTrue,
        reason: 'Expected a SizedBox with height 320 inside DashboardChart',
      );
    });
  });
}
