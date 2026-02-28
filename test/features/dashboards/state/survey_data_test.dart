import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';

import '../test_utils.dart';

void main() {
  group('aggregateSurvey', () {
    const panasSurvey = DashboardSurveyItem(
      surveyType: 'panasSurveyTask',
      surveyName: 'PANAS',
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
    );

    test('extracts correct scoreKey values from survey entries', () {
      final entities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 15, 10),
          calculatedScores: {
            'Positive Affect Score': 35,
            'Negative Affect Score': 15,
          },
          id: 's1',
        ),
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 16, 11),
          calculatedScores: {
            'Positive Affect Score': 40,
            'Negative Affect Score': 12,
          },
          id: 's2',
        ),
      ];

      final positiveResult = aggregateSurvey(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
        scoreKey: 'Positive Affect Score',
      );

      expect(positiveResult, hasLength(2));
      expect(positiveResult[0].value, 35);
      expect(positiveResult[1].value, 40);
    });

    test('skips entries missing the scoreKey', () {
      final entities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 15),
          calculatedScores: {'Positive Affect Score': 35},
        ),
      ];

      final result = aggregateSurvey(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
        scoreKey: 'Negative Affect Score',
      );

      expect(result, isEmpty);
    });

    test('returns empty list for empty entities', () {
      final result = aggregateSurvey(
        entities: [],
        dashboardSurveyItem: panasSurvey,
        scoreKey: 'Positive Affect Score',
      );

      expect(result, isEmpty);
    });

    test('ignores non-survey entities', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 72,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateSurvey(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
        scoreKey: 'Positive Affect Score',
      );

      expect(result, isEmpty);
    });
  });

  group('surveyLines', () {
    const panasSurvey = DashboardSurveyItem(
      surveyType: 'panasSurveyTask',
      surveyName: 'PANAS',
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
    );

    test('produces one LineChartBarData per scoreKey', () {
      final entities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 15),
          calculatedScores: {
            'Positive Affect Score': 35,
            'Negative Affect Score': 15,
          },
        ),
      ];

      final result = surveyLines(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
      );

      expect(result, hasLength(2));
      expect(result, everyElement(isA<LineChartBarData>()));
    });

    test('each line has correct number of spots', () {
      final entities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 15),
          calculatedScores: {
            'Positive Affect Score': 35,
            'Negative Affect Score': 15,
          },
          id: 's1',
        ),
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 16),
          calculatedScores: {
            'Positive Affect Score': 40,
            'Negative Affect Score': 12,
          },
          id: 's2',
        ),
      ];

      final result = surveyLines(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
      );

      // Both lines should have 2 spots each
      for (final line in result) {
        expect(line.spots, hasLength(2));
      }
    });

    test('spots have correct x (milliseconds) and y (score) values', () {
      final date = DateTime(2024, 3, 15, 10);
      final entities = [
        makeSurveyEntry(
          dateFrom: date,
          calculatedScores: {
            'Positive Affect Score': 35,
            'Negative Affect Score': 15,
          },
        ),
      ];

      final result = surveyLines(
        entities: entities,
        dashboardSurveyItem: panasSurvey,
      );

      final positiveLine = result.first;
      expect(positiveLine.spots.first.x, date.millisecondsSinceEpoch);
      expect(positiveLine.spots.first.y, 35);
    });

    test('returns empty spots for no data', () {
      final result = surveyLines(
        entities: [],
        dashboardSurveyItem: panasSurvey,
      );

      expect(result, hasLength(2));
      for (final line in result) {
        expect(line.spots, isEmpty);
      }
    });
  });

  group('surveyTypes', () {
    test('contains expected survey type keys', () {
      expect(surveyTypes, contains('cfq11SurveyTask'));
      expect(surveyTypes, contains('ghq12SurveyTask'));
      expect(surveyTypes, contains('panasSurveyTask'));
    });

    test('PANAS survey has two score keys', () {
      final panas = surveyTypes['panasSurveyTask']!;
      expect(panas.colorsByScoreKey.keys, hasLength(2));
      expect(
        panas.colorsByScoreKey.keys,
        containsAll(['Positive Affect Score', 'Negative Affect Score']),
      );
    });

    test('CFQ11 survey has one score key', () {
      final cfq = surveyTypes['cfq11SurveyTask']!;
      expect(cfq.colorsByScoreKey.keys, hasLength(1));
      expect(cfq.colorsByScoreKey.keys, contains('CFQ11'));
    });

    test('GHQ12 survey has one score key', () {
      final ghq = surveyTypes['ghq12SurveyTask']!;
      expect(ghq.colorsByScoreKey.keys, hasLength(1));
      expect(ghq.colorsByScoreKey.keys, contains('GHQ12'));
    });
  });
}
