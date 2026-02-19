import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('DashboardHealthChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    testWidgets('renders weight chart with title and line chart',
        (tester) async {
      when(
        () => mockJournalDb.getQuantitativeByType(
          type: testWeightEntry.data.dataType,
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testWeightEntry]);

      when(
        () => mockHealthImport
            .fetchHealthDataDelta(testWeightEntry.data.dataType),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHealthChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: const DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.WEIGHT',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Weight'), findsOneWidget);
      expect(find.byType(TimeSeriesLineChart), findsOneWidget);
      expect(find.byType(HealthChartInfoWidget), findsOneWidget);
    });

    testWidgets('renders blood pressure chart using BP-specific widget',
        (tester) async {
      when(
        () => mockJournalDb.getQuantitativeByType(
          type: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testBpSystolicEntry]);

      when(
        () => mockJournalDb.getQuantitativeByType(
          type: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testBpDiastolicEntry]);

      const bpType = 'BLOOD_PRESSURE';

      when(
        () => mockHealthImport.fetchHealthDataDelta(bpType),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHealthChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: const DashboardHealthItem(
              color: '#0000FF',
              healthType: bpType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Blood Pressure'), findsOneWidget);
      // BP type uses specialized widget instead of generic chart
      expect(find.byType(DashboardHealthBpChart), findsOneWidget);
    });
  });
}
