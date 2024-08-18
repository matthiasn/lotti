class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  void updateActivity() {
    _lastActivity = DateTime.now();
  }

  DateTime get lastActivity => _lastActivity;

  int get msSinceLastActivity =>
      DateTime.now().difference(_lastActivity).inMilliseconds;
}
