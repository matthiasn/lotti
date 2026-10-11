import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/utils/daily_os_preferences_keys.dart';
import 'package:lotti/utils/theming_settings_keys.dart';

/// Further stamped records "Send settings" re-sends, owned by features above
/// sync — the GitHub account. The composition root binds them; by default
/// there are none.
final preferenceResendExtrasProvider =
    Provider<Future<List<SyncMessage>> Function()>(
      (ref) =>
          () async => const <SyncMessage>[],
      name: 'preferenceResendExtrasProvider',
    );

/// The messages that re-send this device's synced preferences — the theme,
/// the Daily OS greeting name and every config flag — each with the stamp
/// its stored value holds.
///
/// Each is sent once per change and kept by its receiver under
/// last-writer-wins on that stamp, so a lost message used to stay lost until
/// the setting changed again. A resend is safe: a peer that holds a newer
/// value keeps it. A value with no stamp is left out, since stamp 0 would
/// rank it against a peer's value by content rather than by time.
Future<List<SyncMessage>> preferenceResendMessages({
  required JournalDb journalDb,
  required SettingsDb settingsDb,
}) async {
  final settings = await settingsDb.itemsByKeys(const [
    lightSchemeNameKey,
    darkSchemeNameKey,
    themeModeKey,
    themePrefsUpdatedAtKey,
    dailyOsUserNameSettingsKey,
    dailyOsUserNameUpdatedAtSettingsKey,
  ]);
  final light = settings[lightSchemeNameKey];
  final dark = settings[darkSchemeNameKey];
  final mode = settings[themeModeKey];
  final themeStamp = int.tryParse(settings[themePrefsUpdatedAtKey] ?? '');
  final userName = settings[dailyOsUserNameSettingsKey];
  final nameStamp = int.tryParse(
    settings[dailyOsUserNameUpdatedAtSettingsKey] ?? '',
  );
  return [
    if (light != null && dark != null && mode != null && themeStamp != null)
      SyncMessage.themingSelection(
        lightThemeName: light,
        darkThemeName: dark,
        themeMode: mode,
        updatedAt: themeStamp,
        status: SyncEntryStatus.update,
      ),
    if (userName != null && nameStamp != null)
      SyncMessage.dailyOsUserName(
        userName: userName,
        updatedAt: nameStamp,
        status: SyncEntryStatus.update,
      ),
    for (final (:flag, :updatedAt) in await journalDb.stampedConfigFlags())
      SyncMessage.configFlag(
        name: flag.name,
        description: flag.description,
        status: flag.status,
        updatedAt: updatedAt,
      ),
  ];
}
