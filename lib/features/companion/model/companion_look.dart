import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/model/companion_palette.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';

export 'package:lotti/features/companion/model/companion_palette.dart';

/// What a character stands on: what the leg painter draws below the hips.
enum CompanionLegs {
  /// Bare legs under a dress, in shoes.
  bare,

  /// Trouser legs down to the shoes.
  trousers,

  /// An animal's furred legs and paws.
  paws,
}

/// What a character in trousers wears on its feet.
enum CompanionShoes {
  /// Lace-ups with a punched toe cap.
  brogues,

  /// Canvas high-tops, laced to above the ankle.
  highTops,

  /// Chunky lace-up boots on a treaded sole.
  boots,
}

/// Who the companion is: each character is its own rig on the same
/// skeleton. The humans share a face and differ in their clothes; the
/// animals have ears, a muzzle and a tail where a human has hair and shoes.
enum CompanionSpecies {
  /// Lotti, the grandmother the app is named after.
  grandma(headScale: 1, legs: CompanionLegs.bare, aged: true),

  /// A grandfather: shirt and braces, trousers, a trimmed beard.
  grandpa(
    headScale: 1,
    legs: CompanionLegs.trousers,
    hairStyle: CompanionHairStyle.short,
    bearded: true,
    aged: true,
    lashes: false,
    masculine: true,
  ),

  /// The aunt, about forty: a boiler suit, high-tops, hoops, no glasses.
  aunt(
    headScale: 1,
    legs: CompanionLegs.trousers,
    hairStyle: CompanionHairStyle.bob,
    shoes: CompanionShoes.highTops,
  ),

  /// The uncle, about thirty: a bomber jacket over a tee, chinos turned up
  /// over boots, headphones round his neck.
  uncle(
    headScale: 1,
    legs: CompanionLegs.trousers,
    hairStyle: CompanionHairStyle.curls,
    shoes: CompanionShoes.boots,
    cuffedTrousers: true,
    lashes: false,
    masculine: true,
    stubble: true,
  ),

  /// Plain proportions, tall pointed ears and a thin tail.
  cat(headScale: 1.02, legs: CompanionLegs.paws),

  /// The cat rig with new proportions: a bigger, rounder head, big rimmed
  /// ears and a thick ringed tail.
  redPanda(headScale: 1.08, legs: CompanionLegs.paws);

  const CompanionSpecies({
    required this.headScale,
    required this.legs,
    this.hairStyle = CompanionHairStyle.bun,
    this.bearded = false,
    this.aged = false,
    this.shoes = CompanionShoes.brogues,
    this.cuffedTrousers = false,
    this.lashes = true,
    this.masculine = false,
    this.stubble = false,
  });

  /// The head's size relative to the grandmother's.
  final double headScale;
  final CompanionLegs legs;

  /// The hair this character has until a person chooses another; an animal
  /// has fur and ignores it.
  final CompanionHairStyle hairStyle;

  /// A trimmed beard along the jaw and a moustache over the lip, in the
  /// hair's colour.
  final bool bearded;

  /// A face that has smiled for decades: laugh lines beside the mouth and
  /// under the eyes. A younger face has none, and fuller brows.
  final bool aged;

  /// What [CompanionLegs.trousers] stand in; the other legs ignore it.
  final CompanionShoes shoes;

  /// Trousers turned up at the hem, above the shoes.
  final bool cuffedTrousers;

  /// The two flicked lashes at each eye's outer corner, as Lotti and the
  /// aunt wear them; the lash line itself every human face has.
  final bool lashes;

  /// A man's face: a squarer jaw, straighter and heavier brows, and lips in
  /// the skin's own colour rather than a woman's rose.
  final bool masculine;

  /// A shadow of stubble along the jaw and over the lip.
  final bool stubble;

  bool get isAnimal => legs == CompanionLegs.paws;

  /// The characters a person can choose in settings: the humans, whose
  /// skin and hair the customization dresses.
  static List<CompanionSpecies> get choosable => [
    for (final species in values)
      if (!species.isAnimal) species,
  ];
}

/// What sits on the ears.
enum EarringKind {
  none,
  pearl,
  disc,

  /// A gold ring hanging from the lobe.
  hoop,
}

