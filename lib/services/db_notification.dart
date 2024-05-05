import 'dart:async';

enum DatabaseType {
  journal,
  entity,
  setting,
  sync,
  logging,
}

class UpdateNotifications {
  UpdateNotifications();

  final _updateStreamController =
      StreamController<({DatabaseType type, String id})>.broadcast();

  Stream<({DatabaseType type, String id})> get updateStream =>
      _updateStreamController.stream;

  void notifyUpdate(DatabaseType databaseType, String id) {
    _updateStreamController.add((type: databaseType, id: id));
  }
}
