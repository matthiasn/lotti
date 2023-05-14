import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'settings_db.g.dart';

const settingsDbFileName = 'settings.sqlite';

const String whisperModelKey = 'WHISPER_MODEL';

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

  Future<int> saveSettingsItem(String configKey, String value) async {
    final settingsItem = SettingsItem(
      configKey: configKey,
      value: value,
      updatedAt: DateTime.now(),
    );

    return into(settings).insertOnConflictUpdate(settingsItem);
  }

  Stream<List<SettingsItem>> watchSettingsItemByKey(String configKey) {
    return settingsItemByKey(configKey).watch();
  }

  Future<String?> itemByKey(String configKey) async {
    final existing = await watchSettingsItemByKey(configKey).first;

    if (existing.isNotEmpty) {
      return existing.first.value;
    } else {
      return null;
    }
  }
}

SettingsDb getSettingsDb() {
  return SettingsDb.connect(getDatabaseConnection(settingsDbFileName));
}
