class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  void updateActivity() => _lastActivity = DateTime.now();

  int get msSinceLastActivity =>
      DateTime.now().difference(_lastActivity).inMilliseconds;
}
