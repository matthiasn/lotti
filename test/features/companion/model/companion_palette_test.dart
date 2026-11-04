import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_palette.dart';

void main() {
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

  test('the palette changes her belt and headband alone', () {
    const red = Color(0xFFFF0000);
    const base = CompanionPalette();
    final changed = base.copyWith(belt: red, headband: red);
    expect([changed.belt, changed.headband], [red, red]);
    expect(changed.trousers, base.trousers);
    expect(changed.copyWith().belt, red);
  });

  test("the uncle's jacket, rib and headphones change alone", () {
    const red = Color(0xFFFF0000);
    const base = CompanionPalette();
    final changed = base.copyWith(
      jacket: red,
      jacketShade: red,
      jacketLight: red,
      rib: red,
      headphones: red,
    );
    expect(
      [
        changed.jacket,
        changed.jacketShade,
        changed.jacketLight,
        changed.rib,
        changed.headphones,
      ],
      everyElement(red),
    );
    expect(changed.shirt, base.shirt);
    expect(changed.copyWith().rib, red);
  });
}