/// A named outfit: a palette plus the shapes that come and go with it.
@immutable
class CompanionLook {
  const CompanionLook({
    required this.id,
    required this.palette,
    this.species = CompanionSpecies.grandma,
    this.glasses = true,
    this.sunglasses = false,
    this.beret = false,
    this.beads = false,
    this.glove = false,
    this.earring = EarringKind.pearl,
    this.blush = 0.38,
    this.hairStyle = CompanionHairStyle.bun,
    this.readingGlasses = false,
    this.flatCap = false,
    this.headband = false,
    this.beanie = false,
  });

  /// Stable identifier, as stored when the look becomes a setting.
  final String id;
  final CompanionPalette palette;
  final CompanionSpecies species;

  /// Round tortoiseshell frames.
  final bool glasses;

  /// Square frames with dark lenses, worn in place of [glasses].
  final bool sunglasses;
  final bool beret;

  /// Two strands of big beads at the neckline.
  final bool beads;

  /// The right hand gloved.
  final bool glove;
  final EarringKind earring;

  /// Opacity of the cheeks' colour.
  final double blush;

  /// The grandmother's hair; an animal has fur and ears instead, and ignores
  /// it.
  final CompanionHairStyle hairStyle;

  /// Half-moon reading frames low on the nose, worn in place of [glasses].
  final bool readingGlasses;

  /// A flat cap, its peak over the brow.
  final bool flatCap;

  /// A wide band across the hair behind the hairline.
  final bool headband;

  /// A knitted beanie, its brim folded up over the brow, in the cap's
  /// colours.
  final bool beanie;

  /// This look with [palette] or [hairStyle] changed: an outfit dressed in a
  /// person's own choice of skin and hair.
  CompanionLook copyWith({
    CompanionPalette? palette,
    CompanionHairStyle? hairStyle,
  }) => CompanionLook(
    id: id,
    palette: palette ?? this.palette,
    species: species,
    glasses: glasses,
    sunglasses: sunglasses,
    beret: beret,
    beads: beads,
    glove: glove,
    earring: earring,
    blush: blush,
    hairStyle: hairStyle ?? this.hairStyle,
    readingGlasses: readingGlasses,
    flatCap: flatCap,
    headband: headband,
    beanie: beanie,
  );

  /// Lotti, the grandmother the app is named after: silver bun, glasses, a
  /// teal dress under a mustard cardigan, a small raspberry scarf.
  static const grandma = CompanionLook(
    id: 'grandma',
    palette: CompanionPalette(),
  );

  /// Her keynote outfit: a raspberry dress under an ivory cardigan, a teal
  /// scarf and navy shoes.
  static const grandmaStage = CompanionLook(
    id: 'grandma_stage',
    palette: CompanionPalette(
      dress: Color(0xFFB8336A),
      dressShade: Color(0xFF8F2651),
      dressLight: Color(0xFFD04A82),
      cardigan: Color(0xFFEFE6D6),
      cardiganShade: Color(0xFFCDBFA8),
      cardiganLight: Color(0xFFFAF5EA),
      scarf: Color(0xFF1F7F8A),
      shoe: Color(0xFF1F2A44),
      shoeShade: Color(0xFF121A2C),
    ),
  );

  /// The rock finale: beret, square yellow sunglasses, red lips, beads, a red
  /// glove and a yellow top.
  static const grandmaRock = CompanionLook(
    id: 'grandma_rock',
    palette: CompanionPalette(
      dress: Color(0xFFF1D04A),
      dressShade: Color(0xFFD4AC2A),
      dressLight: Color(0xFFF8E37C),
      cardigan: Color(0xFFF6DD62),
      cardiganShade: Color(0xFFD9B83A),
      cardiganLight: Color(0xFFFFF0A0),
      scarf: Color(0xFFD8322C),
      scarfDot: Color(0xFFD8322C),
      lips: Color(0xFFD1262A),
      lipsUpper: Color(0xFFA81C20),
      lipsLight: Color(0xFFEA5A5A),
      glasses: Color(0xFFE9C23A),
      glassesLight: Color(0xFFF8E58A),
      shoe: Color(0xFFF4F1EA),
      shoeShade: Color(0xFFCFCAC0),
    ),
    glasses: false,
    sunglasses: true,
    beret: true,
    beads: true,
    glove: true,
    earring: EarringKind.disc,
    blush: 0.3,
  );

