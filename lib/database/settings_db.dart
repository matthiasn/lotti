import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'settings_db.g.dart';

const settingsDbFileName = 'settings.sqlite';

@DriftDatabase(include: {'settings_db.drift'})
class SettingsDb extends _$SettingsDb {
  SettingsDb({
    this.inMemoryDatabase = false,
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
          openDbConnection(
            settingsDbFileName,
            inMemoryDatabase: inMemoryDatabase,
            background: background,
            documentsDirectoryProvider: documentsDirectoryProvider,
            tempDirectoryProvider: tempDirectoryProvider,
          ),
        );

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

  Future<void> removeSettingsItem(String configKey) async {
    final existing = await settingsItemByKey(configKey).get();
    if (existing.isNotEmpty) {
      await delete(settings).delete(existing.first);
    }
  }

  Future<String?> itemByKey(String configKey) async {
    final existing = await settingsItemByKey(configKey).get();
    if (existing.isNotEmpty) {
      return existing.first.value;
    }
    return null;
  }
}
