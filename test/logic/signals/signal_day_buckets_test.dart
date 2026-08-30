import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';

import 'signal_test_fixtures.dart';

void main() {
  final day = DateTime.utc(2026, 8, 8);

  group('signalDayKey', () {
    test('re-stamps the local calendar date as midnight UTC', () {
      expect(signalDayKey(DateTime(2026, 8, 8, 23, 59)), day);
      expect(signalDayKey(DateTime(2026, 8, 8, 0, 0, 1)), day);
      expect(signalDayKey(DateTime(2026, 8, 9)), isNot(day));
    });
  });

  group('trailingAverageOn', () {
    test('averages recorded values in the inclusive seven-day window', () {
      final values = {
        day.subtract(const Duration(days: 7)): 100,
        day.subtract(const Duration(days: 6)): 20,
        day.subtract(const Duration(days: 3)): 40,
        day: 60,
        day.add(const Duration(days: 1)): 1000,
      };

      expect(trailingAverageOn(values, day: day), 40);
    });

    test('missing days are gaps and an empty window has no average', () {
      expect(
        trailingAverageOn({day.subtract(const Duration(days: 2)): 0}, day: day),
        0,
      );
      expect(
        trailingAverageOn(
          {day.subtract(const Duration(days: 7)): 100},
          day: day,
        ),
        isNull,
      );
    });
  });

  group('bucketQuantitativeByDay', () {
    test('cumulative counters keep the day peak, not the sum', () {
      final byDay = bucketQuantitativeByDay([
        stepsEntity(DateTime(2026, 8, 8, 9), 2000),
        stepsEntity(DateTime(2026, 8, 8, 18), 7412),
        stepsEntity(DateTime(2026, 8, 7, 20), 3000),
      ], 'cumulative_step_count');
      expect(byDay, {day: 7412, DateTime.utc(2026, 8, 7): 3000});
    });

    test('point samples keep the latest reading, id breaks ties', () {
      final at = DateTime(2026, 8, 8, 7);
      final byDay = bucketQuantitativeByDay([
        weightEntity(DateTime(2026, 8, 8, 6), 80),
        weightEntity(at, 81, id: 'b'),
        weightEntity(at, 82, id: 'a'),
      ], 'HealthDataType.WEIGHT');
      // Newest timestamp wins; among equal timestamps the greater id wins.
      expect(byDay, {day: 81});
    });

    test('an unknown type sums the day rather than going silent', () {
      final byDay = bucketQuantitativeByDay([
        stepsEntity(DateTime(2026, 8, 8, 9), 1),
        stepsEntity(DateTime(2026, 8, 8, 10), 2),
      ], 'no_such_type');
      expect(byDay, {day: 3});
    });

    test('percentage types are scaled to whole percentages', () {
      expect(
        quantitativeDisplayMultiplier('HealthDataType.BODY_FAT_PERCENTAGE'),
        100,
      );
      expect(quantitativeDisplayMultiplier('HealthDataType.WEIGHT'), 1);
    });
  });

  group('bucketMeasurableTotalsByDay', () {
    test('sums a day and keeps a recorded zero as present', () {
      final byDay = bucketMeasurableTotalsByDay([
        measurementEntity(DateTime(2026, 8, 8, 8), 250),
        measurementEntity(DateTime(2026, 8, 8, 12), 500),
        measurementEntity(DateTime(2026, 8, 7, 12), 0),
      ]);
      expect(byDay, {day: 750, DateTime.utc(2026, 8, 7): 0});
      expect(byDay.containsKey(DateTime.utc(2026, 8, 6)), isFalse);
    });

    test('ignores entities that are not measurements', () {
      expect(
        bucketMeasurableTotalsByDay([stepsEntity(DateTime(2026, 8, 8), 5)]),
        isEmpty,
      );
    });
  });

  group('bucketWorkoutsByDay / workoutSignalValue', () {
    test('groups by start day and keeps every workout', () {
      final morning = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30),
        distance: 5000,
        energy: 320,
      );
      final evening = workoutEntity(
        DateTime(2026, 8, 8, 19),
        length: const Duration(minutes: 45),
      );
      final byDay = bucketWorkoutsByDay([morning, evening]);
      expect(byDay.keys, [day]);
      expect(byDay[day]!.length, 2);
    });

    test('ignores entities that are not workouts', () {
      expect(
        bucketWorkoutsByDay([measurementEntity(DateTime(2026, 8, 8), 1)]),
        isEmpty,
      );
    });

    test('values are minutes, kilometres and kcal', () {
      final workout = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30, seconds: 30),
        distance: 5250,
        energy: 320,
      );
      final data = (workout as WorkoutEntry).data;
      expect(workoutSignalValue(data, WorkoutValueType.duration), 30.5);
      expect(workoutSignalValue(data, WorkoutValueType.distance), 5.25);
      expect(workoutSignalValue(data, WorkoutValueType.energy), 320);
    });

    test('missing distance and energy contribute zero, not a crash', () {
      final data =
          (workoutEntity(
                    DateTime(2026, 8, 8),
                    length: const Duration(minutes: 1),
                  )
                  as WorkoutEntry)
              .data;
      expect(workoutSignalValue(data, WorkoutValueType.distance), 0);
      expect(workoutSignalValue(data, WorkoutValueType.energy), 0);
    });
  });

  group('habitSuccessDays', () {
    test('only successes count; skip, fail, open and null do not', () {
      final days = habitSuccessDays([
        habitCompletionEntity(
          DateTime(2026, 8, 8, 9),
          HabitCompletionType.success,
        ),
        habitCompletionEntity(
          DateTime(2026, 8, 7, 9),
          HabitCompletionType.skip,
        ),
        habitCompletionEntity(
          DateTime(2026, 8, 6, 9),
          HabitCompletionType.fail,
        ),
        habitCompletionEntity(
          DateTime(2026, 8, 5, 9),
          HabitCompletionType.open,
        ),
        habitCompletionEntity(DateTime(2026, 8, 4, 9), null),
      ]);
      expect(days, {day});
    });

    test('ignores entities that are not habit completions', () {
      expect(habitSuccessDays([stepsEntity(DateTime(2026, 8, 8), 1)]), isEmpty);
    });
  });
}
