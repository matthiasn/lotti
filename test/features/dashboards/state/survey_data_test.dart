import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
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

  // -------------------------------------------------------------------------
  // Glados property tests.
  // -------------------------------------------------------------------------

  const panasSurveyForProperty = DashboardSurveyItem(
    surveyType: 'panasSurveyTask',
    surveyName: 'PANAS',
    colorsByScoreKey: {
      'Positive Affect Score': '#00FF00',
      'Negative Affect Score': '#FF0000',
    },
  );

  group('aggregateSurvey — properties', () {
    glados.Glados(
      glados.any.intInRange(0, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'only SurveyEntry items contribute to output',
      (quantCount) {
        // Mix of quantitative entries (should be ignored) and survey entries.
        final entities = <JournalEntity>[
          for (var i = 0; i < quantCount; i++)
            makeQuantitativeEntry(
              dateFrom: DateTime(2024, 3, 15 + i),
              value: 72,
              dataType: 'HealthDataType.WEIGHT',
              id: 'q$i',
            ),
          makeSurveyEntry(
            dateFrom: DateTime(2024, 3, 20),
            calculatedScores: {'Positive Affect Score': 35},
            id: 's1',
          ),
        ];
        final result = aggregateSurvey(
          entities: entities,
          dashboardSurveyItem: panasSurveyForProperty,
          scoreKey: 'Positive Affect Score',
        );
        // Exactly one SurveyEntry with the key exists → length must be 1.
        expect(result, hasLength(1));
        expect(result.first.value, equals(35));
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.intInRange(1, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'entries missing the scoreKey are excluded',
      (n) {
        // Build n entries that each have only the Negative score.
        final entities = <SurveyEntry>[
          for (var i = 0; i < n; i++)
            makeSurveyEntry(
              dateFrom: DateTime(2024, 3, 15 + i),
              calculatedScores: {'Negative Affect Score': 10 + i},
              id: 's$i',
            ),
        ];
        final result = aggregateSurvey(
          entities: entities,
          dashboardSurveyItem: panasSurveyForProperty,
          scoreKey: 'Positive Affect Score',
        );
        expect(
          result,
          isEmpty,
          reason: 'no entry has the Positive Affect Score key',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.intInRange(1, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output length equals number of entries that contain the scoreKey',
      (n) {
        // All n entries have Positive score; only every other has Negative.
        final entities = <SurveyEntry>[
          for (var i = 0; i < n; i++)
            makeSurveyEntry(
              dateFrom: DateTime(2024, 3, 15 + i),
              calculatedScores: {
                'Positive Affect Score': 30 + i,
                if (i.isEven) 'Negative Affect Score': 10 + i,
              },
              id: 's$i',
            ),
        ];
        final positiveResult = aggregateSurvey(
          entities: entities,
          dashboardSurveyItem: panasSurveyForProperty,
          scoreKey: 'Positive Affect Score',
        );
        expect(positiveResult.length, equals(n));

        final negativeResult = aggregateSurvey(
          entities: entities,
          dashboardSurveyItem: panasSurveyForProperty,
          scoreKey: 'Negative Affect Score',
        );
        // Only even-index entries have Negative score: 0, 2, 4, ...
        final expectedNegCount = (n + 1) ~/ 2;
        expect(negativeResult.length, equals(expectedNegCount));
      },
      tags: 'glados',
    );
  });
}
