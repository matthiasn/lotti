import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

// Stable task identifiers for the three bundled surveys. These match the survey
// definitions' task names and are the keys under which completions are stored
// and looked up.
const panasSurveyTaskName = 'panasSurveyTask';
const cfq11SurveyTaskName = 'cfq11SurveyTask';
const ghq12SurveyTaskName = 'ghq12SurveyTask';

/// Chart definition for the CFQ-11 survey: a single score line. The
/// `colorsByScoreKey` keys also select which `calculatedScores` entries are
/// plotted (here just `CFQ11`).
DashboardSurveyItem cfq11SurveyChart = const DashboardSurveyItem(
  surveyType: 'cfq11SurveyTask',
  surveyName: 'CFQ11',
  colorsByScoreKey: {'CFQ11': '#82E6CE'},
);

/// Chart definition for the GHQ-12 survey: a single `GHQ12` score line.
DashboardSurveyItem ghq12SurveyChart = const DashboardSurveyItem(
  surveyType: ghq12SurveyTaskName,
  surveyName: 'GHQ12',
  colorsByScoreKey: {'GHQ12': '#82E6CE'},
);

/// Chart definition for the PANAS survey: two lines — Positive Affect (green)
/// and Negative Affect (red) — both pulled from the completion's
/// `calculatedScores`.
DashboardSurveyItem panasSurveyChart = const DashboardSurveyItem(
  surveyType: panasSurveyTaskName,
  surveyName: 'PANAS',
  colorsByScoreKey: {
    'Positive Affect Score': '#00FF00',
    'Negative Affect Score': '#FF0000',
  },
);

/// The bundled survey chart definitions keyed by task name, used when adding a
/// survey series to a dashboard.
Map<String, DashboardSurveyItem> surveyTypes = {
  cfq11SurveyTaskName: cfq11SurveyChart,
  ghq12SurveyTaskName: ghq12SurveyChart,
  panasSurveyTaskName: panasSurveyChart,
};

/// Extracts the time series for one score key from survey completions: one
/// observation per completion that has a value for [scoreKey] (dated at the
/// entry's `dateFrom`). Non-survey entities and completions missing the key are
/// skipped.
List<Observation> aggregateSurvey({
  required List<JournalEntity> entities,
  required DashboardSurveyItem dashboardSurveyItem,
  required String scoreKey,
}) {
  final aggregated = <Observation>[];

  for (final entity in entities) {
    entity.maybeMap(
      survey: (SurveyEntry surveyEntry) {
        final num? value = surveyEntry.data.calculatedScores[scoreKey];
        if (value != null) {
          aggregated.add(
            Observation(
              surveyEntry.meta.dateFrom,
              value,
            ),
          );
        }
      },
      orElse: () {},
    );
  }

  return aggregated;
}

/// Builds one fully-styled fl_chart line per score key in
/// `dashboardSurveyItem.colorsByScoreKey`: a smoothed, gradient-filled curve
/// coloured from the item's hex map (falling back to `#82E6CE`), with x in
/// epoch-millis and dots hidden. This is what the survey chart hands to the
/// multi-line renderer.
List<LineChartBarData> surveyLines({
  required List<JournalEntity> entities,
  required DashboardSurveyItem dashboardSurveyItem,
}) {
  final colorsByScoreKey = dashboardSurveyItem.colorsByScoreKey;

  return dashboardSurveyItem.colorsByScoreKey.keys.map((scoreKey) {
    final color = colorFromCssHex(colorsByScoreKey[scoreKey] ?? '#82E6CE');

    final data = aggregateSurvey(
      entities: entities,
      dashboardSurveyItem: dashboardSurveyItem,
      scoreKey: scoreKey,
    );
    final spots = data
        .map(
          (item) => FlSpot(
            item.dateTime.millisecondsSinceEpoch.toDouble(),
            item.value.toDouble(),
          ),
        )
        .toList();

    final gradientColors = <Color>[
      color.withAlpha(153),
      color.withAlpha(230),
    ];

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.1,
      color: color,
      gradient: LinearGradient(
        colors: gradientColors,
      ),
      isStrokeCapRound: true,
      dotData: const FlDotData(
        show: false,
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: gradientColors.map((color) => color.withAlpha(26)).toList(),
        ),
      ),
    );
  }).toList();
}