  /// Off to the garden: a sage dress under a straw cardigan, a coral scarf
  /// and brown shoes.
  static const grandmaGarden = CompanionLook(
    id: 'grandma_garden',
    palette: CompanionPalette(
      dress: Color(0xFF7A9A6B),
      dressShade: Color(0xFF5F7D52),
      dressLight: Color(0xFF97B588),
      cardigan: Color(0xFFE8D9B0),
      cardiganShade: Color(0xFFC9B88C),
      cardiganLight: Color(0xFFF4EAD0),
      scarf: Color(0xFFE07A5F),
      shoe: Color(0xFF6B4A2E),
      shoeShade: Color(0xFF4A321E),
    ),
  );

  /// Sunday best: a lavender dress under a dove-grey cardigan, a teal scarf
  /// and plum shoes.
  static const grandmaLavender = CompanionLook(
    id: 'grandma_lavender',
    palette: CompanionPalette(
      dress: Color(0xFF8E7CC3),
      dressShade: Color(0xFF6F5FA3),
      dressLight: Color(0xFFAA9BD6),
      cardigan: Color(0xFFD8D5DE),
      cardiganShade: Color(0xFFB6B2BF),
      cardiganLight: Color(0xFFECEAF0),
      scarf: Color(0xFF1F7F8A),
      shoe: Color(0xFF4A2545),
      shoeShade: Color(0xFF301830),
    ),
  );

  /// Wrapped up for winter: a navy dress under a red cardigan, a cream scarf
  /// with red dots and black shoes.
  static const grandmaWinter = CompanionLook(
    id: 'grandma_winter',
    palette: CompanionPalette(
      dress: Color(0xFF27375E),
      dressShade: Color(0xFF1B2745),
      dressLight: Color(0xFF3A4D7D),
      cardigan: Color(0xFFC0392B),
      cardiganShade: Color(0xFF962D22),
      cardiganLight: Color(0xFFD9574A),
      scarf: Color(0xFFF3EBDD),
      scarfDot: Color(0xFFC0392B),
      shoe: Color(0xFF2A2A2E),
      shoeShade: Color(0xFF18181B),
    ),
  );

  /// The grandpa every day: a pale blue shirt with its sleeves rolled, rust
  /// braces, a plum bow tie, charcoal trousers, tan brogues and gold
  /// half-moon readers.
  static const grandpa = CompanionLook(
    id: 'grandpa',
    species: CompanionSpecies.grandpa,
    palette: CompanionPalette(
      glasses: Color(0xFFB08A3E),
      glassesLight: Color(0xFFD8B866),
      shoe: Color(0xFF9A6234),
      shoeShade: Color(0xFF6E4322),
    ),
    glasses: false,
    readingGlasses: true,
    earring: EarringKind.none,
    blush: 0.08,
    hairStyle: CompanionHairStyle.short,
  );

  /// A night at the jazz club: a black shirt, ivory trousers, silver braces,
  /// a cobalt bow tie and white shoes.
  static const grandpaJazz = CompanionLook(
    id: 'grandpa_jazz',
    species: CompanionSpecies.grandpa,
    palette: CompanionPalette(
      shirt: Color(0xFF2A2A30),
      shirtShade: Color(0xFF18181C),
      shirtLight: Color(0xFF43434C),
      trousers: Color(0xFFE9E2D2),
      trousersShade: Color(0xFFC6BCA6),
      trousersLight: Color(0xFFF7F2E7),
      braces: Color(0xFFB9BCC4),
      bowTie: Color(0xFF2747B8),
      bowTieShade: Color(0xFF1A3184),
      glasses: Color(0xFF1E1E22),
      glassesLight: Color(0xFF55555E),
      shoe: Color(0xFFF2EFE8),
      shoeShade: Color(0xFFCFCAC0),
    ),
    glasses: false,
    readingGlasses: true,
    earring: EarringKind.none,
    blush: 0.08,
    hairStyle: CompanionHairStyle.short,
  );

