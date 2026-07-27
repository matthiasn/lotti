import 'package:flutter_test/flutter_test.dart';

import 'day_planning_full_journey_config.dart';

void main() {
  test('blank model selection uses the non-empty default matrix', () {
    expect(fullJourneyModelIds(null), fullJourneyDefaultModelIds);
    expect(fullJourneyModelIds('  , '), fullJourneyDefaultModelIds);
  });

  test(
    'model and scenario CSV values are trimmed and empty entries dropped',
    () {
      expect(
        fullJourneyModelIds(' glm-5.2, ,qwen3.5-397b-a17b '),
        ['glm-5.2', 'qwen3.5-397b-a17b'],
      );
      expect(parseFullJourneyCsv(' dense-rest-of-day, , overloaded '), [
        'dense-rest-of-day',
        'overloaded',
      ]);
    },
  );

  test('evaluation date is fixed by default and accepts an explicit date', () {
    expect(fullJourneyEvaluationDate(null), DateTime(2030, 1, 15));
    expect(fullJourneyEvaluationDate('2040-06-03'), DateTime(2040, 6, 3));
  });

  test('evaluation date rejects timestamps and impossible dates', () {
    for (final invalid in ['2040-06-03T09:00:00', '2040-02-30', 'tomorrow']) {
      expect(
        () => fullJourneyEvaluationDate(invalid),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('DAY_PLANNING_EVAL_DATE'),
          ),
        ),
      );
    }
  });

  test(
    'scenario clock stays on the configured date as elapsed time advances',
    () {
      final value = fullJourneyClockValue(
        evaluationDate: DateTime(2040, 6, 3),
        startHour: 12,
        elapsed: const Duration(minutes: 17),
      );

      expect(value, DateTime(2040, 6, 3, 12, 17));
    },
  );
}
