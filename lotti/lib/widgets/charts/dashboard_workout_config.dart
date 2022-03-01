import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

Map<String, DashboardWorkoutItem> workoutTypes = {
  'walking.duration': DashboardWorkoutItem(
    displayName: 'Walking minutes',
    workoutType: 'walking',
    color: '#0000FF',
    valueType: WorkoutValueType.duration,
  ),
  'walking.calories': DashboardWorkoutItem(
    displayName: 'Walking calories',
    workoutType: 'walking',
    color: '#0000FF',
    valueType: WorkoutValueType.energy,
  ),
  'walking.distance': DashboardWorkoutItem(
    displayName: 'Walking distance/km',
    workoutType: 'walking',
    color: '#0000FF',
    valueType: WorkoutValueType.distance,
  ),
  'running.duration': DashboardWorkoutItem(
    displayName: 'Running minutes',
    workoutType: 'running',
    color: '#0000FF',
    valueType: WorkoutValueType.duration,
  ),
  'running.calories': DashboardWorkoutItem(
    displayName: 'Running calories',
    workoutType: 'running',
    color: '#0000FF',
    valueType: WorkoutValueType.energy,
  ),
  'running.distance': DashboardWorkoutItem(
    displayName: 'Running distance/km',
    workoutType: 'running',
    color: '#0000FF',
    valueType: WorkoutValueType.distance,
  ),
  'functionalStrengthTraining.duration': DashboardWorkoutItem(
    displayName: 'Functional strength training minutes',
    workoutType: 'functionalStrengthTraining',
    color: '#0000FF',
    valueType: WorkoutValueType.duration,
  ),
  'functionalStrengthTraining.calories': DashboardWorkoutItem(
    displayName: 'Functional strength training calories',
    workoutType: 'functionalStrengthTraining',
    color: '#0000FF',
    valueType: WorkoutValueType.energy,
  ),
};

List<Observation> aggregateWorkoutDailySum(
  List<JournalEntity?> entities,
  DashboardWorkoutItem chartConfig,
) {
  Map<String, num> sumsByDay = {};

  for (JournalEntity? entity in entities) {
    entity?.maybeMap(
      workout: (WorkoutEntry workoutEntry) {
        WorkoutData data = workoutEntry.data;
        if (data.workoutType == chartConfig.workoutType) {
          String dayString = ymd(entity.meta.dateFrom);
          num n = sumsByDay[dayString] ?? 0;

          if (chartConfig.valueType == WorkoutValueType.distance &&
              data.distance != null) {
            sumsByDay[dayString] = n + data.distance!;
          }

          if (chartConfig.valueType == WorkoutValueType.energy &&
              data.energy != null) {
            sumsByDay[dayString] = n + data.energy!;
          }

          if (chartConfig.valueType == WorkoutValueType.duration) {
            num minutes = workoutEntry.meta.dateTo
                    .difference(workoutEntry.meta.dateFrom)
                    .inSeconds /
                60;
            sumsByDay[dayString] = n + minutes;
          }
        }
      },
      orElse: () {},
    );
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<Observation> aggregated = [];
  for (final dayString in sumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}