  /// A day by the sea: a peach shirt, white trousers, cornflower braces and
  /// bow tie, and sand suede shoes.
  static const grandpaSeaside = CompanionLook(
    id: 'grandpa_seaside',
    species: CompanionSpecies.grandpa,
    palette: CompanionPalette(
      shirt: Color(0xFFF2C2A2),
      shirtShade: Color(0xFFD9A383),
      shirtLight: Color(0xFFF8D9C4),
      trousers: Color(0xFFF1EFEA),
      trousersShade: Color(0xFFD3CFC6),
      trousersLight: Color(0xFFFFFFFF),
      braces: Color(0xFF6A8FD6),
      bowTie: Color(0xFF4A6DB5),
      bowTieShade: Color(0xFF35528C),
      shoe: Color(0xFFC9A877),
      shoeShade: Color(0xFFA88956),
    ),
    glasses: false,
    readingGlasses: true,
    earring: EarringKind.none,
    blush: 0.08,
    hairStyle: CompanionHairStyle.short,
  );

  /// Market day: a heather flat cap, an olive shirt, chestnut trousers,
  /// oxblood braces, a slate bow tie and dark brown brogues.
  static const grandpaMarket = CompanionLook(
    id: 'grandpa_market',
    species: CompanionSpecies.grandpa,
    palette: CompanionPalette(
      shirt: Color(0xFF7D7F45),
      shirtShade: Color(0xFF62643A),
      shirtLight: Color(0xFF999B5E),
      trousers: Color(0xFF6E4630),
      trousersShade: Color(0xFF52331F),
      trousersLight: Color(0xFF8A5C42),
      braces: Color(0xFF7A2430),
      bowTie: Color(0xFF56708A),
      bowTieShade: Color(0xFF3F5468),
      shoe: Color(0xFF4A3020),
      shoeShade: Color(0xFF2F1E14),
    ),
    glasses: false,
    readingGlasses: true,
    flatCap: true,
    earring: EarringKind.none,
    blush: 0.08,
    hairStyle: CompanionHairStyle.short,
  );

  /// The aunt every day: a denim-blue boiler suit, a cognac belt, white
  /// high-tops and gold hoops.
  static const aunt = CompanionLook(
    id: 'aunt',
    species: CompanionSpecies.aunt,
    palette: CompanionPalette(
      trousers: Color(0xFF4A6A8C),
      trousersShade: Color(0xFF37516D),
      trousersLight: Color(0xFF6688AB),
      shoe: Color(0xFFF3F1EC),
      shoeShade: Color(0xFFCFCBC2),
      earring: _gold,
    ),
    glasses: false,
    earring: EarringKind.hoop,
    blush: 0.3,
    hairStyle: CompanionHairStyle.bob,
  );

  /// In the studio: a blush-pink boiler suit, a black belt and black
  /// high-tops.
  static const auntStudio = CompanionLook(
    id: 'aunt_studio',
    species: CompanionSpecies.aunt,
    palette: CompanionPalette(
      trousers: Color(0xFFE7A9A0),
      trousersShade: Color(0xFFCB8B82),
      trousersLight: Color(0xFFF3C6BF),
      belt: Color(0xFF2A2A2E),
      shoe: Color(0xFF2B2B30),
      shoeShade: Color(0xFF18181B),
      earring: _gold,
    ),
    glasses: false,
    earring: EarringKind.hoop,
    blush: 0.3,
    hairStyle: CompanionHairStyle.bob,
  );

  /// Off to a festival: a tangerine boiler suit, a cream belt, lilac
  /// high-tops and a turquoise headband.
  static const auntFestival = CompanionLook(
    id: 'aunt_festival',
    species: CompanionSpecies.aunt,
    palette: CompanionPalette(
      trousers: Color(0xFFE9813A),
      trousersShade: Color(0xFFC9662A),
      trousersLight: Color(0xFFF5A066),
      belt: Color(0xFFEDE3CF),
      shoe: Color(0xFFB9A6E0),
      shoeShade: Color(0xFF9682C4),
      earring: _gold,
    ),
    glasses: false,
    earring: EarringKind.hoop,
    headband: true,
    blush: 0.32,
    hairStyle: CompanionHairStyle.bob,
  );

  /// A weekend: a brick-red boiler suit, a black belt and cream high-tops.
  static const auntWeekend = CompanionLook(
    id: 'aunt_weekend',
    species: CompanionSpecies.aunt,
    palette: CompanionPalette(
      trousers: Color(0xFF9E3B32),
      trousersShade: Color(0xFF7B2C25),
      trousersLight: Color(0xFFBA5A50),
      belt: Color(0xFF2A2A2E),
      shoe: Color(0xFFEFE6D4),
      shoeShade: Color(0xFFCDBFA6),
      earring: _gold,
    ),
    glasses: false,
    earring: EarringKind.hoop,
    blush: 0.3,
    hairStyle: CompanionHairStyle.bob,
  );

