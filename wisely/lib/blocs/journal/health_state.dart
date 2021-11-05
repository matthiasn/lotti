import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health/health.dart';

part 'health_state.freezed.dart';

@freezed
class HealthState with _$HealthState {
  factory HealthState() = _Initial;
}

List<HealthDataType> workoutTypes = [
  HealthDataType.EXERCISE_TIME,
  HealthDataType.WORKOUT,
];

List<HealthDataType> sleepTypes = [
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_AWAKE,
];

List<HealthDataType> bpTypes = [
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
];

List<HealthDataType> heartRateTypes = [
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
];

List<HealthDataType> bodyMeasurementTypes = [
  HealthDataType.WEIGHT,
  HealthDataType.BODY_FAT_PERCENTAGE,
];
