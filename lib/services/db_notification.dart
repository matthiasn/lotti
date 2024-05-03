import 'dart:async';

enum DatabaseType {
  journal,
  setting,
  sync,
  logging,
}

class UpdateNotifications {
  UpdateNotifications();

  final _updateStreamController = StreamController<DatabaseType>.broadcast();

  Stream<DatabaseType> get updateStream => _updateStreamController.stream;

  void notifyUpdate(DatabaseType databaseType) {
    _updateStreamController.add(databaseType);
  }
}
