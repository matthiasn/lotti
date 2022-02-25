import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

var cfq11SurveyChart = DashboardSurveyItem(
  surveyType: 'cfq11SurveyTask',
  surveyName: 'CFQ11',
  colorsByScoreKey: {'CFQ11': '#0000FF'},
);

var panasSurveyChart = DashboardSurveyItem(
  surveyType: 'panasSurveyTask',
  surveyName: 'PANAS',
  colorsByScoreKey: {
    'Positive Affect Score': '#00FF00',
    'Negative Affect Score': '#FF0000',
  },
);

Map<String, DashboardSurveyItem> surveyTypes = {
  'cfq11SurveyTask': cfq11SurveyChart,
  'panasSurveyTask': panasSurveyChart,
};

List<Observation> aggregateSurvey({
  required List<JournalEntity?> entities,
  required DashboardSurveyItem dashboardSurveyItem,
  required String scoreKey,
}) {
  List<Observation> aggregated = [];

  for (JournalEntity? entity in entities) {
    entity?.maybeMap(
      survey: (SurveyEntry surveyEntry) {
        num? value = surveyEntry.data.calculatedScores[scoreKey];
        if (value != null) {
          aggregated.add(Observation(
            surveyEntry.meta.dateFrom,
            value,
          ));
        }
      },
      orElse: () {},
    );
  }

  return aggregated;
}
