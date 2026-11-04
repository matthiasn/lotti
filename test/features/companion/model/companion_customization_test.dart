import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

void main() {
  test('the default draws her exactly as the pitch videos do', () {
    for (final outfit in CompanionLook.of(CompanionSpecies.grandma)) {
      final dressed = const CompanionCustomization().dress(outfit);
      final a = dressed.palette;
      final b = outfit.palette;
      expect(
        [a.skin, a.skinShade, a.skinDeep, a.skinLight, a.lips],
        [b.skin, b.skinShade, b.skinDeep, b.skinLight, b.lips],
        reason: outfit.id,
      );
      expect(
        [a.hair, a.hairBack, a.hairShade, a.hairLight, a.brow],
        [b.hair, b.hairBack, b.hairShade, b.hairLight, b.brow],
        reason: outfit.id,
      );
      expect(dressed.hairStyle, CompanionHairStyle.bun, reason: outfit.id);
    }
  });

  test('dress keeps the outfit and its props, and takes the skin and hair', () {
    const custom = CompanionCustomization(
      skinTone: CompanionSkinTone.tone5,
      hairStyle: CompanionHairStyle.locs,
      hairColour: CompanionHairColour.blue,
    );
    const outfit = CompanionLook.grandmaRock;
    final dressed = custom.dress(outfit);
    expect(dressed.id, outfit.id);
    expect(dressed.palette.dress, outfit.palette.dress);
    expect(dressed.beret && dressed.sunglasses && dressed.glove, isTrue);
    expect(dressed.palette.skin, CompanionSkinTone.tone5.skin);
    expect(dressed.palette.limbColor, CompanionSkinTone.tone5.skin);
    expect(dressed.palette.hair, CompanionHairColour.blue.hair);
    expect(dressed.palette.brow, CompanionHairColour.blue.brow);
    expect(dressed.hairStyle, CompanionHairStyle.locs);
  });

  test("a deeper tone deepens plain lips, never an outfit's lipstick", () {
    const custom = CompanionCustomization(skinTone: CompanionSkinTone.tone6);
    expect(
      custom.dress(CompanionLook.grandma).palette.lips,
      CompanionSkinTone.tone6.lips,
    );
    expect(
      custom.dress(CompanionLook.grandmaRock).palette.lips,
      CompanionLook.grandmaRock.palette.lips,
    );
  });

  test('round-trips through JSON, with and without an outfit', () {
    for (final custom in const [
      CompanionCustomization(),
      CompanionCustomization(
        skinTone: CompanionSkinTone.tone3,
        hairStyle: CompanionHairStyle.afro,
        hairColour: CompanionHairColour.auburn,
        outfitId: 'grandma_winter',
        sass: CompanionSass.sassy,
        speaksReplies: false,
      ),
    ]) {
      expect(CompanionCustomization.fromJson(custom.toJson()), custom);
    }
    expect(const CompanionCustomization().toJson(), isNot(contains('outfit')));
  });

  test('she teases by default, a cheeky sass, never a scold', () {
    expect(const CompanionCustomization().sass, CompanionSass.cheeky);
    expect(const CompanionCustomization().toJson()['sass'], 'cheeky');
  });

  test('she answers a spoken question aloud unless she is muted; only an '
      'explicit false mutes her', () {
    expect(const CompanionCustomization().speaksReplies, isTrue);
    expect(
      CompanionCustomization.fromJson(const {
        'speaksReplies': false,
      }).speaksReplies,
      isFalse,
    );
    expect(
      CompanionCustomization.fromJson(const {
        'speaksReplies': 'no',
      }).speaksReplies,
      isTrue,
    );
    expect(
      const CompanionCustomization().copyWith(speaksReplies: false),
      isNot(const CompanionCustomization()),
    );
  });

  test('changedParts names what differs; adopting takes only those parts', () {
    const stored = CompanionCustomization(
      sass: CompanionSass.sassy,
      speaksReplies: false,
    );
    const shown = CompanionCustomization();
    final changed = shown.copyWith(hairStyle: CompanionHairStyle.locs);

    expect(CompanionCustomization.changedParts(shown, changed), {'hairStyle'});
    expect(CompanionCustomization.changedParts(shown, shown), isEmpty);
    expect(
      stored.adopting(changed, {'hairStyle'}),
      const CompanionCustomization(
        hairStyle: CompanionHairStyle.locs,
        sass: CompanionSass.sassy,
        speaksReplies: false,
      ),
    );
    // A part named is taken even where it equals the default shown.
    expect(stored.adopting(shown, {'speaksReplies'}).speaksReplies, isTrue);
  });

  test('the deepest tone and the new styles round-trip', () {
    const custom = CompanionCustomization(
      skinTone: CompanionSkinTone.tone7,
      hairStyle: CompanionHairStyle.ponytail,
    );
    expect(CompanionCustomization.fromJson(custom.toJson()), custom);
  });

  test('a part a newer version wrote falls back to its default', () {
    final read = CompanionCustomization.fromJson(const {
      'skinTone': 'tone9',
      'hairStyle': 'mohawk',
      'hairColour': 'green',
      'outfit': 'grandma_space',
      'sass': 'savage',
    });
    expect(read, const CompanionCustomization());
    expect(
      CompanionCustomization.fromJson(const {}),
      const CompanionCustomization(),
    );
  });

  group('toJsonOver', () {
    // Written by a newer version: a hairstyle, an outfit and a part this one
    // has never heard of.
    const newer = {
      'skinTone': 'tone2',
      'hairStyle': 'mohawk',
      'hairColour': 'black',
      'outfit': 'grandma_space',
      'eyes': 'green',
    };
    final read = CompanionCustomization.fromJson(newer);

    test('keeps what a newer version wrote in every part left alone', () {
      expect(
        read.copyWith(skinTone: CompanionSkinTone.tone5).toJsonOver(newer),
        {...newer, 'skinTone': 'tone5'},
      );
      expect(read.toJsonOver(newer), newer);
    });

    test('writes a part that changed, over what it could not read', () {
      expect(
        read
            .copyWith(
              hairStyle: CompanionHairStyle.bob,
              outfitId: () => 'grandma_rock',
            )
            .toJsonOver(newer),
        {...newer, 'hairStyle': 'bob', 'outfit': 'grandma_rock'},
      );
    });

    test('writes a changed sass, and keeps one an older read left alone', () {
      expect(
        read.copyWith(sass: CompanionSass.warm).toJsonOver(newer),
        {...newer, 'sass': 'warm'},
      );
      // Stored before there was a sass: a change to another part does not
      // write the default in.
      expect(
        read.copyWith(skinTone: CompanionSkinTone.tone4).toJsonOver(newer),
        isNot(contains('sass')),
      );
    });

    test('clears an outfit set back to a surprise', () {
      const stored = {
        'skinTone': 'tone1',
        'hairStyle': 'bun',
        'hairColour': 'silver',
        'outfit': 'grandma_rock',
      };
      final json = CompanionCustomization.fromJson(
        stored,
      ).copyWith(outfitId: () => null).toJsonOver(stored);
      expect(json, isNot(contains('outfit')));
      expect(CompanionCustomization.fromJson(json).outfitId, isNull);
    });
  });

  test('copyWith changes what it is given, and can clear the outfit', () {
    const custom = CompanionCustomization(outfitId: 'grandma_rock');
    expect(
      custom.copyWith(hairStyle: CompanionHairStyle.bob).hairStyle,
      CompanionHairStyle.bob,
    );
    expect(
      custom.copyWith(hairStyle: CompanionHairStyle.bob).outfitId,
      'grandma_rock',
    );
    expect(custom.copyWith(outfitId: () => null).outfitId, isNull);
    expect(
      custom.copyWith(sass: CompanionSass.sassy).sass,
      CompanionSass.sassy,
    );
    expect(custom.copyWith(sass: CompanionSass.sassy), isNot(custom));
    expect(custom.copyWith(), custom);
    expect(custom.copyWith().hashCode, custom.hashCode);
  });

  group('the character', () {
    const grandpa = CompanionCustomization(
      character: CompanionSpecies.grandpa,
      hairStyle: CompanionHairStyle.balding,
      outfitId: 'grandpa_jazz',
    );

    test('is Lotti by default, and written by its name', () {
      expect(
        const CompanionCustomization().character,
        CompanionSpecies.grandma,
      );
      expect(const CompanionCustomization().toJson()['character'], 'grandma');
      expect(grandpa.toJson()['character'], 'grandpa');
    });

    test('round-trips through JSON with his own outfit', () {
      expect(CompanionCustomization.fromJson(grandpa.toJson()), grandpa);
    });

    test('reads as Lotti when unknown, or when an animal was stored', () {
      for (final name in ['wizard', 'cat', 'redPanda', 42]) {
        expect(
          CompanionCustomization.fromJson({'character': name}).character,
          CompanionSpecies.grandma,
          reason: '$name',
        );
      }
    });

    test("drops an outfit that is another character's", () {
      expect(
        CompanionCustomization.fromJson(const {
          'character': 'grandpa',
          'outfit': 'grandma_rock',
        }).outfitId,
        isNull,
      );
      expect(
        CompanionCustomization.fromJson(const {
          'outfit': 'grandpa_jazz',
        }).outfitId,
        isNull,
      );
    });

    test('asCharacter clears the outfit and takes his own hair', () {
      const lotti = CompanionCustomization(
        skinTone: CompanionSkinTone.tone4,
        hairStyle: CompanionHairStyle.locs,
        hairColour: CompanionHairColour.blue,
        outfitId: 'grandma_rock',
        sass: CompanionSass.sassy,
        speaksReplies: false,
      );
      expect(
        lotti.asCharacter(CompanionSpecies.grandpa),
        const CompanionCustomization(
          character: CompanionSpecies.grandpa,
          skinTone: CompanionSkinTone.tone4,
          hairStyle: CompanionHairStyle.short,
          hairColour: CompanionHairColour.blue,
          sass: CompanionSass.sassy,
          speaksReplies: false,
        ),
      );
      expect(
        grandpa.asCharacter(CompanionSpecies.grandma).hairStyle,
        CompanionHairStyle.bun,
      );
    });

    test('asCharacter gives the aunt her bob, outfit cleared', () {
      final aunt = grandpa.asCharacter(CompanionSpecies.aunt);
      expect(aunt.character, CompanionSpecies.aunt);
      expect(aunt.hairStyle, CompanionHairStyle.bob);
      expect(aunt.outfitId, isNull);
      expect(
        CompanionCustomization.fromJson(
          aunt.copyWith(outfitId: () => 'aunt_studio').toJson(),
        ).outfitId,
        'aunt_studio',
      );
    });

    test('asCharacter gives the uncle his curls, outfit cleared', () {
      final uncle = grandpa.asCharacter(CompanionSpecies.uncle);
      expect(uncle.character, CompanionSpecies.uncle);
      expect(uncle.hairStyle, CompanionHairStyle.curls);
      expect(uncle.outfitId, isNull);
      expect(
        CompanionCustomization.fromJson(
          uncle.copyWith(outfitId: () => 'uncle_snow').toJson(),
        ).outfitId,
        'uncle_snow',
      );
    });

    test('dresses his outfit in the chosen skin and hair', () {
      final dressed = grandpa.dress(CompanionLook.grandpaJazz);
      expect(dressed.species, CompanionSpecies.grandpa);
      expect(dressed.hairStyle, CompanionHairStyle.balding);
      expect(dressed.palette.shirt, CompanionLook.grandpaJazz.palette.shirt);
    });

    test('is a part changedParts names and adopting takes', () {
      const shown = CompanionCustomization();
      final changed = shown.copyWith(character: CompanionSpecies.grandpa);
      expect(CompanionCustomization.changedParts(shown, changed), {
        'character',
      });
      expect(
        shown.adopting(changed, {'character'}).character,
        CompanionSpecies.grandpa,
      );
      expect(
        shown.adopting(changed, {'sass'}).character,
        CompanionSpecies.grandma,
      );
    });

    test('tells two customizations apart', () {
      final other = grandpa.copyWith(character: CompanionSpecies.grandma);
      expect(other, isNot(grandpa));
      expect(other.hashCode, isNot(grandpa.hashCode));
    });
  });

  group('the eyes', () {
    test('match the skin tone by default, and follow a change of tone', () {
      const custom = CompanionCustomization();
      expect(custom.eyeColour, isNull);
      expect(custom.eyes, CompanionSkinTone.tone1.eyes);
      expect(
        custom.copyWith(skinTone: CompanionSkinTone.tone6).eyes,
        CompanionSkinTone.tone6.eyes,
      );
    });

    test('a picked colour wins over the tone, whatever the tone', () {
      const custom = CompanionCustomization(
        skinTone: CompanionSkinTone.tone7,
        eyeColour: CompanionEyeColour.green,
      );
      expect(custom.eyes, CompanionEyeColour.green);
      expect(
        custom.copyWith(skinTone: CompanionSkinTone.tone1).eyes,
        CompanionEyeColour.green,
      );
    });

    test('dress draws the eyes, on every character', () {
      for (final outfit in [
        CompanionLook.grandma,
        CompanionLook.grandpa,
        CompanionLook.aunt,
        CompanionLook.uncle,
      ]) {
        final dressed = const CompanionCustomization(
          skinTone: CompanionSkinTone.tone5,
        ).dress(outfit);
        expect(
          dressed.palette.iris,
          CompanionSkinTone.tone5.eyes.iris,
          reason: outfit.id,
        );
        expect(dressed.palette.irisLight, CompanionSkinTone.tone5.eyes.light);
      }
    });

    test('a picked colour round-trips; matching the tone writes nothing', () {
      const picked = CompanionCustomization(
        eyeColour: CompanionEyeColour.hazel,
      );
      expect(picked.toJson()['eyeColour'], 'hazel');
      expect(CompanionCustomization.fromJson(picked.toJson()), picked);
      expect(
        const CompanionCustomization().toJson(),
        isNot(contains('eyeColour')),
      );
    });

    test('an unknown colour, written by a newer version, matches the tone', () {
      expect(
        CompanionCustomization.fromJson(const {
          'eyeColour': 'violet',
        }).eyeColour,
        isNull,
      );
    });

    test('copyWith picks and clears it; changedParts names it; adopting '
        'takes it', () {
      const base = CompanionCustomization();
      final picked = base.copyWith(eyeColour: () => CompanionEyeColour.grey);
      expect(picked.eyeColour, CompanionEyeColour.grey);
      expect(picked.copyWith(eyeColour: () => null).eyeColour, isNull);
      expect(picked.copyWith().eyeColour, CompanionEyeColour.grey);
      expect(CompanionCustomization.changedParts(base, picked), {'eyeColour'});
      expect(base.adopting(picked, {'eyeColour'}), picked);
      expect(base.adopting(picked, {'sass'}).eyeColour, isNull);
      expect(picked, isNot(base));
      expect(picked.hashCode, isNot(base.hashCode));
    });
  });

  test("dress gives a man the skin's own lips, a woman her rose ones", () {
    const custom = CompanionCustomization(skinTone: CompanionSkinTone.tone4);
    final uncle = custom.dress(CompanionLook.uncle).palette;
    final aunt = custom.dress(CompanionLook.aunt).palette;
    expect(uncle.lips, CompanionSkinTone.tone4.naturalLips.lips);
    expect(uncle.lipsUpper, CompanionSkinTone.tone4.naturalLips.upper);
    expect(uncle.lipsLight, CompanionSkinTone.tone4.naturalLips.light);
    expect(aunt.lips, CompanionSkinTone.tone4.lips);
    expect(
      custom.dress(CompanionLook.grandpa).palette.lips,
      CompanionSkinTone.tone4.naturalLips.lips,
    );
  });
}
