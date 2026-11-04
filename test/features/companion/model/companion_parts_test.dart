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
}
