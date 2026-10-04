/// Canonical journal health identifiers currently supported by goal agents.
abstract final class GoalHealthDataTypes {
  static const weight = 'HealthDataType.WEIGHT';
  static const bloodPressureSystolic = 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC';
  static const bloodPressureDiastolic =
      'HealthDataType.BLOOD_PRESSURE_DIASTOLIC';

  /// Daily step totals, written by the activity importer under its own
  /// cumulative storage type rather than a `HealthDataType.` name.
  static const steps = 'cumulative_step_count';

  /// Point-sample vitals: the value a card quotes is the LATEST reading, not
  /// the period aggregate. [steps] is deliberately absent — a step count is a
  /// daily total that only means something summed or averaged.
  static const Set<String> supported = {
    weight,
    bloodPressureSystolic,
    bloodPressureDiastolic,
  };

  static String criterionId(String dataType) => switch (dataType) {
    weight => 'health-weight',
    bloodPressureSystolic => 'health-blood-pressure-systolic',
    bloodPressureDiastolic => 'health-blood-pressure-diastolic',
    _ => throw ArgumentError.value(dataType, 'dataType'),
  };
}
