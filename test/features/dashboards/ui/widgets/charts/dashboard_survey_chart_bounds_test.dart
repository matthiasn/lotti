import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/research_package.dart';

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

  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  // -------------------------------------------------------------------------
  // Single-series chart (CFQ11)
  // -------------------------------------------------------------------------
  group('DashboardSurveyChart — multi-series (PANAS)', () {
    const chartConfig = DashboardSurveyItem(
      surveyType: panasSurveyTaskName,
      surveyName: 'PANAS',
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
    );

    testWidgets('renders survey name "PANAS" in header', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      expect(find.text('PANAS'), findsOneWidget);
    });

    testWidgets('empty entity list produces two series each with zero spots', (
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
      expect(
        lineChart.data.lineBarsData,
        hasLength(2),
        reason: 'PANAS chart config has two score keys → two series',
      );
      for (final bar in lineChart.data.lineBarsData) {
        expect(bar.spots, isEmpty);
      }
    });

    testWidgets(
      'survey entries populate both series independently',
      (tester) async {
        // Build a PANAS entry carrying scores for both keys.
        final date1 = DateTime(2024, 3, 10);
        final meta = Metadata(
          id: 'panas-1',
          createdAt: date1,
          updatedAt: date1,
          dateFrom: date1,
          dateTo: date1.add(const Duration(minutes: 5)),
          vectorClock: const VectorClock({}),
        );
        final entry = JournalEntity.survey(
          meta: meta,
          data: SurveyData(
            taskResult: RPTaskResult(identifier: panasSurveyTaskName),
            scoreDefinitions: {
              'Positive Affect Score': {'q1', 'q2'},
              'Negative Affect Score': {'q3', 'q4'},
            },
            calculatedScores: const {
              'Positive Affect Score': 35,
              'Negative Affect Score': 12,
            },
          ),
        );

        when(
          () => mockJournalDb.getSurveyCompletionsByType(
            type: any(named: 'type'),
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [entry]);

        await hPumpSurveyChart(tester, chartConfig: chartConfig);

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        expect(lineChart.data.lineBarsData, hasLength(2));

        // Both series have exactly one spot.
        for (final bar in lineChart.data.lineBarsData) {
          expect(bar.spots, hasLength(1));
        }

        // Spot values correspond to the scores (order matches colorsByScoreKey).
        final positiveSpots = lineChart.data.lineBarsData[0].spots;
        final negativeSpots = lineChart.data.lineBarsData[1].spots;
        expect(positiveSpots.first.y, 35.0);
        expect(negativeSpots.first.y, 12.0);
      },
    );

    testWidgets('x-axis range matches rangeStart/rangeEnd', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(
        tester,
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

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
  });

  // -------------------------------------------------------------------------
  // GHQ12 chart — covers the ghq12SurveyTaskName branch in onTapAdd
  // -------------------------------------------------------------------------
  group('DashboardSurveyChart — GHQ12', () {
    const chartConfig = DashboardSurveyItem(
      surveyType: ghq12SurveyTaskName,
      surveyName: 'GHQ12',
      colorsByScoreKey: {'GHQ12': '#82E6CE'},
    );

    testWidgets('renders survey name "GHQ12" and add button', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(tester, chartConfig: chartConfig);

      expect(find.text('GHQ12'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('GHQ12 entry produces one spot with correct y value', (
      tester,
    ) async {
      final entries = <JournalEntity>[
        hMakeSurveyEntry(
          id: 'ghq-1',
          dateFrom: DateTime(2024, 3, 12),
          scoreKey: 'GHQ12',
          scoreValue: 7,
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
      expect(spots, hasLength(1));
      expect(spots.first.y, 7.0);
    });
  });

  // -------------------------------------------------------------------------
  // minVal / maxVal computation from spots
  // -------------------------------------------------------------------------
  group('DashboardSurveyChart — minVal/maxVal Y-axis bounds', () {
    const chartConfig = DashboardSurveyItem(
      surveyType: cfq11SurveyTaskName,
      surveyName: 'CFQ11',
      colorsByScoreKey: {'CFQ11': '#82E6CE'},
    );

    testWidgets('empty data → minY and maxY both derive from 0', (
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

      // minVal=0, maxVal=0 → valRange=0, minY=max(0-0,0)=0, maxY=0+0=0
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.minY, 0.0);
      expect(lineChart.data.maxY, 0.0);
    });

    testWidgets(
      'two entries with scores 20 and 80 produce correct Y bounds',
      (tester) async {
        final entries = <JournalEntity>[
          hMakeSurveyEntry(
            id: 'y1',
            dateFrom: DateTime(2024, 3, 5),
            scoreKey: 'CFQ11',
            scoreValue: 20,
          ),
          hMakeSurveyEntry(
            id: 'y2',
            dateFrom: DateTime(2024, 3, 20),
            scoreKey: 'CFQ11',
            scoreValue: 80,
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

        // minVal=20, maxVal=80, valRange=60
        // minY = max(20 - 60*0.2, 0) = max(8, 0) = 8
        // maxY = 80 + 60*0.2 = 92
        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        expect(lineChart.data.minY, 8.0);
        expect(lineChart.data.maxY, 92.0);
      },
    );
  });

  // -------------------------------------------------------------------------
  // onTapAdd: tapping the add-button opens the matching survey modal.
  // Each surveyType routes to a different runXxx() helper, which loads a
  // distinct RPOrderedTask. We assert on the task identifier of the rendered
  // RPUITask, which uniquely identifies the survey that was launched.
  // -------------------------------------------------------------------------
  group('DashboardSurveyChart — add-button launches survey', () {
    /// Taps the add-button and lets the survey modal sheet open.
    Future<void> tapAdd(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // surveyType -> expected RPOrderedTask identifier launched on tap.
    final cases = <(String surveyType, String surveyName, String taskId)>[
      (cfq11SurveyTaskName, 'CFQ11', 'cfq11SurveyTask'),
      (panasSurveyTaskName, 'PANAS', 'panasSurveyTask'),
      (ghq12SurveyTaskName, 'GHQ12', 'ghq12SurveyTask'),
    ];

    for (final (surveyType, surveyName, taskId) in cases) {
      testWidgets('tapping add for $surveyName launches the $taskId task', (
        tester,
      ) async {
        when(
          () => mockJournalDb.getSurveyCompletionsByType(
            type: any(named: 'type'),
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []);

        await hPumpSurveyChart(
          tester,
          chartConfig: DashboardSurveyItem(
            surveyType: surveyType,
            surveyName: surveyName,
            colorsByScoreKey: const {'k': '#82E6CE'},
          ),
        );

        // No survey is open before tapping.
        expect(find.byType(RPUITask), findsNothing);

        await tapAdd(tester);

        // Exactly the matching survey's task is now driving the modal, proving
        // the correct branch of onTapAdd fired and routed to the right runXxx().
        final task = tester.widget<RPUITask>(find.byType(RPUITask)).task;
        expect(
          task.identifier,
          taskId,
          reason: 'Tapping add for $surveyType must launch the $taskId survey.',
        );
      });
    }

    testWidgets('unknown survey type opens no survey on tap', (tester) async {
      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      await hPumpSurveyChart(
        tester,
        chartConfig: const DashboardSurveyItem(
          surveyType: 'unknownSurveyTask',
          surveyName: 'Unknown',
          colorsByScoreKey: {'k': '#82E6CE'},
        ),
      );

      await tapAdd(tester);

      // Every if-condition in onTapAdd evaluated false, so no survey opened.
      expect(find.byType(RPUITask), findsNothing);
    });
  });
}
