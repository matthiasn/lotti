import 'dart:async';

class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  final StreamController<DateTime> _activityController =
      StreamController<DateTime>.broadcast();

  void updateActivity() {
    _lastActivity = DateTime.now();
    if (!_activityController.isClosed) {
      _activityController.add(_lastActivity);
    }
  }

  int get msSinceLastActivity =>
      DateTime.now().difference(_lastActivity).inMilliseconds;

  DateTime get lastActivity => _lastActivity;

  Stream<DateTime> get activityStream => _activityController.stream;

  Future<void> dispose() async {
    await _activityController.close();
  }
}
