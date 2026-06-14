import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

  List<Observation> sysObs(List<double> values) => [
    for (var i = 0; i < values.length; i++)
      Observation(rangeStart.add(Duration(days: i)), values[i]),
  ];

  List<Observation> diaObs(List<double> values) => [
    for (var i = 0; i < values.length; i++)
      Observation(rangeStart.add(Duration(days: i + 1)), values[i]),
  ];

  group('BpChartInfoWidget', () {
    testWidgets('renders "Blood Pressure" label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 400,
            height: 400,
            child: BpChartInfoWidget(),
          ),
        ),
      );

      expect(find.text('Blood Pressure'), findsOneWidget);
    });
  });

  group('DashboardHealthBpChart', () {
    testWidgets('renders a LineChart with two data series', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild(
              (ref, notifier) => sysObs([120.0, 118.0, 122.0]),
            ),
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild(
              (ref, notifier) => diaObs([80.0, 78.0, 82.0]),
            ),
          ],
        ),
      );

      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(2));
    });

    testWidgets(
      'systolic uses the error token colour and diastolic the info token',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthBpChart(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
            overrides: [
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => sysObs([120.0])),
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ).overrideWithBuild((ref, notifier) => diaObs([80.0])),
            ],
          ),
        );

        await tester.pump();

        final tokens = tester.element(find.byType(LineChart)).designTokens;
        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final bars = lineChart.data.lineBarsData;

        // Systolic = alert.error, diastolic = alert.info, drawn as two clean
        // lines with no area fill below either series.
        expect(bars[0].color, tokens.colors.alert.error.defaultColor);
        expect(bars[1].color, tokens.colors.alert.info.defaultColor);
        expect(bars[0].belowBarData.show, isFalse);
        expect(bars[1].belowBarData.show, isFalse);
      },
    );

    testWidgets('footer legend labels Systolic and Diastolic series', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => sysObs([120.0])),
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => diaObs([80.0])),
          ],
        ),
      );

      await tester.pump();

      final tokens = tester.element(find.byType(LineChart)).designTokens;
      final legend = tester.widget<DashboardChartLegend>(
        find.byType(DashboardChartLegend),
      );
      expect(legend.entries, hasLength(2));
      expect(legend.entries[0].label, 'Systolic');
      expect(legend.entries[0].color, tokens.colors.alert.error.defaultColor);
      expect(legend.entries[1].label, 'Diastolic');
      expect(legend.entries[1].color, tokens.colors.alert.info.defaultColor);
    });

    testWidgets('systolic spots map observation values correctly', (
      tester,
    ) async {
      final systolicObservations = [
        Observation(DateTime(2024, 3, 5), 125),
        Observation(DateTime(2024, 3, 10), 130),
      ];

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => systolicObservations),
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final systolicBar = lineChart.data.lineBarsData.first;

      expect(systolicBar.spots, hasLength(2));
      expect(
        systolicBar.spots.first.x,
        DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(),
      );
      expect(systolicBar.spots.first.y, 125.0);
      expect(systolicBar.spots.last.y, 130.0);
    });

    testWidgets('diastolic spots map observation values correctly', (
      tester,
    ) async {
      final diastolicObservations = [
        Observation(DateTime(2024, 3, 5), 78),
        Observation(DateTime(2024, 3, 10), 82),
      ];

      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
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
            ).overrideWithBuild((ref, notifier) => diastolicObservations),
          ],
        ),
      );

      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final diastolicBar = lineChart.data.lineBarsData[1];

      expect(diastolicBar.spots, hasLength(2));
      expect(diastolicBar.spots.first.y, 78.0);
      expect(diastolicBar.spots.last.y, 82.0);
    });

    testWidgets('renders Blood Pressure header label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
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

      expect(find.text('Blood Pressure'), findsOneWidget);
    });

    testWidgets(
      'empty data shows the no-data message instead of the chart',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            DashboardHealthBpChart(
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

        // With both series empty the card renders the empty-state message and
        // no LineChart at all.
        expect(find.byType(LineChart), findsNothing);
        expect(find.text('No data in this range'), findsOneWidget);
      },
    );

    testWidgets('minX and maxX match rangeStart and rangeEnd', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => sysObs([120.0])),
            healthObservationsControllerProvider(
              healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ).overrideWithBuild((ref, notifier) => <Observation>[]),
          ],
        ),
      );

      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        lineChart.data.minX,
        rangeStart.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        lineChart.data.maxX,
        rangeEnd.millisecondsSinceEpoch.toDouble(),
      );
    });

    testWidgets('chart container has height 220', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHealthBpChart(
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

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 220),
        isTrue,
        reason: 'Expected a SizedBox with height 220 for the chart',
      );
    });
  });
}
