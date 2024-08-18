import 'package:flutter/foundation.dart';

class UserActivityService {
  UserActivityService();

  DateTime _lastActivity = DateTime.now();
  int _updateCount = 0;

  void updateActivity() {
    _lastActivity = DateTime.now();
    _updateCount++;
    if (_updateCount % 100 == 0) {
      debugPrint('User activity updated $_updateCount times');
    }
  }

  DateTime get lastActivity => _lastActivity;
}
