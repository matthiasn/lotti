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
  // Settings are read repeatedly on hot UI and sync paths. Cache per-process
  // lookups so repeated reads do not serialize through settings.sqlite.
  final Map<String, String?> _cache = <String, String?>{};

  @override
  int get schemaVersion => 1;

  Future<int> saveSettingsItem(String configKey, String value) async {
    final settingsItem = SettingsItem(
      configKey: configKey,
      value: value,
      updatedAt: DateTime.now(),
    );

    final result = await into(settings).insertOnConflictUpdate(settingsItem);
    _cache[configKey] = value;
    return result;
  }

  Future<void> removeSettingsItem(String configKey) async {
    await (delete(settings)..where((t) => t.configKey.equals(configKey))).go();
    _cache.remove(configKey);
  }

  Future<String?> itemByKey(String configKey) async {
    if (_cache.containsKey(configKey)) {
      return _cache[configKey];
    }

    final existing = await settingsItemByKey(configKey).getSingleOrNull();
    final value = existing?.value;
    _cache[configKey] = value;
    return value;
  }
}
