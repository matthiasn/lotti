import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'settings_db.g.dart';

const settingsDbFileName = 'settings.sqlite';

@DriftDatabase(include: {'settings_db.drift'})
class SettingsDb extends _$SettingsDb {
  SettingsDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            settingsDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  SettingsDb.connect(super.connection) : super.connect();

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 1;

  Future<int> saveSettingsItem(SettingsItem settingsItem) async {
    return into(settings).insertOnConflictUpdate(settingsItem);
  }

  Stream<List<SettingsItem>> watchSettingsItemByKey(String configKey) {
    return settingsItemByKey(configKey).watch();
  }
}

SettingsDb getSettingsDb() {
  return SettingsDb.connect(getDatabaseConnection(settingsDbFileName));
}
