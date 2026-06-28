import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';

void main() {
  group('token round-trip', () {
    test(
      'a fixed selection serializes to (and parses back from) its variant',
      () {
        for (final variant in CelebrationVariant.values) {
          final selection = FixedSelection(variant);
          expect(selection.token, variant.name);
          expect(CelebrationSelection.fromToken(selection.token), selection);
        }
      },
    );

    test('random and combine use stable sentinel tokens', () {
      expect(
        CelebrationSelection.fromToken(CelebrationSelection.randomToken),
        const RandomSelection(),
      );
      expect(
        CelebrationSelection.fromToken(CelebrationSelection.combineToken),
        const CombineSelection(),
      );
    });

    test('fromToken is backward compatible with a bare variant name', () {
      // Values stored before surprise modes existed are plain variant names.
      expect(
        CelebrationSelection.fromToken('confetti'),
        const FixedSelection(CelebrationVariant.confetti),
      );
    });

    test('fromToken returns null for null / empty / unknown tokens', () {
      expect(CelebrationSelection.fromToken(null), isNull);
      expect(CelebrationSelection.fromToken(''), isNull);
      expect(CelebrationSelection.fromToken('not-a-variant'), isNull);
    });
  });

  group('resolve', () {
    test('a fixed selection always resolves to its variant', () {
      const selection = FixedSelection(CelebrationVariant.embers);
      for (final seed in const [0, 1, 7, 99]) {
        expect(
          selection.resolve(seed: seed),
          const ResolvedCelebration(CelebrationVariant.embers),
        );
      }
    });

    test('resolve is deterministic in the seed', () {
      const random = RandomSelection();
      expect(random.resolve(seed: 12), random.resolve(seed: 12));
      const combine = CombineSelection();
      expect(combine.resolve(seed: 5), combine.resolve(seed: 5));
    });

    test('random covers every variant across advancing seeds', () {
      const random = RandomSelection();
      final seen = <CelebrationVariant>{};
      for (var seed = 0; seed < CelebrationVariant.values.length; seed++) {
        seen.add(random.resolve(seed: seed).primary);
      }
      expect(seen, CelebrationVariant.values.toSet());
    });

    test('combine always yields a distinct, layered pair', () {
      const combine = CombineSelection();
      for (var seed = 0; seed < 40; seed++) {
        final resolved = combine.resolve(seed: seed);
        expect(resolved.isCombined, isTrue);
        expect(resolved.secondary, isNotNull);
        expect(
          resolved.secondary,
          isNot(resolved.primary),
          reason: 'seed $seed produced a same-variant pair',
        );
      }
    });
  });

  group('equality & hashCode', () {
    test('ResolvedCelebration is a value type (== and hashCode)', () {
      const a = ResolvedCelebration(
        CelebrationVariant.sparks,
        CelebrationVariant.embers,
      );
      const b = ResolvedCelebration(
        CelebrationVariant.sparks,
        CelebrationVariant.embers,
      );
      const single = ResolvedCelebration(CelebrationVariant.sparks);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(single));
      // Distinct values collapse to two entries in a hash set (a == b).
      // ignore: equal_elements_in_set, intentional — proves set dedup
      expect({a, b, single}.length, 2);
    });

    test('surprise selections are value types usable as set keys', () {
      expect(
        const RandomSelection().hashCode,
        const RandomSelection().hashCode,
      );
      expect(
        const CombineSelection().hashCode,
        const CombineSelection().hashCode,
      );
      expect(const RandomSelection(), isNot(const CombineSelection()));
      expect(
        <CelebrationSelection>{
          const RandomSelection(),
          // ignore: equal_elements_in_set, intentional — proves set dedup
          const RandomSelection(),
          const CombineSelection(),
        }.length,
        2,
      );
    });
  });

  group('nextCelebrationSeed', () {
    test('advances on every call so surprise modes re-roll', () {
      debugResetCelebrationSeed();
      final a = nextCelebrationSeed();
      final b = nextCelebrationSeed();
      final c = nextCelebrationSeed();
      expect(a, isNot(b));
      expect(b, isNot(c));
    });
  });
}
