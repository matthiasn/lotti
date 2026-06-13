import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
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

  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  List<Observation> makeObservations(List<double> values) => [
    for (var i = 0; i < values.length; i++)
      Observation(rangeStart.add(Duration(days: i)), values[i]),
  ];

  // ------------------------------------------------------------------ //
  // HealthChartInfoWidget
  // ------------------------------------------------------------------ //

  group('HealthChartInfoWidget', () {
    testWidgets('shows display name for a known health type', (tester) async {
      // 'HealthDataType.RESTING_HEART_RATE' → 'Resting Heart Rate'
      const config =
          DashboardItem.healthChart(
                color: '#FF0000',
                healthType: 'HealthDataType.RESTING_HEART_RATE',
              )
              as DashboardHealthItem;

      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [HealthChartInfoWidget(config)],
            ),
          ),
        ),
      );

      expect(find.text('Resting Heart Rate'), findsOneWidget);
      // The unit is surfaced as the header subtitle.
      expect(find.text('bpm'), findsOneWidget);
    });

    testWidgets('falls back to raw healthType string when type is unknown', (
      tester,
    ) async {
      const config =
          DashboardItem.healthChart(
                color: '#00FF00',
                healthType: 'SomeUnknownType',
              )
              as DashboardHealthItem;

      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [HealthChartInfoWidget(config)],
            ),
          ),
        ),
      );

      expect(find.text('SomeUnknownType'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ //
  // DashboardHealthChart — BLOOD_PRESSURE delegates to BpChart
  // ------------------------------------------------------------------ //

  group('DashboardHealthChart — BLOOD_PRESSURE branch', () {
    const bpConfig =
        DashboardItem.healthChart(
              color: '#FF0000',
              healthType: 'BLOOD_PRESSURE',
            )
            as DashboardHealthItem;

    testWidgets('renders DashboardHealthBpChart for BLOOD_PRESSURE', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: bpConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(DashboardHealthBpChart), findsOneWidget);
      // Should NOT show BMI or generic charts.
      expect(find.byType(DashboardHealthBmiChart), findsNothing);
      expect(find.byType(TimeSeriesLineChart), findsNothing);
      expect(find.byType(TimeSeriesBarChart), findsNothing);
    });
  });

  // ------------------------------------------------------------------ //
  // DashboardHealthChart — BODY_MASS_INDEX delegates to BmiChart
  // ------------------------------------------------------------------ //

  group('DashboardHealthChart — BODY_MASS_INDEX branch', () {
    const bmiConfig =
        DashboardItem.healthChart(
              color: '#0000FF',
              healthType: 'BODY_MASS_INDEX',
            )
            as DashboardHealthItem;

    testWidgets('renders DashboardHealthBmiChart for BODY_MASS_INDEX', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: bmiConfig,
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
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );

      await tester.pump();

      expect(find.byType(DashboardHealthBmiChart), findsOneWidget);
      expect(find.byType(DashboardHealthBpChart), findsNothing);
      expect(find.byType(TimeSeriesBarChart), findsNothing);
    });
  });

  // ------------------------------------------------------------------ //
  // DashboardHealthChart — line chart branch (e.g. resting heart rate)
  // ------------------------------------------------------------------ //

  group('DashboardHealthChart — line chart branch', () {
    const hrConfig =
        DashboardItem.healthChart(
              color: '#FF0000',
              healthType: 'HealthDataType.RESTING_HEART_RATE',
            )
            as DashboardHealthItem;

    testWidgets('renders TimeSeriesLineChart with observation data', (
      tester,
    ) async {
      final observations = makeObservations([60.0, 62.0, 58.0]);

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: hrConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.RESTING_HEART_RATE',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(TimeSeriesLineChart), findsOneWidget);
      expect(find.byType(TimeSeriesBarChart), findsNothing);
      expect(find.byType(DashboardHealthBpChart), findsNothing);
      expect(find.byType(DashboardHealthBmiChart), findsNothing);

      // The observations must flow through to the embedded LineChart.
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        lineChart.data.lineBarsData.first.spots.map((s) => s.y),
        [60.0, 62.0, 58.0],
      );
    });

    testWidgets('shows the health type display name in the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: hrConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.RESTING_HEART_RATE',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Resting Heart Rate'), findsOneWidget);
    });

    testWidgets(
      'shows the no-data message instead of a line chart when empty',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthChart(
              chartConfig: hrConfig,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.RESTING_HEART_RATE',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => <Observation>[]),
            ],
          ),
        );

        await tester.pump();

        // Empty observations → the card renders the empty state, no chart.
        expect(find.byType(TimeSeriesLineChart), findsNothing);
        expect(find.byType(LineChart), findsNothing);
        expect(find.text('No data in this range'), findsOneWidget);
        // The header still renders so the chart stays identifiable.
        expect(find.text('Resting Heart Rate'), findsOneWidget);
      },
    );

    testWidgets('DashboardChart has height 150 for a line-chart health type', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: hrConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.RESTING_HEART_RATE',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 150),
        isTrue,
        reason: 'Expected a SizedBox with height 150 for a line-chart type',
      );
    });

    testWidgets('spots map observation values correctly for line chart', (
      tester,
    ) async {
      final observations = [
        Observation(DateTime(2024, 3, 5), 65),
        Observation(DateTime(2024, 3, 10), 70),
      ];

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: hrConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.RESTING_HEART_RATE',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = lineChart.data.lineBarsData.first.spots;

      expect(spots, hasLength(2));
      expect(
        spots.first.x,
        DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(),
      );
      expect(spots.first.y, 65.0);
      expect(spots.last.y, 70.0);
    });
  });

  // ------------------------------------------------------------------ //
  // DashboardHealthChart — bar chart branch (e.g. steps)
  // ------------------------------------------------------------------ //

  group('DashboardHealthChart — bar chart branch', () {
    const stepsConfig =
        DashboardItem.healthChart(
              color: '#00FF00',
              healthType: 'cumulative_step_count',
            )
            as DashboardHealthItem;

    testWidgets('renders TimeSeriesBarChart for a bar-chart health type', (
      tester,
    ) async {
      final observations = makeObservations([8000.0, 12000.0, 6500.0]);

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: stepsConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'cumulative_step_count',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(TimeSeriesBarChart), findsOneWidget);
      expect(find.byType(TimeSeriesLineChart), findsNothing);

      // The observations and step-count unit must be forwarded verbatim.
      final barChart = tester.widget<TimeSeriesBarChart>(
        find.byType(TimeSeriesBarChart),
      );
      expect(barChart.data.map((o) => o.value), [8000.0, 12000.0, 6500.0]);
      expect(barChart.valueInHours, isFalse);
    });

    testWidgets(
      'shows display name "Steps" in header for cumulative_step_count',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthChart(
              chartConfig: stepsConfig,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              healthObservationsControllerProvider(
                healthDataType: 'cumulative_step_count',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => <Observation>[]),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Steps'), findsOneWidget);
      },
    );

    testWidgets('DashboardChart has height 180 for a bar-chart health type', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: stepsConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'cumulative_step_count',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 180),
        isTrue,
        reason: 'Expected a SizedBox with height 180 for a bar-chart type',
      );
    });

    testWidgets(
      'shows the no-data message instead of a bar chart when empty',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthChart(
              chartConfig: stepsConfig,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              healthObservationsControllerProvider(
                healthDataType: 'cumulative_step_count',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => <Observation>[]),
            ],
          ),
        );

        await tester.pump();

        // Empty observations → the card renders the empty state, no chart.
        expect(find.byType(TimeSeriesBarChart), findsNothing);
        expect(find.byType(BarChart), findsNothing);
        expect(find.text('No data in this range'), findsOneWidget);
      },
    );
  });

  // ------------------------------------------------------------------ //
  // DashboardHealthChart — sleep bar chart (unit 'h' → valueInHours=true)
  // ------------------------------------------------------------------ //

  group('DashboardHealthChart — sleep bar chart (valueInHours)', () {
    const sleepConfig =
        DashboardItem.healthChart(
              color: '#8800FF',
              healthType: 'HealthDataType.SLEEP_ASLEEP',
            )
            as DashboardHealthItem;

    testWidgets('renders TimeSeriesBarChart for SLEEP_ASLEEP', (tester) async {
      final observations = makeObservations([420.0, 480.0]);

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: sleepConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.SLEEP_ASLEEP',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => observations),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(TimeSeriesBarChart), findsOneWidget);
      expect(find.byType(TimeSeriesLineChart), findsNothing);

      // SLEEP_ASLEEP is an hour-unit type: the chart must receive the data
      // with the valueInHours flag set so labels render as hours.
      final barChart = tester.widget<TimeSeriesBarChart>(
        find.byType(TimeSeriesBarChart),
      );
      expect(barChart.data.map((o) => o.value), [420.0, 480.0]);
      expect(barChart.valueInHours, isTrue);
    });

    testWidgets('shows "Asleep" display name in header', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthChart(
            chartConfig: sleepConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.SLEEP_ASLEEP',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Asleep'), findsOneWidget);
    });
  });
}
