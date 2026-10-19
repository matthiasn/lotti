import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';

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
      ),
    ]) {
      expect(CompanionCustomization.fromJson(custom.toJson()), custom);
    }
    expect(const CompanionCustomization().toJson(), isNot(contains('outfit')));
  });

  test('a part a newer version wrote falls back to its default', () {
    final read = CompanionCustomization.fromJson(const {
      'skinTone': 'tone9',
      'hairStyle': 'mohawk',
      'hairColour': 'green',
      'outfit': 'grandma_space',
    });
    expect(read, const CompanionCustomization());
    expect(
      CompanionCustomization.fromJson(const {}),
      const CompanionCustomization(),
    );
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
    expect(custom.copyWith(), custom);
    expect(custom.copyWith().hashCode, custom.hashCode);
  });
}
