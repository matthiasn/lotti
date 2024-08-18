class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.now();

  void updateActivity() {
    _lastActivity = DateTime.now();
  }

  DateTime get lastActivity => _lastActivity;

  int get msSinceLastActivity =>
      _lastActivity.difference(DateTime.now()).inMilliseconds;
}
