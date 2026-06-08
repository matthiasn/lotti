import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import 'dashboard_survey_chart_test_helpers.dart';

void main() {
  late MockJournalDb mockJournalDb;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    final mocks = await setUpTestGetIt();
    mockJournalDb = mocks.journalDb;

    // The add-button (onTapAdd) builds a resultCallback via
    // createResultCallback, which eagerly reads getIt<PersistenceLogic>().
    // Register a mock so tapping the button does not throw. Cleared by
    // tearDownTestGetIt -> getIt.reset().
    getIt.registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(tearDownTestGetIt);

  // -------------------------------------------------------------------------
  // Single-series chart (CFQ11)
  // -------------------------------------------------------------------------
  group('DashboardSurveyChart — single-series (CFQ11)', () {
    const chartConfig = DashboardSurveyItem(
      surveyType: cfq11SurveyTaskName,
      surveyName: 'CFQ11',
      colorsByScoreKey: {'CFQ11': '#82E6CE'},
    );

    testWidgets('renders survey name in header', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      expect(
        find.text('CFQ11'),
        findsOneWidget,
        reason: 'surveyName label must appear in chart header',
      );
    });

    testWidgets('renders add-button (Icons.add_rounded) in header', (
      tester,
    ) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('empty entity list produces one series with empty spots', (
      tester,
    ) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // One series (CFQ11) with zero spots.
      expect(lineChart.data.lineBarsData, hasLength(1));
      expect(
        lineChart.data.lineBarsData.first.spots,
        isEmpty,
        reason: 'No entities → no spots in the single series',
      );
    });

    testWidgets('survey entries produce one spot per entry per score key', (
      tester,
    ) async {
      final entries = <JournalEntity>[
        hMakeSurveyEntry(
          id: 'e1',
          dateFrom: DateTime(2024, 3, 5),
          scoreKey: 'CFQ11',
          scoreValue: 42,
        ),
        hMakeSurveyEntry(
          id: 'e2',
          dateFrom: DateTime(2024, 3, 15),
          scoreKey: 'CFQ11',
          scoreValue: 30,
        ),
        hMakeSurveyEntry(
          id: 'e3',
          dateFrom: DateTime(2024, 3, 20),
          scoreKey: 'CFQ11',
          scoreValue: 55,
        ),
      ];

      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(1));
      final spots = lineChart.data.lineBarsData.first.spots;
      expect(spots, hasLength(3));

      // Verify y values match scores in order.
      expect(spots[0].y, 42.0);
      expect(spots[1].y, 30.0);
      expect(spots[2].y, 55.0);
    });

    testWidgets('spot x values match millisecondsSinceEpoch of dateFrom', (
      tester,
    ) async {
      final date1 = DateTime(2024, 3, 5);
      final date2 = DateTime(2024, 3, 20);

      final entries = <JournalEntity>[
        hMakeSurveyEntry(
          id: 'x1',
          dateFrom: date1,
          scoreKey: 'CFQ11',
          scoreValue: 10,
        ),
        hMakeSurveyEntry(
          id: 'x2',
          dateFrom: date2,
          scoreKey: 'CFQ11',
          scoreValue: 20,
        ),
      ];

      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = lineChart.data.lineBarsData.first.spots;
      expect(spots[0].x, date1.millisecondsSinceEpoch.toDouble());
      expect(spots[1].x, date2.millisecondsSinceEpoch.toDouble());
    });

    testWidgets('entries with mismatched score key produce no spots', (
      tester,
    ) async {
      // Entry uses 'OTHER_KEY' but chart config only maps 'CFQ11'.
      final entries = <JournalEntity>[
        hMakeSurveyEntry(
          id: 'miss1',
          dateFrom: DateTime(2024, 3, 10),
          scoreKey: 'OTHER_KEY',
          scoreValue: 99,
        ),
      ];

      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        lineChart.data.lineBarsData.first.spots,
        isEmpty,
        reason: 'Score key mismatch → no matching observations',
      );
    });

    testWidgets('DashboardChart height is 180', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 180),
        isTrue,
        reason: 'DashboardChart passes height:180 to SizedBox',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Multi-series chart (PANAS — two score keys)
  // -------------------------------------------------------------------------
}
