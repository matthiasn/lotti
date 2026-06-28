import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';

void main() {
  group('celebrationSliderSpecs', () {
    test('every variant exposes the shared knobs plus its specifics', () {
      for (final variant in CelebrationVariant.values) {
        final ids = celebrationSliderSpecs(variant).map((s) => s.id).toList();
        expect(ids, contains('count'), reason: variant.name);
        expect(ids, contains('size'), reason: variant.name);
        expect(ids, contains('reach'), reason: variant.name);
        // 4 shared (3 for confetti, which drops clearCenter) + 4 specific.
        expect(ids.length, greaterThanOrEqualTo(7), reason: variant.name);
        // No duplicate knob ids within a variant.
        expect(ids.toSet().length, ids.length, reason: variant.name);
      }
    });

    test('confetti drops the cleared-centre knob its painter ignores', () {
      final ids = celebrationSliderSpecs(
        CelebrationVariant.confetti,
      ).map((s) => s.id);
      expect(ids, isNot(contains('clearCenter')));
    });

    test('every default sits inside its own slider range', () {
      for (final variant in CelebrationVariant.values) {
        for (final spec in celebrationSliderSpecs(variant)) {
          expect(
            spec.defaultValue,
            inInclusiveRange(spec.min, spec.max),
            reason: '${variant.name}.${spec.id}',
          );
        }
      }
    });
  });

  group('defaultsFor', () {
    test('reproduces the legacy hard-coded physics constants', () {
      final sparks = CelebrationParams.defaultsFor(CelebrationVariant.sparks);
      expect(sparks.v('gravity'), 0.16);
      expect(sparks.v('trail'), 0.2);

      final fireworks = CelebrationParams.defaultsFor(
        CelebrationVariant.fireworks,
      );
      expect(fireworks.v('launch'), 0.28);
      expect(fireworks.v('twinkle'), 8);

      expect(
        CelebrationParams.defaultsFor(CelebrationVariant.confetti).v('spread'),
        1.3,
      );
      expect(
        CelebrationParams.defaultsFor(CelebrationVariant.embers).v('fanSpread'),
        1.4,
      );
      expect(
        CelebrationParams.defaultsFor(CelebrationVariant.bubbles).v('pop'),
        0.9,
      );
    });

    test('is not flagged as customized and equals itself', () {
      final a = CelebrationParams.defaultsFor(CelebrationVariant.sparks);
      final b = CelebrationParams.defaultsFor(CelebrationVariant.sparks);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.isCustomized, isFalse);
    });
  });

  group('typed getters', () {
    test('count rounds to a whole number of particles', () {
      final p = CelebrationParams.defaultsFor(
        CelebrationVariant.sparks,
      ).withValue('count', 23.6);
      expect(p.count, 24);
    });

    test('clearCenter falls back to 0 for a variant that omits it', () {
      expect(
        CelebrationParams.defaultsFor(CelebrationVariant.confetti).clearCenter,
        0,
      );
    });
  });

  group('v', () {
    test('falls back to the spec default for a knob absent from the map', () {
      // An older persisted blob can omit a knob added since it was written;
      // v() must resolve it to the spec default rather than throwing.
      const partial = CelebrationParams(
        variant: CelebrationVariant.sparks,
        values: <String, double>{},
      );
      expect(partial.v('gravity'), 0.16);
      expect(partial.v('count'), 40);
    });

    test('throws ArgumentError for an id no spec defines', () {
      final p = CelebrationParams.defaultsFor(CelebrationVariant.sparks);
      expect(() => p.v('not-a-knob'), throwsArgumentError);
    });
  });

  group('withValue', () {
    test('returns a customized copy and leaves the source untouched', () {
      final base = CelebrationParams.defaultsFor(CelebrationVariant.sparks);
      final tuned = base.withValue('gravity', 0.4);
      expect(tuned.v('gravity'), 0.4);
      expect(tuned.isCustomized, isTrue);
      // The original is unchanged (the value map was copied, not mutated).
      expect(base.v('gravity'), 0.16);
      expect(base.isCustomized, isFalse);
      expect(base == tuned, isFalse);
    });
  });

  group('JSON round-trip', () {
    test('encode → tryDecode preserves a tuned params set', () {
      final tuned = CelebrationParams.defaultsFor(
        CelebrationVariant.bubbles,
      ).withValue('count', 12).withValue('swell', 2.2);
      final restored = CelebrationParams.tryDecode(tuned.encode());
      expect(restored, tuned);
    });

    test('fromJson clamps out-of-range values into the slider range', () {
      final json = {
        'variant': 'sparks',
        'values': {'gravity': 99.0, 'count': -5.0},
      };
      final decoded = CelebrationParams.fromJson(json)!;
      final gravitySpec = celebrationSliderSpecs(
        CelebrationVariant.sparks,
      ).firstWhere((s) => s.id == 'gravity');
      expect(decoded.v('gravity'), gravitySpec.max);
      // count is clamped to its min, not left negative.
      expect(decoded.count, greaterThan(0));
    });

    test('fromJson fills a missing knob from the spec default', () {
      // An older blob written before "trail" existed: it must not throw and the
      // missing knob takes its default.
      final decoded = CelebrationParams.fromJson({
        'variant': 'sparks',
        'values': {'gravity': 0.3},
      })!;
      expect(decoded.v('trail'), 0.2);
    });

    test('tryDecode tolerates null / empty / malformed input', () {
      expect(CelebrationParams.tryDecode(null), isNull);
      expect(CelebrationParams.tryDecode(''), isNull);
      expect(CelebrationParams.tryDecode('not json'), isNull);
      expect(CelebrationParams.tryDecode('[1,2,3]'), isNull);
      expect(CelebrationParams.tryDecode('{"variant":"nope"}'), isNull);
    });
  });
}
