import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/check_arb_parity.dart';

void main() {
  group('arbMessageKeys', () {
    test('keeps messages and drops the @ metadata entries', () {
      expect(
        arbMessageKeys('''
{
  "@@locale": "en",
  "greeting": "Hello {name}",
  "@greeting": {"placeholders": {"name": {}}},
  "farewell": "Bye"
}
'''),
        {'greeting', 'farewell'},
      );
    });
  });

  group('arbParityProblems', () {
    const template = {'a', 'b', 'c'};

    test('a catalog holding exactly the template keys passes', () {
      expect(
        arbParityProblems({
          'app_en.arb': template,
          'app_de.arb': {'c', 'b', 'a'},
        }),
        isEmpty,
      );
    });

    test('reports missing and orphaned keys, sorted, per catalog', () {
      expect(
        arbParityProblems({
          'app_en.arb': template,
          'app_sv.arb': {'b', 'zombie', 'ghost'},
          'app_da.arb': {'a', 'b'},
        }),
        [
          (catalog: 'app_da.arb', key: 'c', drift: ArbDrift.missing),
          (catalog: 'app_sv.arb', key: 'a', drift: ArbDrift.missing),
          (catalog: 'app_sv.arb', key: 'c', drift: ArbDrift.missing),
          (catalog: 'app_sv.arb', key: 'ghost', drift: ArbDrift.orphaned),
          (catalog: 'app_sv.arb', key: 'zombie', drift: ArbDrift.orphaned),
        ],
      );
    });

    test('a regional catalog may be partial but never hold orphans', () {
      // app_en_GB only overrides what British English spells differently and
      // inherits the rest from app_en.
      expect(
        arbParityProblems({
          'app_en.arb': template,
          'app_en_GB.arb': {'b', 'gone'},
        }),
        [(catalog: 'app_en_GB.arb', key: 'gone', drift: ArbDrift.orphaned)],
      );
    });

    test('a region without its base language must be complete', () {
      // Nothing to inherit from: pt_BR alone would fall back to English.
      expect(
        arbParityProblems({
          'app_en.arb': template,
          'app_pt_BR.arb': {'a'},
        }),
        [
          (catalog: 'app_pt_BR.arb', key: 'b', drift: ArbDrift.missing),
          (catalog: 'app_pt_BR.arb', key: 'c', drift: ArbDrift.missing),
        ],
      );
    });

    test('refuses to run without the template', () {
      expect(
        () => arbParityProblems({
          'app_de.arb': {'a'},
        }),
        throwsArgumentError,
      );
    });
  });
}
