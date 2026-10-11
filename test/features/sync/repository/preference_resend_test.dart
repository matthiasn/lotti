import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/repository/preference_resend.dart';
import 'package:lotti/utils/daily_os_preferences_keys.dart';
import 'package:lotti/utils/theming_settings_keys.dart';

void main() {
  late JournalDb journalDb;
  late SettingsDb settingsDb;

  setUp(() {
    journalDb = JournalDb(inMemoryDatabase: true);
    settingsDb = SettingsDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await journalDb.close();
    await settingsDb.close();
  });

  Future<List<SyncMessage>> messages() => preferenceResendMessages(
    journalDb: journalDb,
    settingsDb: settingsDb,
  );

  test('re-sends the theme, the greeting name and each versioned flag with '
      'the stamp it holds', () async {
    await settingsDb.saveSettingsItem(lightSchemeNameKey, 'Indigo');
    await settingsDb.saveSettingsItem(darkSchemeNameKey, 'Shark');
    await settingsDb.saveSettingsItem(themeModeKey, 'dark');
    await settingsDb.saveSettingsItem(themePrefsUpdatedAtKey, '1700');
    await settingsDb.saveSettingsItem(dailyOsUserNameSettingsKey, 'Pingu');
    await settingsDb.saveSettingsItem(
      dailyOsUserNameUpdatedAtSettingsKey,
      '1800',
    );
    await journalDb.applyConfigFlagVersion(
      const ConfigFlag(name: 'private', description: 'Private?', status: true),
      updatedAt: 1900,
    );

    expect(await messages(), [
      const SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: 1700,
        status: SyncEntryStatus.update,
      ),
      const SyncMessage.dailyOsUserName(
        userName: 'Pingu',
        updatedAt: 1800,
        status: SyncEntryStatus.update,
      ),
      const SyncMessage.configFlag(
        name: 'private',
        description: 'Private?',
        status: true,
        updatedAt: 1900,
      ),
    ]);
  });

  test('leaves out a value with no stamp, or with part of it missing, so a '
      'resend never competes without its time', () async {
    await settingsDb.saveSettingsItem(lightSchemeNameKey, 'Indigo');
    await settingsDb.saveSettingsItem(darkSchemeNameKey, 'Shark');
    await settingsDb.saveSettingsItem(themeModeKey, 'dark');
    await settingsDb.saveSettingsItem(dailyOsUserNameSettingsKey, 'Pingu');
    await settingsDb.saveSettingsItem(
      dailyOsUserNameUpdatedAtSettingsKey,
      'not a number',
    );

    expect(await messages(), isEmpty);

    await settingsDb.saveSettingsItem(themePrefsUpdatedAtKey, '1700');
    await settingsDb.removeSettingsItem(themeModeKey);
    expect(await messages(), isEmpty);
  });
}
