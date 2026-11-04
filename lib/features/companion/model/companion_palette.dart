import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Who the companion is dressed as: the colours, and the few switches that
/// differ between outfits.
///
/// Lotti's are the looks of the pitch videos' grandmother (their rig's
/// `looks.py`; see the feature README for where that rig lives), carried
/// over as data; the grandpa's and the animals' were drawn here. They are illustration colours — the character's skin, hair and
/// clothes, like the pixels of a drawing — not interface colours, so they do
/// not come from the design system's tokens.
@immutable
class CompanionPalette {
  const CompanionPalette({
    this.hair = const Color(0xFFD9D6D1),
    this.hairBack = const Color(0xFFB9B5B0),
    this.hairShade = const Color(0xFFA39E98),
    this.hairLight = const Color(0xFFF4F2EE),
    this.skin = const Color(0xFFF1D2BD),
    this.skinShade = const Color(0xFFD9B39B),
    this.skinDeep = const Color(0xFFC0957C),
    this.skinLight = const Color(0xFFF9E3D2),
    this.brow = const Color(0xFF8E8780),
    this.iris = const Color(0xFF4A6F8F),
    this.irisLight = const Color(0xFF7EA2C0),
    this.pupil = const Color(0xFF141A22),
    this.eyeWhite = const Color(0xFFF7F5F2),
    this.lips = const Color(0xFFC9666A),
    this.lipsUpper = const Color(0xFFB2555A),
    this.lipsLight = const Color(0xFFE3959A),
    this.mouthIn = const Color(0xFF4A1418),
    this.teeth = const Color(0xFFFBF7F1),
    this.tongue = const Color(0xFFD4636B),
    this.dress = const Color(0xFF1F7F8A),
    this.dressShade = const Color(0xFF17646D),
    this.dressLight = const Color(0xFF2B96A2),
    this.cardigan = const Color(0xFFE0A526),
    this.cardiganShade = const Color(0xFFBD861A),
    this.cardiganLight = const Color(0xFFF0BF4A),
    this.scarf = const Color(0xFFC2405A),
    this.scarfDot = const Color(0xFFF6E7C3),
    this.glasses = const Color(0xFF5A3A22),
    this.glassesLight = const Color(0xFF8A5A33),
    this.pearl = const Color(0xFFF5EFE6),
    this.pearlShade = const Color(0xFFD8CDBD),
    this.shoe = const Color(0xFF5C1F2B),
    this.shoeShade = const Color(0xFF3F1119),
    this.sole = const Color(0xFF2A2A2E),
    this.ink = const Color(0xFF1D2329),
    this.hat = const Color(0xFFD8322C),
    this.hatShade = const Color(0xFFA8231F),
    this.lens = const Color(0xFF3A2418),
    this.beads = const Color(0xFFC8302C),
    this.beadsLight = const Color(0xFFEE6A62),
    this.glove = const Color(0xFFD8322C),
    this.gloveDeep = const Color(0xFF8F1A18),
    this.earring = const Color(0xFFD8322C),
    this.shirt = const Color(0xFFB9D3EA),
    this.shirtShade = const Color(0xFF93B2D0),
    this.shirtLight = const Color(0xFFD9E8F5),
    this.trousers = const Color(0xFF44474D),
    this.trousersShade = const Color(0xFF2F3135),
    this.trousersLight = const Color(0xFF5D6169),
    this.braces = const Color(0xFFB4532A),
    this.bowTie = const Color(0xFF6E2C5C),
    this.bowTieShade = const Color(0xFF4E1E41),
    this.cap = const Color(0xFF8E8A86),
    this.capShade = const Color(0xFF6F6B67),
    this.belt = const Color(0xFF8C5530),
    this.headband = const Color(0xFF2FB5A8),
    this.jacket = const Color(0xFF22252B),
    this.jacketShade = const Color(0xFF14161A),
    this.jacketLight = const Color(0xFF353942),
    this.rib = const Color(0xFF4A4F58),
    this.headphones = const Color(0xFFC9CCD2),
    this.muzzle,
    this.earInner,
    this.furMark,
    this.limb,
    this.limbDeep,
    this.paw,
    this.nose,
    this.whisker,
    this.tail,
    this.tailRing,
  });

