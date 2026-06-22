import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';

void main() {
  group('CelebrationVariant', () {
    test('exposes exactly the five supported variants', () {
      expect(CelebrationVariant.values, [
        CelebrationVariant.sparks,
        CelebrationVariant.fireworks,
        CelebrationVariant.confetti,
        CelebrationVariant.embers,
        CelebrationVariant.bubbles,
      ]);
    });

    test('defaultVariant is sparks (the pre-existing look)', () {
      expect(CelebrationVariant.defaultVariant, CelebrationVariant.sparks);
    });

    group('fromStorage', () {
      test('round-trips every variant through its name', () {
        for (final variant in CelebrationVariant.values) {
          expect(CelebrationVariant.fromStorage(variant.name), variant);
        }
      });

      test('falls back to the default for null', () {
        expect(
          CelebrationVariant.fromStorage(null),
          CelebrationVariant.defaultVariant,
        );
      });

      test('falls back to the default for an empty string', () {
        expect(
          CelebrationVariant.fromStorage(''),
          CelebrationVariant.defaultVariant,
        );
      });

      test('falls back to the default for an unrecognised value', () {
        expect(
          CelebrationVariant.fromStorage('supernova'),
          CelebrationVariant.defaultVariant,
        );
      });

      test('is case-sensitive — a wrong case does not match', () {
        // `name` is lower-case; an upper-case persisted value should not match
        // and must fall back rather than throw.
        expect(
          CelebrationVariant.fromStorage('SPARKS'),
          CelebrationVariant.defaultVariant,
        );
      });
    });

    group('tryFromStorage', () {
      test('round-trips every variant through its name', () {
        for (final variant in CelebrationVariant.values) {
          expect(CelebrationVariant.tryFromStorage(variant.name), variant);
        }
      });

      test('returns null (not the default) for an absent value', () {
        // The distinction the per-content-type migration relies on: "never
        // stored" must be tellable from "stored as the default".
        expect(CelebrationVariant.tryFromStorage(null), isNull);
        expect(CelebrationVariant.tryFromStorage(''), isNull);
      });

      test('returns null for an unrecognised value', () {
        expect(CelebrationVariant.tryFromStorage('supernova'), isNull);
      });
    });

    group('durationScale', () {
      test('bubbles run slower than the base timing', () {
        expect(CelebrationVariant.bubbles.durationScale, greaterThan(1.0));
      });

      test('every other variant keeps the base timing', () {
        for (final variant in CelebrationVariant.values.where(
          (v) => v != CelebrationVariant.bubbles,
        )) {
          expect(
            variant.durationScale,
            1.0,
            reason: '${variant.name} should keep base timing',
          );
        }
      });
    });

    group('isWarm', () {
      test('only embers reads as warm', () {
        expect(CelebrationVariant.embers.isWarm, isTrue);
      });

      test('every other variant is not warm', () {
        for (final variant in CelebrationVariant.values.where(
          (v) => v != CelebrationVariant.embers,
        )) {
          expect(
            variant.isWarm,
            isFalse,
            reason: '${variant.name} should be cool',
          );
        }
      });
    });
  });
}
