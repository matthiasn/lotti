import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Who the companion is dressed as: her colours, and the few switches that
/// differ between outfits.
///
/// These are the looks of the pitch videos' grandmother
/// (`tools/tutorial_videos/presenter/narrator/looks.py`), carried over as
/// data. They are illustration colours — the character's skin, hair and
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

  Color get limbColor => limb ?? skin;
  Color get limbDeepColor => limbDeep ?? skinDeep;
  Color get pawColor => paw ?? limbColor;
  Color get muzzleColor => muzzle ?? skinLight;
  Color get furMarkColor => furMark ?? skinDeep;
  Color get tailColor => tail ?? skin;
  Color get tailRingColor => tailRing ?? furMarkColor;
}

/// Who the companion is: each species is its own rig on the same skeleton.
/// The animals have ears, a muzzle and a tail where she has hair, a bun and
/// shoes.
enum CompanionSpecies {
  grandma(headScale: 1),

  /// Plain proportions, tall pointed ears and a thin tail.
  cat(headScale: 1.02),

  /// The cat rig with new proportions: a bigger, rounder head, big rimmed
  /// ears and a thick ringed tail.
  redPanda(headScale: 1.08);

  const CompanionSpecies({required this.headScale});

  /// The head's size relative to the grandmother's.
  final double headScale;

  bool get isAnimal => this != grandma;
}

/// What sits on her ears.
enum EarringKind { none, pearl, disc }

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