  final Color hair;
  final Color hairBack;
  final Color hairShade;
  final Color hairLight;
  final Color skin;
  final Color skinShade;
  final Color skinDeep;
  final Color skinLight;
  final Color brow;
  final Color iris;
  final Color irisLight;
  final Color pupil;
  final Color eyeWhite;
  final Color lips;
  final Color lipsUpper;
  final Color lipsLight;
  final Color mouthIn;
  final Color teeth;
  final Color tongue;
  final Color dress;
  final Color dressShade;
  final Color dressLight;
  final Color cardigan;
  final Color cardiganShade;
  final Color cardiganLight;
  final Color scarf;
  final Color scarfDot;
  final Color glasses;
  final Color glassesLight;
  final Color pearl;
  final Color pearlShade;
  final Color shoe;
  final Color shoeShade;
  final Color sole;
  final Color ink;
  final Color hat;
  final Color hatShade;
  final Color lens;
  final Color beads;
  final Color beadsLight;
  final Color glove;
  final Color gloveDeep;
  final Color earring;

  // The grandpa's garments: a shirt tucked into trousers, braces, a bow tie
  // and, in one outfit, a flat cap. The defaults are his everyday outfit.
  final Color shirt;
  final Color shirtShade;
  final Color shirtLight;
  final Color trousers;
  final Color trousersShade;
  final Color trousersLight;
  final Color braces;
  final Color bowTie;
  final Color bowTieShade;
  final Color cap;
  final Color capShade;

  // The aunt's: the belt of her boiler suit — the suit itself takes the
  // trousers' colours — and the headband of one outfit.
  final Color belt;
  final Color headband;

  // The uncle's: a bomber jacket with ribbed collar, cuffs and hem, and the
  // headphones round his neck. His tee takes the shirt's colours, his
  // chinos the trousers', his beanie the cap's.
  final Color jacket;
  final Color jacketShade;
  final Color jacketLight;
  final Color rib;
  final Color headphones;

  // An animal's own colours. Each is null on the grandmother, whose skin
  // stands in for the ones she has a counterpart of.

  /// The pale fur round the mouth and chin.
  final Color? muzzle;
  final Color? earInner;

  /// Stripes, tear marks and the tail's rings.
  final Color? furMark;

  /// Arms and legs, where they differ from the face's fur.
  final Color? limb;
  final Color? limbDeep;

  /// The hands and the feet.
  final Color? paw;
  final Color? nose;
  final Color? whisker;
  final Color? tail;
  final Color? tailRing;

