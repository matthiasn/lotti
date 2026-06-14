import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  const typeId = 'water-type-id';
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  MeasurableDataType makeDataType(AggregationType? aggregationType) =>
      MeasurableDataType(
        id: typeId,
        displayName: 'Water',
        description: 'Water intake',
        unitName: 'ml',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        version: 1,
        aggregationType: aggregationType,
      );

  List<Observation> makeObservations(List<double> values) => [
    for (var i = 0; i < values.length; i++)
      Observation(rangeStart.add(Duration(days: i)), values[i]),
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    required MeasurableDataType? dataType,
    AggregationType resolvedAggregation = AggregationType.dailySum,
    List<Observation> observations = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        MeasurablesBarChart(
          measurableDataTypeId: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        overrides: [
          measurableDataTypeControllerProvider(
            typeId,
          ).overrideWithBuild((ref, notifier) => dataType),
          aggregationTypeControllerProvider((
            measurableDataTypeId: typeId,
            dashboardDefinedAggregationType: null,
          )).overrideWithBuild((ref, notifier) => resolvedAggregation),
          measurableObservationsControllerProvider((
            measurableDataTypeId: typeId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            dashboardDefinedAggregationType: resolvedAggregation,
          )).overrideWithBuild((ref, notifier) => observations),
        ],
      ),
    );
    await tester.pump();
  }

  group('MeasurablesBarChart', () {
    testWidgets('renders nothing while the data type is unknown', (
      tester,
    ) async {
      await pumpChart(tester, dataType: null);

      expect(find.byType(DashboardChart), findsNothing);
      expect(find.byType(TimeSeriesBarChart), findsNothing);
      expect(find.byType(TimeSeriesLineChart), findsNothing);
    });

    testWidgets(
      'renders a bar chart with the header info for aggregated data',
      (tester) async {
        await pumpChart(
          tester,
          dataType: makeDataType(AggregationType.dailySum),
          observations: makeObservations([100, 250, 50]),
        );

        expect(find.byType(DashboardChart), findsOneWidget);
        expect(find.byType(TimeSeriesBarChart), findsOneWidget);
        expect(find.byType(TimeSeriesLineChart), findsNothing);

        // The header title is the bare display name; the subtitle is the
        // measurable's unit ("ml"), consistent with every other card — never a
        // "[agg] · [description]" stack or a developer enum suffix.
        expect(find.text('Water'), findsOneWidget);
        expect(find.text('ml'), findsOneWidget);
        expect(find.text('Water intake'), findsNothing);
        expect(find.textContaining('·'), findsNothing);
        expect(find.text('Water [dailySum]'), findsNothing);
      },
    );

    testWidgets(
      'renders a line chart when the aggregation resolves to none',
      (tester) async {
        await pumpChart(
          tester,
          dataType: makeDataType(AggregationType.none),
          resolvedAggregation: AggregationType.none,
          observations: makeObservations([100, 250]),
        );

        expect(find.byType(TimeSeriesLineChart), findsOneWidget);
        expect(find.byType(TimeSeriesBarChart), findsNothing);
      },
    );

    testWidgets('renders the bar chart with the dailyMax aggregation label', (
      tester,
    ) async {
      await pumpChart(
        tester,
        dataType: makeDataType(AggregationType.dailyMax),
        resolvedAggregation: AggregationType.dailyMax,
        observations: makeObservations([10, 20, 30]),
      );

      expect(find.byType(TimeSeriesBarChart), findsOneWidget);
      // Title is the bare name; the subtitle is the unit ("ml") — the
      // aggregation/description are not stacked in even when configured.
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('ml'), findsOneWidget);
      expect(find.text('Water intake'), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('shows the no-data message instead of a chart when empty', (
      tester,
    ) async {
      await pumpChart(
        tester,
        dataType: makeDataType(AggregationType.dailyMax),
        resolvedAggregation: AggregationType.dailyMax,
      );

      // Empty observations → the card renders the empty state, no chart.
      expect(find.byType(TimeSeriesBarChart), findsNothing);
      expect(find.byType(TimeSeriesLineChart), findsNothing);
      expect(find.text('No data in this range'), findsOneWidget);
      // The header still renders so the chart stays identifiable.
      expect(find.text('Water'), findsOneWidget);
    });
  });
}
