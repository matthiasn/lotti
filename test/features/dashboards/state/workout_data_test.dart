import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_data.dart';

import '../test_utils.dart';

void main() {
  final rangeStart = DateTime(2024, 3, 10);
  final rangeEnd = DateTime(2024, 3, 15);

  const runningEnergyConfig = DashboardWorkoutItem(
    workoutType: 'running',
    displayName: 'Running (calories)',
    color: '#82E6CE',
    valueType: WorkoutValueType.energy,
  );

  const runningDistanceConfig = DashboardWorkoutItem(
    workoutType: 'running',
    displayName: 'Running distance',
    color: '#82E6CE',
    valueType: WorkoutValueType.distance,
  );

  const runningDurationConfig = DashboardWorkoutItem(
    workoutType: 'running',
    displayName: 'Running (time)',
    color: '#82E6CE',
    valueType: WorkoutValueType.duration,
  );

  group('aggregateWorkoutDailySum', () {
    test('returns zeros for all days in range when entities list is empty', () {
      final result = aggregateWorkoutDailySum(
        [],
        chartConfig: runningEnergyConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // 5 days: March 10, 11, 12, 13, 14
      expect(result, hasLength(5));
      for (final obs in result) {
        expect(obs.value, 0);
      }
    });

    test('sums energy values for matching workout type', () {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 11, 8),
          dateTo: DateTime(2024, 3, 11, 9),
          workoutType: 'running',
          energy: 300,
          id: 'w1',
        ),
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 11, 17),
          dateTo: DateTime(2024, 3, 11, 18),
          workoutType: 'running',
          energy: 200,
          id: 'w2',
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningEnergyConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final march11 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 11),
      );
      expect(march11.value, 500);
    });

    test('sums distance values for matching workout type', () {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 12, 7),
          dateTo: DateTime(2024, 3, 12, 8),
          workoutType: 'running',
          distance: 5000,
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningDistanceConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final march12 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 12),
      );
      expect(march12.value, 5000);
    });

    test('calculates duration in minutes from dateFrom/dateTo', () {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 13, 10),
          dateTo: DateTime(2024, 3, 13, 11, 30),
          workoutType: 'running',
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningDurationConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final march13 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 13),
      );
      // 1h 30m = 90 minutes
      expect(march13.value, 90);
    });

    test('ignores non-matching workout types', () {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 11, 8),
          dateTo: DateTime(2024, 3, 11, 9),
          workoutType: 'swimming',
          energy: 500,
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningEnergyConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // All values should be 0 since swimming != running
      for (final obs in result) {
        expect(obs.value, 0);
      }
    });

    test('ignores unrelated QuantitativeEntry values', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 12),
          value: 100,
          dataType: 'some_unrelated_type',
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningEnergyConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final march12 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 12),
      );
      // Unrelated QuantitativeEntry values should not be included
      expect(march12.value, 0);
    });

    test('sums multiple workouts on the same day', () {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 14, 6),
          dateTo: DateTime(2024, 3, 14, 7),
          workoutType: 'running',
          energy: 400,
          id: 'w1',
        ),
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 14, 18),
          dateTo: DateTime(2024, 3, 14, 19),
          workoutType: 'running',
          energy: 350,
          id: 'w2',
        ),
      ];

      final result = aggregateWorkoutDailySum(
        entities,
        chartConfig: runningEnergyConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final march14 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 14),
      );
      expect(march14.value, 750);
    });
  });
}
