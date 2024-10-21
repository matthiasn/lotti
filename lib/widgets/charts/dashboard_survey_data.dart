import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

const panasSurveyTaskName = 'panasSurveyTask';
const cfq11SurveyTaskName = 'cfq11SurveyTask';
const ghq12SurveyTaskName = 'ghq12SurveyTask';

DashboardSurveyItem cfq11SurveyChart = const DashboardSurveyItem(
  surveyType: 'cfq11SurveyTask',
  surveyName: 'CFQ11',
  colorsByScoreKey: {'CFQ11': '#82E6CE'},
);

DashboardSurveyItem ghq12SurveyChart = const DashboardSurveyItem(
  surveyType: ghq12SurveyTaskName,
  surveyName: 'GHQ12',
  colorsByScoreKey: {'GHQ12': '#82E6CE'},
);

DashboardSurveyItem panasSurveyChart = const DashboardSurveyItem(
  surveyType: panasSurveyTaskName,
  surveyName: 'PANAS',
  colorsByScoreKey: {
    'Positive Affect Score': '#00FF00',
    'Negative Affect Score': '#FF0000',
  },
);

Map<String, DashboardSurveyItem> surveyTypes = {
  cfq11SurveyTaskName: cfq11SurveyChart,
  ghq12SurveyTaskName: ghq12SurveyChart,
  panasSurveyTaskName: panasSurveyChart,
};

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
      color.withOpacity(0.6),
      color.withOpacity(0.9),
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
          colors:
              gradientColors.map((color) => color.withOpacity(0.1)).toList(),
        ),
      ),
    );
  }).toList();
}
