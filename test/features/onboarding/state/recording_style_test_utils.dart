import 'package:lotti/services/app_prefs_service.dart';

/// In-memory [AppPrefs] backed by [store], so `recordingStyleProvider` (and
/// anything reading through `recordingStyleAppPrefsProvider`) can be
/// exercised without SharedPreferences. Shared across the onboarding/settings
/// recording-style tests that all need the same fake.
AppPrefs fakeRecordingStylePrefs(Map<String, String> store) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (key) async => store[key],
  setString: ({required key, required value}) async {
    store[key] = value;
    return true;
  },
);
