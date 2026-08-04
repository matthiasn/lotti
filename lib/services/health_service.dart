import 'package:health/health.dart';

/// Thin seam over the `health` plugin's [Health] facade.
///
/// Everything the app reads from Apple Health / Health Connect goes through
/// here, which keeps [Health] — a concrete class wrapping a `MethodChannel` —
/// out of the import logic and mockable in tests.
///
/// The seam also owns the plugin's one initialization requirement: [Health]
/// documents that [Health.configure] "must be called before using the
/// plugin", and it is what populates the plugin's cached device id. Some read
/// paths recover a missing device id on their own, but not all of them —
/// notably the Android BMI computation dereferences it unconditionally — so a
/// plugin that was never configured fails there rather than at a point that
/// names the cause. Rather than making every caller remember the handshake,
/// each method here awaits [_ensureConfigured] first.
class HealthService {
  HealthService(this._health);

  final Health _health;

  /// The in-flight or completed [Health.configure] call, so the handshake runs
  /// once per service rather than once per request. Reset to `null` on failure
  /// so a transient error (e.g. a device-info channel not ready yet) does not
  /// poison every later call with a cached rejected future.
  Future<void>? _configuration;

  Future<void> _ensureConfigured() async {
    final pending = _configuration ??= _health.configure();
    try {
      await pending;
    } catch (_) {
      _configuration = null;
      rethrow;
    }
  }

  Future<bool?> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    await _ensureConfigured();
    return _health.requestAuthorization(types, permissions: permissions);
  }

  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime,
  ) async {
    await _ensureConfigured();
    return _health.getTotalStepsInInterval(startTime, endTime);
  }

  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) async {
    await _ensureConfigured();
    return _health.getHealthDataFromTypes(
      startTime: startTime,
      endTime: endTime,
      types: types,
    );
  }
}
