import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/services/app_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A generated preferences key: a numeric id plus whether it should live under
/// the prefix-under-test. Non-matching keys are built from a disjoint namespace
/// so a generated "other" key can never accidentally start with the prefix.
class _GeneratedKey {
  const _GeneratedKey({required this.id, required this.matches});

  final int id;
  final bool matches;

  /// `seen_<id>` for matching keys, `other_<id>` for non-matching ones. The two
  /// namespaces are disjoint, so `matches` is the single source of truth for
  /// whether the key starts with the `seen_` prefix.
  String get key => matches ? 'seen_$id' : 'other_$id';
}

extension _AnyGeneratedKey on glados.Any {
  glados.Generator<_GeneratedKey> get prefKey =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 40),
        glados.AnyUtils(this).choose([false, true]),
        (int id, bool matches) => _GeneratedKey(id: id, matches: matches),
      );

  glados.Generator<List<_GeneratedKey>> get prefKeys =>
      glados.ListAnys(this).listWithLengthInRange(0, 25, prefKey);
}

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

    glados.Glados(
      glados.any.prefKeys,
      // The input space (id range x matches flag x list length) is small and
      // fully exercised well under the default run count; keep it bounded.
      glados.ExploreConfig(numRuns: 120),
    ).test('removes exactly the prefixed keys, preserving the rest', (
      generatedKeys,
    ) async {
      // Collapse duplicate keys: SharedPreferences is a map, so two generated
      // entries with the same key are a single stored key. `matches` is stable
      // per key because the namespace ("seen_"/"other_") is encoded in the key.
      final stored = <String, bool>{
        for (final g in generatedKeys) g.key: true,
      };
      // Independent expectation derived from the generator's `matches` flag,
      // not from re-running `startsWith` (the predicate under test).
      final expectedRemoved = generatedKeys
          .where((g) => g.matches)
          .map((g) => g.key)
          .toSet();
      final expectedKept = generatedKeys
          .where((g) => !g.matches)
          .map((g) => g.key)
          .toSet();

      SharedPreferences.setMockInitialValues(stored);

      final removed = await clearPrefsByPrefix('seen_');
      expect(removed, expectedRemoved.length);

      final prefs = await SharedPreferences.getInstance();
      for (final key in expectedRemoved) {
        expect(
          prefs.containsKey(key),
          isFalse,
          reason: 'prefixed key "$key" should have been removed',
        );
      }
      for (final key in expectedKept) {
        expect(
          prefs.containsKey(key),
          isTrue,
          reason: 'non-prefixed key "$key" must be preserved',
        );
      }
    }, tags: 'glados');
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
