import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';
import '../../test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('DashboardMeasurablesChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    testWidgets('weight chart is rendered', (tester) async {
      when(
        () => mockJournalDb.watchQuantitativeByType(
          type: testWeightEntry.data.dataType,
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWeightEntry]
        ]),
      );

      when(
        () => mockHealthImport
            .fetchHealthDataDelta(testWeightEntry.data.dataType),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHealthChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.WEIGHT',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Weight'),
        findsOneWidget,
      );
    });

    testWidgets('BP chart is rendered', (tester) async {
      when(
        () => mockJournalDb.watchQuantitativeByTypes(
          types: [
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
            'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          ],
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) {
        return Stream<List<JournalEntity>>.fromIterable([
          [
            testBpSystolicEntry,
            testBpDiastolicEntry,
          ]
        ]);
      });

      const bpType = 'BLOOD_PRESSURE';

      when(
        () => mockHealthImport.fetchHealthDataDelta(bpType),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHealthChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardHealthItem(
              color: '#0000FF',
              healthType: bpType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Blood Pressure'),
        findsOneWidget,
      );
    });

    testWidgets('BMI chart is rendered', (tester) async {
      when(
        () => mockJournalDb.watchQuantitativeByType(
          type: testHeightEntry.data.dataType,
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testHeightEntry]
        ]),
      );

      when(
        () => mockJournalDb.watchQuantitativeByType(
          type: testWeightEntry.data.dataType,
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [
            testWeightEntry,
            testWeightEntry2,
          ]
        ]),
      );

      when(
        () => mockJournalDb.watchQuantitativeByTypes(
          types: [
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
            'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          ],
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) {
        return Stream<List<JournalEntity>>.fromIterable([
          [
            testBpSystolicEntry,
            testBpDiastolicEntry,
          ]
        ]);
      });

      const healthType = 'BODY_MASS_INDEX';

      when(
        () => mockHealthImport.fetchHealthDataDelta(healthType),
      ).thenAnswer((_) async {});

      when(
        () => mockHealthImport.fetchHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          types: any(named: 'types'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHealthChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardHealthItem(
              color: '#0000FF',
              healthType: healthType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Weight vs. Body Mass Index'),
        findsOneWidget,
      );

      // chart displays expected min and max weights
      expect(find.text('Min: 94.5 kg'), findsOneWidget);
      expect(find.text('Max: 99.2 kg'), findsOneWidget);
    });
  });
}