  /// The uncle every day: a black bomber over a white tee, stone chinos,
  /// brown boots and silver headphones.
  static const uncle = CompanionLook(
    id: 'uncle',
    species: CompanionSpecies.uncle,
    palette: CompanionPalette(
      shirt: Color(0xFFF2F2F0),
      shirtShade: Color(0xFFD9D9D5),
      shirtLight: Color(0xFFFFFFFF),
      trousers: Color(0xFFC7B79A),
      trousersShade: Color(0xFFAA9A7D),
      trousersLight: Color(0xFFDDD0B6),
      shoe: Color(0xFF5A3A24),
      shoeShade: Color(0xFF3A2416),
    ),
    glasses: false,
    earring: EarringKind.none,
    blush: 0.05,
    hairStyle: CompanionHairStyle.curls,
  );

  /// A night out: an emerald bomber over a black tee, navy-grey chinos and
  /// black boots.
  static const uncleNight = CompanionLook(
    id: 'uncle_night',
    species: CompanionSpecies.uncle,
    palette: CompanionPalette(
      jacket: Color(0xFF1E6E52),
      jacketShade: Color(0xFF155540),
      jacketLight: Color(0xFF2C8A69),
      rib: Color(0xFF1C1C20),
      shirt: Color(0xFF1C1C20),
      shirtShade: Color(0xFF111114),
      shirtLight: Color(0xFF2C2C32),
      trousers: Color(0xFF2F3A4A),
      trousersShade: Color(0xFF222B37),
      trousersLight: Color(0xFF43506A),
      shoe: Color(0xFF1E1E22),
      shoeShade: Color(0xFF0F0F12),
      headphones: Color(0xFF1E1E22),
    ),
    glasses: false,
    earring: EarringKind.none,
    blush: 0.05,
    hairStyle: CompanionHairStyle.curls,
  );

  /// The skate park: a cherry-red bomber with white ribbing over a grey
  /// tee, khaki chinos, tan suede boots and white headphones.
  static const uncleSkate = CompanionLook(
    id: 'uncle_skate',
    species: CompanionSpecies.uncle,
    palette: CompanionPalette(
      jacket: Color(0xFFB3242E),
      jacketShade: Color(0xFF8C1A22),
      jacketLight: Color(0xFFCC3C45),
      rib: Color(0xFFF2F2F0),
      shirt: Color(0xFF9A9CA2),
      shirtShade: Color(0xFF7E8086),
      shirtLight: Color(0xFFB6B8BD),
      trousers: Color(0xFFB59F72),
      trousersShade: Color(0xFF967F55),
      trousersLight: Color(0xFFCDBA90),
      shoe: Color(0xFFC9A06A),
      shoeShade: Color(0xFFA47F4F),
      headphones: Color(0xFFF2F2F0),
    ),
    glasses: false,
    earring: EarringKind.none,
    blush: 0.05,
    hairStyle: CompanionHairStyle.curls,
  );

  /// A snow day: a plum bomber over an oatmeal tee, a rust beanie, taupe
  /// chinos and dark boots.
  static const uncleSnow = CompanionLook(
    id: 'uncle_snow',
    species: CompanionSpecies.uncle,
    palette: CompanionPalette(
      jacket: Color(0xFF5A2E58),
      jacketShade: Color(0xFF40203E),
      jacketLight: Color(0xFF744072),
      rib: Color(0xFFD8D2C4),
      shirt: Color(0xFFE8DCC4),
      shirtShade: Color(0xFFCDBFA2),
      shirtLight: Color(0xFFF5ECD8),
      trousers: Color(0xFF4F4A44),
      trousersShade: Color(0xFF3A3632),
      trousersLight: Color(0xFF6A645C),
      shoe: Color(0xFF3B2A1F),
      shoeShade: Color(0xFF24190F),
      cap: Color(0xFFC7563A),
      capShade: Color(0xFFA2432C),
      headphones: Color(0xFF3B2A1F),
    ),
    glasses: false,
    earring: EarringKind.none,
    beanie: true,
    blush: 0.05,
    hairStyle: CompanionHairStyle.curls,
  );

