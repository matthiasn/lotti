import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';

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
      'grandpa',
      'grandpa_jazz',
      'grandpa_seaside',
      'grandpa_market',
      'aunt',
      'aunt_studio',
      'aunt_festival',
      'aunt_weekend',
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
    expect(CompanionSpecies.grandpa.isAnimal, isFalse);
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

  test('copyWith with nothing to change keeps every part as it was', () {
    const look = CompanionLook.grandmaRock;
    final palette = look.palette;
    final kept = palette.copyWith();
    expect(
      [
        kept.hair,
        kept.hairBack,
        kept.hairShade,
        kept.hairLight,
        kept.skin,
        kept.skinShade,
        kept.skinDeep,
        kept.skinLight,
        kept.brow,
        kept.dress,
        kept.cardigan,
      ],
      [
        palette.hair,
        palette.hairBack,
        palette.hairShade,
        palette.hairLight,
        palette.skin,
        palette.skinShade,
        palette.skinDeep,
        palette.skinLight,
        palette.brow,
        palette.dress,
        palette.cardigan,
      ],
    );

    final same = look.copyWith();
    expect(identical(same.palette, palette), isTrue);
    expect(same.hairStyle, look.hairStyle);
    expect(
      [same.id, same.sunglasses, same.beret, same.beads, same.glove],
      [look.id, look.sunglasses, look.beret, look.beads, look.glove],
    );
  });

  group('characters', () {
    test('each stands on the legs its body has', () {
      expect(
        {for (final s in CompanionSpecies.values) s: s.legs},
        {
          CompanionSpecies.grandma: CompanionLegs.bare,
          CompanionSpecies.grandpa: CompanionLegs.trousers,
          CompanionSpecies.aunt: CompanionLegs.trousers,
          CompanionSpecies.cat: CompanionLegs.paws,
          CompanionSpecies.redPanda: CompanionLegs.paws,
        },
      );
    });

    test('a person chooses among the humans, Lotti first', () {
      expect(CompanionSpecies.choosable, [
        CompanionSpecies.grandma,
        CompanionSpecies.grandpa,
        CompanionSpecies.aunt,
      ]);
    });

    test('only the grandpa is bearded, and his own hair is short', () {
      expect(
        [
          for (final s in CompanionSpecies.values)
            if (s.bearded) s,
        ],
        [CompanionSpecies.grandpa],
      );
      expect(CompanionSpecies.grandpa.hairStyle, CompanionHairStyle.short);
      expect(CompanionSpecies.grandma.hairStyle, CompanionHairStyle.bun);
      expect(CompanionSpecies.aunt.hairStyle, CompanionHairStyle.bob);
    });

    test('only the grandparents are aged', () {
      expect(
        [
          for (final s in CompanionSpecies.values)
            if (s.aged) s,
        ],
        [CompanionSpecies.grandma, CompanionSpecies.grandpa],
      );
    });

    test('the grandpa wears brogues and the aunt high-tops', () {
      expect(CompanionSpecies.grandpa.shoes, CompanionShoes.brogues);
      expect(CompanionSpecies.aunt.shoes, CompanionShoes.highTops);
    });
  });

  group("the grandpa's outfits", () {
    final his = CompanionLook.of(CompanionSpecies.grandpa);

    test('are four, his everyday one first', () {
      expect(his, [
        CompanionLook.grandpa,
        CompanionLook.grandpaJazz,
        CompanionLook.grandpaSeaside,
        CompanionLook.grandpaMarket,
      ]);
    });

    test("wear readers and short hair, and none of Lotti's props", () {
      for (final look in his) {
        expect(look.readingGlasses, isTrue, reason: look.id);
        expect(look.hairStyle, CompanionHairStyle.short, reason: look.id);
        expect(
          [look.glasses, look.sunglasses, look.beret, look.beads, look.glove],
          everyElement(isFalse),
          reason: look.id,
        );
        expect(look.earring, EarringKind.none, reason: look.id);
      }
    });

    test('put the flat cap on for the market only', () {
      expect(
        [
          for (final look in his)
            if (look.flatCap) look,
        ],
        [CompanionLook.grandpaMarket],
      );
    });

    test('no two share a shirt and trousers', () {
      expect(
        his.map((l) => (l.palette.shirt, l.palette.trousers)).toSet(),
        hasLength(his.length),
      );
    });

    test("repeat none of the colours of Lotti's dresses and cardigans", () {
      final hers = {
        for (final look in CompanionLook.of(CompanionSpecies.grandma)) ...[
          look.palette.dress,
          look.palette.cardigan,
        ],
      };
      for (final look in his) {
        final c = look.palette;
        expect(
          [c.shirt, c.trousers, c.braces, c.bowTie],
          everyElement(isNot(isIn(hers))),
          reason: look.id,
        );
      }
    });

    test('the everyday one wears the palette defaults for his garments', () {
      const base = CompanionPalette();
      final c = CompanionLook.grandpa.palette;
      expect(
        [c.shirt, c.trousers, c.braces, c.bowTie, c.cap],
        [base.shirt, base.trousers, base.braces, base.bowTie, base.cap],
      );
    });

    test('copyWith keeps the readers and the cap', () {
      final dressed = CompanionLook.grandpaMarket.copyWith(
        hairStyle: CompanionHairStyle.balding,
      );
      expect(dressed.readingGlasses, isTrue);
      expect(dressed.flatCap, isTrue);
      expect(dressed.hairStyle, CompanionHairStyle.balding);
      expect(dressed.species, CompanionSpecies.grandpa);
    });
  });

  test('palette copyWith changes only the garment colours it is given', () {
    const red = Color(0xFFFF0000);
    const base = CompanionPalette();
    final changed = base.copyWith(
      shirt: red,
      shirtShade: red,
      shirtLight: red,
      trousers: red,
      trousersShade: red,
      trousersLight: red,
      braces: red,
      bowTie: red,
      bowTieShade: red,
      cap: red,
      capShade: red,
    );
    expect(
      [
        changed.shirt,
        changed.shirtShade,
        changed.shirtLight,
        changed.trousers,
        changed.trousersShade,
        changed.trousersLight,
        changed.braces,
        changed.bowTie,
        changed.bowTieShade,
        changed.cap,
        changed.capShade,
      ],
      everyElement(red),
    );
    expect([changed.dress, changed.skin], [base.dress, base.skin]);
    final kept = changed.copyWith();
    expect([kept.shirt, kept.cap], [red, red]);
  });

  group("the aunt's outfits", () {
    final hers = CompanionLook.of(CompanionSpecies.aunt);

    test('are four, her everyday one first', () {
      expect(hers, [
        CompanionLook.aunt,
        CompanionLook.auntStudio,
        CompanionLook.auntFestival,
        CompanionLook.auntWeekend,
      ]);
    });

    test('wear gold hoops and no frames or props of the others', () {
      for (final look in hers) {
        expect(look.earring, EarringKind.hoop, reason: look.id);
        expect(look.hairStyle, CompanionHairStyle.bob, reason: look.id);
        expect(
          [
            look.glasses,
            look.sunglasses,
            look.readingGlasses,
            look.beret,
            look.beads,
            look.glove,
            look.flatCap,
          ],
          everyElement(isFalse),
          reason: look.id,
        );
      }
    });

    test('put the headband on for the festival only', () {
      expect(
        [
          for (final look in hers)
            if (look.headband) look,
        ],
        [CompanionLook.auntFestival],
      );
    });

    test('no two share a suit colour', () {
      expect(hers.map((l) => l.palette.trousers).toSet(), hasLength(4));
    });

    test("repeat no garment colour of Lotti's or the grandpa's", () {
      final theirs = {
        for (final look in CompanionLook.of(CompanionSpecies.grandma)) ...[
          look.palette.dress,
          look.palette.cardigan,
        ],
        for (final look in CompanionLook.of(CompanionSpecies.grandpa)) ...[
          look.palette.shirt,
          look.palette.trousers,
          look.palette.braces,
          look.palette.bowTie,
        ],
      };
      for (final look in hers) {
        expect(theirs, isNot(contains(look.palette.trousers)), reason: look.id);
      }
    });

    test('copyWith keeps the headband', () {
      final dressed = CompanionLook.auntFestival.copyWith(
        hairStyle: CompanionHairStyle.afro,
      );
      expect(dressed.headband, isTrue);
      expect(dressed.earring, EarringKind.hoop);
    });

    test('the palette changes her belt and headband alone', () {
      const red = Color(0xFFFF0000);
      const base = CompanionPalette();
      final changed = base.copyWith(belt: red, headband: red);
      expect([changed.belt, changed.headband], [red, red]);
      expect(changed.trousers, base.trousers);
      expect(changed.copyWith().belt, red);
    });
  });
}
