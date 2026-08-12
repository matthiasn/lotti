/// Canonical journal health identifiers currently supported by goal agents.
abstract final class GoalHealthDataTypes {
  static const weight = 'HealthDataType.WEIGHT';
  static const bloodPressureSystolic = 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC';
  static const bloodPressureDiastolic =
      'HealthDataType.BLOOD_PRESSURE_DIASTOLIC';

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
