import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';

double _luminance(CompanionSkinTone t) => t.skin.computeLuminance();

void main() {
  test('ten hairstyles, the bun first, as the pitch videos draw her', () {
    expect(CompanionHairStyle.values, hasLength(10));
    expect(CompanionHairStyle.values.first, CompanionHairStyle.bun);
  });

  test(
    'new styles come after the ones already stored, keeping their order',
    () {
      expect(CompanionHairStyle.values.skip(5), [
        CompanionHairStyle.short,
        CompanionHairStyle.balding,
        CompanionHairStyle.long,
        CompanionHairStyle.waves,
        CompanionHairStyle.ponytail,
      ]);
    },
  );

  test('seven skin tones, the seventh the deepest, added last', () {
    expect(CompanionSkinTone.values, hasLength(7));
    expect(CompanionSkinTone.values.last, CompanionSkinTone.tone7);
    for (final t in CompanionSkinTone.values.take(6)) {
      expect(
        CompanionSkinTone.tone7.skin.computeLuminance(),
        lessThan(t.skin.computeLuminance()),
        reason: t.name,
      );
    }
    // Lips deep enough to read on it.
    expect(CompanionSkinTone.tone7.lips, isNotNull);
  });

  test('the skin tones run light to deep, each shade below its skin', () {
    for (var i = 1; i < CompanionSkinTone.values.length; i++) {
      expect(
        _luminance(CompanionSkinTone.values[i]),
        lessThan(_luminance(CompanionSkinTone.values[i - 1])),
      );
    }
    for (final t in CompanionSkinTone.values) {
      expect(t.shade.computeLuminance(), lessThan(t.skin.computeLuminance()));
      expect(t.deep.computeLuminance(), lessThan(t.shade.computeLuminance()));
      expect(
        t.light.computeLuminance(),
        greaterThan(t.skin.computeLuminance()),
      );
    }
  });

  test('the first tone and silver are her own colours', () {
    const c = CompanionPalette();
    const t = CompanionSkinTone.tone1;
    expect(
      [t.skin, t.shade, t.deep, t.light],
      [
        c.skin,
        c.skinShade,
        c.skinDeep,
        c.skinLight,
      ],
    );
    const h = CompanionHairColour.silver;
    expect(
      [h.hair, h.back, h.shade, h.light, h.brow],
      [
        c.hair,
        c.hairBack,
        c.hairShade,
        c.hairLight,
        c.brow,
      ],
    );
  });

  test('every hair colour is its own, the back a shade darker', () {
    expect(
      CompanionHairColour.values.map((c) => c.hair).toSet(),
      hasLength(CompanionHairColour.values.length),
    );
    for (final c in CompanionHairColour.values) {
      expect(
        c.back.computeLuminance(),
        lessThan(c.hair.computeLuminance()),
        reason: c.name,
      );
    }
  });

  group('eye colours', () {
    test('are their own, the lit side lighter than the iris', () {
      expect(
        CompanionEyeColour.values.map((e) => e.iris).toSet(),
        hasLength(CompanionEyeColour.values.length),
      );
      for (final e in CompanionEyeColour.values) {
        expect(
          e.light.computeLuminance(),
          greaterThan(e.iris.computeLuminance()),
          reason: e.name,
        );
      }
    });

    test("blue is the pitch videos' blue, Lotti's own on the first tone", () {
      const c = CompanionPalette();
      expect(CompanionEyeColour.blue.iris, c.iris);
      expect(CompanionEyeColour.blue.light, c.irisLight);
      expect(CompanionSkinTone.tone1.eyes, CompanionEyeColour.blue);
    });

    // The ask: blue eyes on every skin tone did not fit.
    test('every tone past the first matches eyes darker than blue, and the '
        'deeper the tone the darker its eyes', () {
      for (final t in CompanionSkinTone.values.skip(1)) {
        expect(t.eyes, isNot(CompanionEyeColour.blue), reason: t.name);
      }
      const tones = CompanionSkinTone.values;
      for (var i = 2; i < tones.length; i++) {
        expect(
          tones[i].eyes.iris.computeLuminance(),
          lessThanOrEqualTo(tones[i - 1].eyes.iris.computeLuminance()),
          reason: tones[i].name,
        );
      }
    });
  });

  group("a man's natural lips", () {
    /// How much redder than its own greens and blues a colour is.
    double redness(Color c) => c.r - (c.g + c.b) / 2;

    // The ask: the uncle read as a lady wearing lipstick.
    test('are less red than the rose lips of the same tone', () {
      const rose = CompanionPalette();
      for (final t in CompanionSkinTone.values) {
        expect(
          redness(t.naturalLips.lips),
          lessThan(redness(t.lips ?? rose.lips)),
          reason: t.name,
        );
      }
    });

    test('the upper lip in shade below the lower, lit one', () {
      for (final t in CompanionSkinTone.values) {
        final lips = t.naturalLips;
        expect(
          lips.upper.computeLuminance(),
          lessThan(lips.lips.computeLuminance()),
          reason: t.name,
        );
        expect(
          lips.light.computeLuminance(),
          greaterThan(lips.lips.computeLuminance()),
          reason: t.name,
        );
      }
    });
  });
}
