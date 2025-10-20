import 'package:lotti/utils/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over simple key/value app preferences to enable mocking in tests.
class AppPrefs {
  const AppPrefs({required this.getBool, required this.setBool});

  final Future<bool?> Function(String key) getBool;
  final Future<bool> Function({required String key, required bool value})
      setBool;
}

AppPrefs makeSharedPrefsService() => AppPrefs(
      getBool: (String key) async {
        if (isTestEnv) return true; // avoid UI hints in tests by default
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(key);
      },
      setBool: ({required String key, required bool value}) async {
        if (isTestEnv) return true;
        final prefs = await SharedPreferences.getInstance();
        return prefs.setBool(key, value);
      },
    );

/// Clears preferences whose keys start with [prefix]. Returns the number of
/// removed keys. Intended for ephemeral UI hints (e.g., keys prefixed with
/// 'seen_').
Future<int> clearPrefsByPrefix(String prefix) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
  for (final k in keys) {
    await prefs.remove(k);
  }
  return keys.length;
}
