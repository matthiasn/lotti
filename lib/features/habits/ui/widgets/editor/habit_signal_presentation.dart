import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';

/// Icon and naming for a signal row, shared by the card and the picker.
extension HabitSignalKindPresentation on HabitSignalKind {
  IconData get icon => switch (this) {
    HabitSignalKind.measurable => LottiIcons.measure,
    HabitSignalKind.health => LottiIcons.heartRate,
    HabitSignalKind.workout => LottiIcons.fitness,
  };
}

/// The human name of a signal: the measurable's display name, the health
/// config's name, or the raw workout type.
String habitSignalDisplayName(
  HabitSignalForm signal,
  Map<String, MeasurableDataType> measurablesById,
) => switch (signal.kind) {
  HabitSignalKind.measurable =>
    signal.title ?? measurablesById[signal.id]?.displayName ?? signal.id,
  HabitSignalKind.health =>
    signal.title ?? healthTypes[signal.id]?.displayName ?? signal.id,
  HabitSignalKind.workout => signal.title ?? signal.id,
};

/// The unit a threshold is entered in.
String habitSignalUnit(
  HabitSignalForm signal,
  Map<String, MeasurableDataType> measurablesById,
) => switch (signal.kind) {
  HabitSignalKind.measurable => measurablesById[signal.id]?.unitName ?? '',
  HabitSignalKind.health => '',
  HabitSignalKind.workout => switch (signal.workoutValueType) {
    WorkoutValueType.duration => 'min',
    WorkoutValueType.distance => 'km',
    WorkoutValueType.energy => 'kcal',
    null => '',
  },
};