  /// A silver tabby: green eyes, a white muzzle and white socks, in a navy
  /// dress under a coral cardigan with a mint scarf.
  static const cat = CompanionLook(
    id: 'cat',
    species: CompanionSpecies.cat,
    palette: _catPalette,
    glasses: false,
    earring: EarringKind.none,
    blush: 0.3,
  );

  /// The tabby at the rock finale: beret, red-framed sunglasses, beads and a
  /// red glove over a black outfit.
  static const catRock = CompanionLook(
    id: 'cat_rock',
    species: CompanionSpecies.cat,
    palette: CompanionPalette(
      skin: Color(0xFFA7A9AC),
      skinShade: Color(0xFF8A8C90),
      skinDeep: Color(0xFF66686D),
      skinLight: Color(0xFFC6C8CA),
      brow: Color(0xFF55575C),
      iris: Color(0xFF5E9A3E),
      irisLight: Color(0xFFB4D86A),
      pupil: Color(0xFF101410),
      eyeWhite: Color(0xFFF2F4E8),
      lips: Color(0xFFF5F2EC),
      lipsUpper: Color(0xFFF5F2EC),
      lipsLight: Color(0xFFF5F2EC),
      mouthIn: Color(0xFF5A2228),
      tongue: Color(0xFFE07C88),
      dress: Color(0xFF2A2A30),
      dressShade: Color(0xFF1A1A1F),
      dressLight: Color(0xFF3E3E46),
      cardigan: Color(0xFF3A3A42),
      cardiganShade: Color(0xFF24242A),
      cardiganLight: Color(0xFF55555F),
      scarf: Color(0xFFD8322C),
      scarfDot: Color(0xFFD8322C),
      glasses: Color(0xFFD8322C),
      glassesLight: Color(0xFFEE6A62),
      ink: Color(0xFF26282C),
      muzzle: Color(0xFFF5F2EC),
      earInner: Color(0xFFE8A9B0),
      furMark: Color(0xFF5B5D62),
      paw: Color(0xFFF5F2EC),
      nose: Color(0xFFD98C95),
      whisker: Color(0xFFF8F6F2),
      tailRing: Color(0xFF6A6C71),
    ),
    glasses: false,
    sunglasses: true,
    beret: true,
    beads: true,
    glove: true,
    earring: EarringKind.none,
    blush: 0.25,
  );

  /// A red panda: rust fur, a white mask with dark tear marks, dark legs
  /// and arms, in a cream dress under a forest-green cardigan.
  static const redPanda = CompanionLook(
    id: 'red_panda',
    species: CompanionSpecies.redPanda,
    palette: _redPandaPalette,
    glasses: false,
    earring: EarringKind.none,
    blush: 0.22,
  );

  /// The red panda with a book under its arm, so to speak: round glasses, a
  /// teal dress under an ivory cardigan and a raspberry scarf.
  static const redPandaBookish = CompanionLook(
    id: 'red_panda_bookish',
    species: CompanionSpecies.redPanda,
    palette: CompanionPalette(
      skin: Color(0xFFC4562A),
      skinShade: Color(0xFFA4441F),
      skinDeep: Color(0xFF7E3215),
      skinLight: Color(0xFFDB7A48),
      brow: Color(0xFFF7F0E4),
      iris: Color(0xFF3A2216),
      irisLight: Color(0xFF7A4A30),
      pupil: Color(0xFF0E0806),
      eyeWhite: Color(0xFFF4EEE4),
      lips: Color(0xFFF7F0E4),
      lipsUpper: Color(0xFFF7F0E4),
      lipsLight: Color(0xFFF7F0E4),
      mouthIn: Color(0xFF4A1A12),
      tongue: Color(0xFFD86A6E),
      cardigan: Color(0xFFEFE6D6),
      cardiganShade: Color(0xFFCDBFA8),
      cardiganLight: Color(0xFFFAF5EA),
      scarf: Color(0xFFB8336A),
      ink: Color(0xFF241510),
      muzzle: Color(0xFFF7F0E4),
      earInner: Color(0xFF5A2A18),
      furMark: Color(0xFF6E2814),
      limb: Color(0xFF3A1F16),
      limbDeep: Color(0xFF22120C),
      nose: Color(0xFF231511),
      whisker: Color(0xFFF7F0E4),
      tail: Color(0xFFC4562A),
      tailRing: Color(0xFF8A3418),
    ),
    earring: EarringKind.none,
    blush: 0.22,
  );

