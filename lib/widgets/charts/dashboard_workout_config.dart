import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';

Map<String, DashboardWorkoutItem> workoutTypes = {
  'walking.duration': const DashboardWorkoutItem(
    displayName: 'Walking (time)',
    workoutType: 'walking',
    color: '#82E6CE',
    valueType: WorkoutValueType.duration,
  ),
  'walking.energy': const DashboardWorkoutItem(
    displayName: 'Walking (calories)',
    workoutType: 'walking',
    color: '#82E6CE',
    valueType: WorkoutValueType.energy,
  ),
  'walking.distance': const DashboardWorkoutItem(
    displayName: 'Walking distance (m)',
    workoutType: 'walking',
    color: '#82E6CE',
    valueType: WorkoutValueType.distance,
  ),
  'running.duration': const DashboardWorkoutItem(
    displayName: 'Running (time)',
    workoutType: 'running',
    color: '#82E6CE',
    valueType: WorkoutValueType.duration,
  ),
  'running.energy': const DashboardWorkoutItem(
    displayName: 'Running (calories)',
    workoutType: 'running',
    color: '#82E6CE',
    valueType: WorkoutValueType.energy,
  ),
  'running.distance': const DashboardWorkoutItem(
    displayName: 'Running distance (m)',
    workoutType: 'running',
    color: '#82E6CE',
    valueType: WorkoutValueType.distance,
  ),
  'swimming.duration': const DashboardWorkoutItem(
    displayName: 'Swimming (time)',
    workoutType: 'swimming',
    color: '#82E6CE',
    valueType: WorkoutValueType.duration,
  ),
  'swimming.energy': const DashboardWorkoutItem(
    displayName: 'Swimming (calories)',
    workoutType: 'swimming',
    color: '#82E6CE',
    valueType: WorkoutValueType.energy,
  ),
  'swimming.distance': const DashboardWorkoutItem(
    displayName: 'Swimming distance (m)',
    workoutType: 'swimming',
    color: '#82E6CE',
    valueType: WorkoutValueType.distance,
  ),
  'functionalStrengthTraining.duration': const DashboardWorkoutItem(
    displayName: 'Strength training (time)',
    workoutType: 'functionalStrengthTraining',
    color: '#82E6CE',
    valueType: WorkoutValueType.duration,
  ),
  'functionalStrengthTraining.energy': const DashboardWorkoutItem(
    displayName: 'Strength training (calories)',
    workoutType: 'functionalStrengthTraining',
    color: '#82E6CE',
    valueType: WorkoutValueType.energy,
  ),
};
