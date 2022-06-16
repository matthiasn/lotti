import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';

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
  'swimming.duration': DashboardWorkoutItem(
    displayName: 'Swimming minutes',
    workoutType: 'swimming',
    color: '#0000FF',
    valueType: WorkoutValueType.duration,
  ),
  'swimming.calories': DashboardWorkoutItem(
    displayName: 'Swimming calories',
    workoutType: 'swimming',
    color: '#0000FF',
    valueType: WorkoutValueType.energy,
  ),
  'swimming.distance': DashboardWorkoutItem(
    displayName: 'Swimming distance/km',
    workoutType: 'swimming',
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