  /// This palette with the given colours changed: how a skin tone or a hair
  /// colour is laid over an outfit.
  CompanionPalette copyWith({
    Color? hair,
    Color? hairBack,
    Color? hairShade,
    Color? hairLight,
    Color? skin,
    Color? skinShade,
    Color? skinDeep,
    Color? skinLight,
    Color? brow,
    Color? iris,
    Color? irisLight,
    Color? pupil,
    Color? eyeWhite,
    Color? lips,
    Color? lipsUpper,
    Color? lipsLight,
    Color? mouthIn,
    Color? teeth,
    Color? tongue,
    Color? dress,
    Color? dressShade,
    Color? dressLight,
    Color? cardigan,
    Color? cardiganShade,
    Color? cardiganLight,
    Color? scarf,
    Color? scarfDot,
    Color? glasses,
    Color? glassesLight,
    Color? pearl,
    Color? pearlShade,
    Color? shoe,
    Color? shoeShade,
    Color? sole,
    Color? ink,
    Color? hat,
    Color? hatShade,
    Color? lens,
    Color? beads,
    Color? beadsLight,
    Color? glove,
    Color? gloveDeep,
    Color? earring,
    Color? shirt,
    Color? shirtShade,
    Color? shirtLight,
    Color? trousers,
    Color? trousersShade,
    Color? trousersLight,
    Color? braces,
    Color? bowTie,
    Color? bowTieShade,
    Color? cap,
    Color? capShade,
    Color? belt,
    Color? headband,
    Color? jacket,
    Color? jacketShade,
    Color? jacketLight,
    Color? rib,
    Color? headphones,
    Color? muzzle,
    Color? earInner,
    Color? furMark,
    Color? limb,
    Color? limbDeep,
    Color? paw,
    Color? nose,
    Color? whisker,
    Color? tail,
    Color? tailRing,
  }) => CompanionPalette(
    hair: hair ?? this.hair,
    hairBack: hairBack ?? this.hairBack,
    hairShade: hairShade ?? this.hairShade,
    hairLight: hairLight ?? this.hairLight,
    skin: skin ?? this.skin,
    skinShade: skinShade ?? this.skinShade,
    skinDeep: skinDeep ?? this.skinDeep,
    skinLight: skinLight ?? this.skinLight,
    brow: brow ?? this.brow,
    iris: iris ?? this.iris,
    irisLight: irisLight ?? this.irisLight,
    pupil: pupil ?? this.pupil,
    eyeWhite: eyeWhite ?? this.eyeWhite,
    lips: lips ?? this.lips,
    lipsUpper: lipsUpper ?? this.lipsUpper,
    lipsLight: lipsLight ?? this.lipsLight,
    mouthIn: mouthIn ?? this.mouthIn,
    teeth: teeth ?? this.teeth,
    tongue: tongue ?? this.tongue,
    dress: dress ?? this.dress,
    dressShade: dressShade ?? this.dressShade,
    dressLight: dressLight ?? this.dressLight,
    cardigan: cardigan ?? this.cardigan,
    cardiganShade: cardiganShade ?? this.cardiganShade,
    cardiganLight: cardiganLight ?? this.cardiganLight,
    scarf: scarf ?? this.scarf,
    scarfDot: scarfDot ?? this.scarfDot,
    glasses: glasses ?? this.glasses,
    glassesLight: glassesLight ?? this.glassesLight,
    pearl: pearl ?? this.pearl,
    pearlShade: pearlShade ?? this.pearlShade,
    shoe: shoe ?? this.shoe,
    shoeShade: shoeShade ?? this.shoeShade,
    sole: sole ?? this.sole,
    ink: ink ?? this.ink,
    hat: hat ?? this.hat,
    hatShade: hatShade ?? this.hatShade,
    lens: lens ?? this.lens,
    beads: beads ?? this.beads,
    beadsLight: beadsLight ?? this.beadsLight,
    glove: glove ?? this.glove,
    gloveDeep: gloveDeep ?? this.gloveDeep,
    earring: earring ?? this.earring,
    shirt: shirt ?? this.shirt,
    shirtShade: shirtShade ?? this.shirtShade,
    shirtLight: shirtLight ?? this.shirtLight,
    trousers: trousers ?? this.trousers,
    trousersShade: trousersShade ?? this.trousersShade,
    trousersLight: trousersLight ?? this.trousersLight,
    braces: braces ?? this.braces,
    bowTie: bowTie ?? this.bowTie,
    bowTieShade: bowTieShade ?? this.bowTieShade,
    cap: cap ?? this.cap,
    capShade: capShade ?? this.capShade,
    belt: belt ?? this.belt,
    headband: headband ?? this.headband,
    jacket: jacket ?? this.jacket,
    jacketShade: jacketShade ?? this.jacketShade,
    jacketLight: jacketLight ?? this.jacketLight,
    rib: rib ?? this.rib,
    headphones: headphones ?? this.headphones,
    muzzle: muzzle ?? this.muzzle,
    earInner: earInner ?? this.earInner,
    furMark: furMark ?? this.furMark,
    limb: limb ?? this.limb,
    limbDeep: limbDeep ?? this.limbDeep,
    paw: paw ?? this.paw,
    nose: nose ?? this.nose,
    whisker: whisker ?? this.whisker,
    tail: tail ?? this.tail,
    tailRing: tailRing ?? this.tailRing,
  );

  Color get limbColor => limb ?? skin;
  Color get limbDeepColor => limbDeep ?? skinDeep;
  Color get pawColor => paw ?? limbColor;
  Color get muzzleColor => muzzle ?? skinLight;
  Color get furMarkColor => furMark ?? skinDeep;
  Color get tailColor => tail ?? skin;
  Color get tailRingColor => tailRing ?? furMarkColor;
}
