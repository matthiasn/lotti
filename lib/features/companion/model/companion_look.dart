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
}

/// What sits on her ears.
enum EarringKind { pearl, disc }

/// A named outfit: a palette plus the shapes that come and go with it.
@immutable
class CompanionLook {
  const CompanionLook({
    required this.id,
    required this.palette,
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

  static const List<CompanionLook> all = [grandma, grandmaStage, grandmaRock];
}
