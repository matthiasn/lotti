import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('clearPrefsByPrefix', () {
    test('removes only keys with the given prefix and returns count', () async {
      SharedPreferences.setMockInitialValues({
        'seen_checklist_share_hint': true,
        'seen_intro_modal': true,
        'other_flag': true,
      });

      final removed = await clearPrefsByPrefix('seen_');
      expect(removed, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('seen_checklist_share_hint'), isNull);
      expect(prefs.getBool('seen_intro_modal'), isNull);
      expect(prefs.getBool('other_flag'), isTrue);
    });
  });

  group('makeSharedPrefsService (test env behavior)', () {
    test('getBool returns true in test env by default', () async {
      final prefs = makeSharedPrefsService();
      final value = await prefs.getBool('any_key');
      expect(value, isTrue);
    });

    test('setBool returns true in test env', () async {
      final prefs = makeSharedPrefsService();
      final ok = await prefs.setBool(key: 'k', value: false);
      expect(ok, isTrue);
    });
  });
}