  static const List<CompanionLook> all = [
    grandma,
    grandmaStage,
    grandmaRock,
    grandmaGarden,
    grandmaLavender,
    grandmaWinter,
    grandpa,
    grandpaJazz,
    grandpaSeaside,
    grandpaMarket,
    aunt,
    auntStudio,
    auntFestival,
    auntWeekend,
    uncle,
    uncleNight,
    uncleSkate,
    uncleSnow,
    cat,
    catRock,
    redPanda,
    redPandaBookish,
  ];

  /// The looks of [species], in the order of [all].
  static List<CompanionLook> of(CompanionSpecies species) => [
    for (final look in all)
      if (look.species == species) look,
  ];
}

/// The aunt's gold hoops.
const _gold = Color(0xFFD4A637);

/// The silver tabby. The lips take the muzzle's colour, so only the mouth's
/// opening and seam show, the way a cat's mouth does.
const _catPalette = CompanionPalette(
  skin: Color(0xFFA7A9AC),
  skinShade: Color(0xFF8A8C90),
  skinDeep: Color(0xFF66686D),
  skinLight: Color(0xFFC6C8CA),
  brow: Color(0xFF55575C),
  iris: Color(0xFF5E9A3E),
  irisLight: Color(0xFFB4D86A),
  pupil: Color(0xFF101410),
  eyeWhite: Color(0xFFF2F4E8),
  lips: Color(0xFFF5F2EC),
  lipsUpper: Color(0xFFF5F2EC),
  lipsLight: Color(0xFFF5F2EC),
  mouthIn: Color(0xFF5A2228),
  tongue: Color(0xFFE07C88),
  dress: Color(0xFF2E3F66),
  dressShade: Color(0xFF22304F),
  dressLight: Color(0xFF41568A),
  cardigan: Color(0xFFE07A5F),
  cardiganShade: Color(0xFFC15E45),
  cardiganLight: Color(0xFFF09A80),
  scarf: Color(0xFF7CC6B0),
  scarfDot: Color(0xFFF6F2E8),
  ink: Color(0xFF26282C),
  muzzle: Color(0xFFF5F2EC),
  earInner: Color(0xFFE8A9B0),
  furMark: Color(0xFF5B5D62),
  paw: Color(0xFFF5F2EC),
  nose: Color(0xFFD98C95),
  whisker: Color(0xFFF8F6F2),
  tailRing: Color(0xFF6A6C71),
);

/// The red panda. Its brows are the white spots above its eyes.
const _redPandaPalette = CompanionPalette(
  skin: Color(0xFFC4562A),
  skinShade: Color(0xFFA4441F),
  skinDeep: Color(0xFF7E3215),
  skinLight: Color(0xFFDB7A48),
  brow: Color(0xFFF7F0E4),
  iris: Color(0xFF3A2216),
  irisLight: Color(0xFF7A4A30),
  pupil: Color(0xFF0E0806),
  eyeWhite: Color(0xFFF4EEE4),
  lips: Color(0xFFF7F0E4),
  lipsUpper: Color(0xFFF7F0E4),
  lipsLight: Color(0xFFF7F0E4),
  mouthIn: Color(0xFF4A1A12),
  tongue: Color(0xFFD86A6E),
  dress: Color(0xFFEDE3CF),
  dressShade: Color(0xFFD3C6AC),
  dressLight: Color(0xFFF8F1E2),
  cardigan: Color(0xFF2F6B4F),
  cardiganShade: Color(0xFF22513B),
  cardiganLight: Color(0xFF468A69),
  scarf: Color(0xFFE0A526),
  ink: Color(0xFF241510),
  muzzle: Color(0xFFF7F0E4),
  earInner: Color(0xFF5A2A18),
  furMark: Color(0xFF6E2814),
  limb: Color(0xFF3A1F16),
  limbDeep: Color(0xFF22120C),
  nose: Color(0xFF231511),
  whisker: Color(0xFFF7F0E4),
  tail: Color(0xFFC4562A),
  tailRing: Color(0xFF8A3418),
);
