import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:research_package/research_package.dart';

import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [SurveyEntry] with given [scoreKey]/[scoreValue] and
/// a deterministic [dateFrom].
SurveyEntry hMakeSurveyEntry({
  required String id,
  required DateTime dateFrom,
  required String scoreKey,
  required int scoreValue,
}) {
  return JournalEntity.survey(
        meta: Metadata(
          id: id,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          dateFrom: dateFrom,
          dateTo: dateFrom.add(const Duration(minutes: 5)),
          vectorClock: const VectorClock({}),
        ),
        data: SurveyData(
          taskResult: RPTaskResult(identifier: 'test_survey'),
          scoreDefinitions: {
            scoreKey: {'q1', 'q2'},
          },
          calculatedScores: {scoreKey: scoreValue},
        ),
      )
      as SurveyEntry;
}

/// Pumps [DashboardSurveyChart] inside a sized surface so fl_chart can lay
/// out. Sets [physicalSize] and registers an [addTearDown] per conventions.
///
/// Caller must have already stubbed `mockJournalDb.getSurveyCompletionsByType`
/// before calling this helper.
Future<void> hPumpSurveyChart(
  WidgetTester tester, {
  required DashboardSurveyItem chartConfig,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  Size physicalSize = const Size(800, 600),
}) async {
  final start = rangeStart ?? DateTime(2024, 3);
  final end = rangeEnd ?? DateTime(2024, 3, 31);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SizedBox(
          width: physicalSize.width,
          height: physicalSize.height,
          child: DashboardSurveyChart(
            chartConfig: chartConfig,
            rangeStart: start,
            rangeEnd: end,
          ),
        ),
      ),
    ),
  );
  // First pump triggers the async provider build.
  await tester.pump();
  // Second pump lets the resolved future propagate to the widget.
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
