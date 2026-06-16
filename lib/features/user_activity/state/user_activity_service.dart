import 'dart:async';

import 'package:clock/clock.dart';

/// Records "the user just did something" timestamps and broadcasts them.
///
/// Deliberately a timestamp emitter, not an analytics layer: UI surfaces call
/// [updateActivity] on scroll/interaction, and `UserActivityGate` turns the
/// resulting [activityStream] into an idle/busy gate. [lastActivity] is seeded
/// at epoch 0 so a freshly constructed service reads as "idle for a very long
/// time" until the first interaction. Uses `clock.now()` so tests can drive it.
class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  final StreamController<DateTime> _activityController =
      StreamController<DateTime>.broadcast();

  /// Records `clock.now()` as the latest [lastActivity] and broadcasts it on
  /// [activityStream]. Called from UI surfaces on each scroll/interaction.
  /// No-ops the broadcast after [dispose] (the controller is closed), but the
  /// timestamp is still updated.
  void updateActivity() {
    _lastActivity = clock.now();
    if (!_activityController.isClosed) {
      _activityController.add(_lastActivity);
    }
  }

  DateTime get lastActivity => _lastActivity;

  Stream<DateTime> get activityStream => _activityController.stream;

  Future<void> dispose() async {
    await _activityController.close();
  }
}
