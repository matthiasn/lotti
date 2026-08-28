import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Icon and naming for a signal row, shared by the card, the picker and the
/// completion sheet.
extension HabitSignalKindPresentation on HabitSignalKind {
  IconData get icon => switch (this) {
    HabitSignalKind.measurable => LottiIcons.measure,
    HabitSignalKind.health => LottiIcons.heartRate,
    HabitSignalKind.workout => LottiIcons.fitness,
  };
}

/// The health data types a habit rule can be evaluated against.
///
/// `healthTypes` also carries synthetic keys (`BLOOD_PRESSURE`,
/// `BODY_MASS_INDEX`) that exist only to dispatch combined dashboard charts;
/// no journal entry is ever stored under them, so a rule naming one could
/// never fire. Only the real `HealthDataType.*` and `cumulative_*` keys are
/// offered.
Iterable<String> get evaluableHealthDataTypes => healthTypes.keys.where(
  (key) => key.startsWith('HealthDataType.') || key.startsWith('cumulative_'),
);

/// The localized name of a health data type, falling back to the config's
/// English name for a type the catalog does not know.
String habitHealthTypeName(
  AppLocalizations messages,
  String dataType,
) => switch (dataType) {
  'HealthDataType.WEIGHT' => messages.habitHealthWeight,
  'HealthDataType.BODY_FAT_PERCENTAGE' => messages.habitHealthBodyFat,
  'HealthDataType.BODY_MASS_INDEX' => messages.habitHealthBodyMassIndex,
  'HealthDataType.RESTING_HEART_RATE' => messages.habitHealthRestingHeartRate,
  'HealthDataType.WALKING_HEART_RATE' => messages.habitHealthWalkingHeartRate,
  'HealthDataType.HEART_RATE_VARIABILITY_SDNN' =>
    messages.habitHealthHeartRateVariability,
  'HealthDataType.BLOOD_PRESSURE_SYSTOLIC' =>
    messages.habitHealthBloodPressureSystolic,
  'HealthDataType.BLOOD_PRESSURE_DIASTOLIC' =>
    messages.habitHealthBloodPressureDiastolic,
  'cumulative_step_count' => messages.habitHealthSteps,
  'cumulative_distance' => messages.habitHealthDistance,
  'cumulative_flights_climbed' => messages.habitHealthFlightsClimbed,
  'HealthDataType.SLEEP_ASLEEP' => messages.habitHealthSleepAsleep,
  'HealthDataType.SLEEP_LIGHT' => messages.habitHealthSleepLight,
  'HealthDataType.SLEEP_DEEP' => messages.habitHealthSleepDeep,
  'HealthDataType.SLEEP_REM' => messages.habitHealthSleepRem,
  'HealthDataType.SLEEP_IN_BED' => messages.habitHealthSleepInBed,
  'HealthDataType.SLEEP_AWAKE' => messages.habitHealthSleepAwake,
  _ => healthTypes[dataType]?.displayName ?? dataType,
};

/// The human name of a signal: the measurable's display name, the localized
/// health name, or the raw workout type.
String habitSignalDisplayName(
  AppLocalizations messages,
  HabitSignalForm signal,
  Map<String, MeasurableDataType> measurablesById,
) => switch (signal.kind) {
  HabitSignalKind.measurable =>
    signal.title ?? measurablesById[signal.id]?.displayName ?? signal.id,
  HabitSignalKind.health =>
    signal.title ?? habitHealthTypeName(messages, signal.id),
  HabitSignalKind.workout => signal.title ?? signal.id,
};

/// The unit label for a workout dimension.
String habitWorkoutUnit(AppLocalizations messages, WorkoutValueType type) =>
    switch (type) {
      WorkoutValueType.duration => messages.habitUnitMinutes,
      WorkoutValueType.distance => messages.habitUnitKilometres,
      WorkoutValueType.energy => messages.habitUnitKilocalories,
    };

/// The picker row's second line for a measurable: its unit, or for a choice
/// measurable its active choices — "Clear · Pale · Dark" — since those are
/// what a rule on it would be about. `null` when there is nothing to say.
String? habitMeasurableSubtitle(MeasurableDataType measurable) {
  if (measurable.isChoice) {
    final titles = measurable.activeChoices.map((choice) => choice.title);
    return titles.isEmpty ? null : titles.join(' · ');
  }
  return measurable.unitName.isEmpty ? null : measurable.unitName;
}

/// The unit a threshold is entered in. A choice measurable has none — its
/// unit field is a leftover from before it was switched — so it reads as
/// empty rather than labelling a threshold that does not exist.
String habitSignalUnit(
  AppLocalizations messages,
  HabitSignalForm signal,
  Map<String, MeasurableDataType> measurablesById,
) => switch (signal.kind) {
  HabitSignalKind.measurable => switch (measurablesById[signal.id]) {
    null => '',
    final measurable => measurable.isChoice ? '' : measurable.unitName,
  },
  HabitSignalKind.health => healthTypes[signal.id]?.unit ?? '',
  HabitSignalKind.workout => switch (signal.workoutValueType) {
    null => '',
    final type => habitWorkoutUnit(messages, type),
  },
};
