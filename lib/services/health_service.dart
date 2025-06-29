import 'package:health/health.dart';

class HealthService {
  HealthService(this._health);

  final Health _health;

  Future<bool?> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) {
    return _health.requestAuthorization(types, permissions: permissions);
  }

  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime) {
    return _health.getTotalStepsInInterval(startTime, endTime);
  }

  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) {
    return _health.getHealthDataFromTypes(
      startTime: startTime,
      endTime: endTime,
      types: types,
    );
  }
}
