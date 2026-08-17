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

  /// Storage types the activity importer writes, mirroring
  /// `HealthImport.activityStorageTypes`. Kept here so
  /// [isPlatformHealthImported] can classify a goal's data type without the
  /// model layer depending on the importer.
  static const Set<String> _activityStorageTypes = {
    steps,
    'cumulative_flights_climbed',
    'cumulative_distance',
  };

  /// Whether [dataType] comes from the platform health store (Apple Health /
  /// Health Connect) rather than from something the user writes in Lotti.
  ///
  /// This is the set worth re-importing when a goal surface opens: a goal
  /// reading its own journal entries is current by construction, while one
  /// reading health samples is only as fresh as the last import.
  static bool isPlatformHealthImported(String dataType) =>
      dataType.startsWith('HealthDataType.') ||
      _activityStorageTypes.contains(dataType);

  static String criterionId(String dataType) => switch (dataType) {
    weight => 'health-weight',
    bloodPressureSystolic => 'health-blood-pressure-systolic',
    bloodPressureDiastolic => 'health-blood-pressure-diastolic',
    _ => throw ArgumentError.value(dataType, 'dataType'),
  };
}
