import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';

void main() {
  test('every look has its own id', () {
    final ids = CompanionLook.all.map((l) => l.id).toSet();
    expect(ids, {
      'grandma',
      'grandma_stage',
      'grandma_rock',
      'grandma_garden',
      'grandma_lavender',
      'grandma_winter',
      'cat',
      'cat_rock',
      'red_panda',
      'red_panda_bookish',
    });
  });

  test('every species has at least two looks, its own', () {
    for (final species in CompanionSpecies.values) {
      final looks = CompanionLook.of(species);
      expect(looks.length, greaterThanOrEqualTo(2), reason: species.name);
      expect(looks.every((l) => l.species == species), isTrue);
    }
    expect(
      CompanionSpecies.values.expand(CompanionLook.of).toList(),
      unorderedEquals(CompanionLook.all),
    );
  });

  test('only the animals are animals, and the red panda has the big head', () {
    expect(CompanionSpecies.grandma.isAnimal, isFalse);
    expect(CompanionSpecies.cat.isAnimal, isTrue);
    expect(CompanionSpecies.redPanda.isAnimal, isTrue);
    expect(
      CompanionSpecies.redPanda.headScale,
      greaterThan(CompanionSpecies.cat.headScale),
    );
  });

  test("the grandmother's limbs and paws fall back to her skin", () {
    const c = CompanionPalette();
    expect(c.limbColor, c.skin);
    expect(c.limbDeepColor, c.skinDeep);
    expect(c.pawColor, c.skin);
    expect(c.muzzleColor, c.skinLight);
    expect(c.furMarkColor, c.skinDeep);
    expect(c.tailColor, c.skin);
    expect(c.tailRingColor, c.skinDeep);
  });

  test(
    'the cat has white paws; the red panda dark limbs and a ringed tail',
    () {
      final cat = CompanionLook.cat.palette;
      expect(cat.pawColor, isNot(cat.limbColor));
      final panda = CompanionLook.redPanda.palette;
      expect(panda.limbColor, isNot(panda.skin));
      expect(panda.pawColor, panda.limbColor);
      expect(panda.tailRingColor, isNot(panda.tailColor));
    },
  );

  test('the animals wear no earrings and the rock cat keeps its props', () {
    for (final species in [CompanionSpecies.cat, CompanionSpecies.redPanda]) {
      for (final look in CompanionLook.of(species)) {
        expect(look.earring, EarringKind.none, reason: look.id);
      }
    }
    const rock = CompanionLook.catRock;
    expect(rock.sunglasses && rock.beret && rock.beads && rock.glove, isTrue);
    expect(CompanionLook.redPandaBookish.glasses, isTrue);
  });

  test('the stage look keeps her face and changes only the outfit', () {
    const base = CompanionPalette();
    final stage = CompanionLook.grandmaStage.palette;
    expect(stage.skin, base.skin);
    expect(stage.hair, base.hair);
    expect(stage.iris, base.iris);
    expect(stage.dress, isNot(base.dress));
    expect(stage.cardigan, isNot(base.cardigan));
    expect(CompanionLook.grandmaStage.glasses, isTrue);
  });

  test('the rock look swaps the glasses for sunglasses and adds the props', () {
    const rock = CompanionLook.grandmaRock;
    expect(rock.glasses, isFalse);
    expect(rock.sunglasses, isTrue);
    expect(rock.beret && rock.beads && rock.glove, isTrue);
    expect(rock.earring, EarringKind.disc);
    expect(rock.palette.lips, isNot(const CompanionPalette().lips));
  });

  test('the everyday look wears none of the props', () {
    const g = CompanionLook.grandma;
    expect(g.sunglasses || g.beret || g.beads || g.glove, isFalse);
    expect(g.earring, EarringKind.pearl);
  });

  test('her new outfits keep her face and change only her clothes', () {
    const base = CompanionPalette();
    final outfits = [
      CompanionLook.grandmaGarden,
      CompanionLook.grandmaLavender,
      CompanionLook.grandmaWinter,
    ];
    for (final look in outfits) {
      final c = look.palette;
      expect(look.species, CompanionSpecies.grandma, reason: look.id);
      expect(
        [c.skin, c.hair, c.iris, c.lips],
        [
          base.skin,
          base.hair,
          base.iris,
          base.lips,
        ],
        reason: look.id,
      );
      expect(c.dress, isNot(base.dress), reason: look.id);
      expect(c.cardigan, isNot(base.cardigan), reason: look.id);
      expect(look.glasses, isTrue, reason: look.id);
    }
    // No two of her outfits share a dress and cardigan.
    final grandma = CompanionLook.of(CompanionSpecies.grandma);
    expect(
      grandma.map((l) => (l.palette.dress, l.palette.cardigan)).toSet(),
      hasLength(grandma.length),
    );
  });
}
