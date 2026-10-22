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
}
