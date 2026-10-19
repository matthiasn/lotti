import 'dart:ui';

/// The parts a person puts her together from. Every part combines with every
/// other: no hairstyle or colour belongs to a skin tone, and no part is named
/// after a people (plan 2026-10-12, "Revision"). They are illustration
/// colours, like the rest of her, not interface colours.

/// Her hair's shape: the bun of the pitch videos, and the styles a person may
/// give her instead.
enum CompanionHairStyle {
  /// A soft low bun behind the left of her neck, waves swept back.
  bun,

  /// Short, tight curls close to the head.
  curls,

  /// A full, round afro.
  afro,

  /// Locs to below the shoulders, the ends swinging as she moves.
  locs,

  /// A chin-length bob with a straight fringe.
  bob,
}

/// Her skin, light to deep. Numbered rather than named: the picker shows a
/// swatch, and a screen reader says "Skin tone 3".
enum CompanionSkinTone {
  tone1(
    skin: Color(0xFFF1D2BD),
    shade: Color(0xFFD9B39B),
    deep: Color(0xFFC0957C),
    light: Color(0xFFF9E3D2),
  ),
  tone2(
    skin: Color(0xFFE6BC98),
    shade: Color(0xFFCF9F7C),
    deep: Color(0xFFB38262),
    light: Color(0xFFF2D3B6),
  ),
  tone3(
    skin: Color(0xFFD19C72),
    shade: Color(0xFFB88159),
    deep: Color(0xFF9B6644),
    light: Color(0xFFE3B994),
  ),
  tone4(
    skin: Color(0xFFB47A50),
    shade: Color(0xFF9A623C),
    deep: Color(0xFF7E4C2C),
    light: Color(0xFFC99670),
    lips: Color(0xFFB5585C),
    lipsUpper: Color(0xFF9C4A4E),
    lipsLight: Color(0xFFCF8085),
  ),
  tone5(
    skin: Color(0xFF8D5A3A),
    shade: Color(0xFF754829),
    deep: Color(0xFF5C3520),
    light: Color(0xFFA87552),
    lips: Color(0xFF9E4D4F),
    lipsUpper: Color(0xFF844043),
    lipsLight: Color(0xFFBA6E70),
  ),
  tone6(
    skin: Color(0xFF5E3B26),
    shade: Color(0xFF4C2E1C),
    deep: Color(0xFF3A2114),
    light: Color(0xFF7A5238),
    lips: Color(0xFF7E3C3E),
    lipsUpper: Color(0xFF6A3133),
    lipsLight: Color(0xFF9C5A5C),
  );

  const CompanionSkinTone({
    required this.skin,
    required this.shade,
    required this.deep,
    required this.light,
    this.lips,
    this.lipsUpper,
    this.lipsLight,
  });

  final Color skin;
  final Color shade;
  final Color deep;
  final Color light;

  /// Lips a touch deeper on the deeper tones, so they still read as lips;
  /// null keeps the outfit's.
  final Color? lips;
  final Color? lipsUpper;
  final Color? lipsLight;
}

/// Her hair's colour, the greys a grandmother grows into and the colours
/// she might dye it.
enum CompanionHairColour {
  silver(
    hair: Color(0xFFD9D6D1),
    back: Color(0xFFB9B5B0),
    shade: Color(0xFFA39E98),
    light: Color(0xFFF4F2EE),
    brow: Color(0xFF8E8780),
  ),
  white(
    hair: Color(0xFFF2F0EC),
    back: Color(0xFFD9D6D0),
    shade: Color(0xFFC4C0B9),
    light: Color(0xFFFFFFFF),
    brow: Color(0xFFA8A39C),
  ),
  grey(
    hair: Color(0xFF9E9A96),
    back: Color(0xFF7E7A76),
    shade: Color(0xFF6A6662),
    light: Color(0xFFBDB9B5),
    brow: Color(0xFF6A6560),
  ),
  black(
    hair: Color(0xFF2E2A28),
    back: Color(0xFF1F1C1A),
    shade: Color(0xFF141210),
    light: Color(0xFF4A4542),
    brow: Color(0xFF26221F),
  ),
  brown(
    hair: Color(0xFF6B4A35),
    back: Color(0xFF523726),
    shade: Color(0xFF3F2A1C),
    light: Color(0xFF8A654B),
    brow: Color(0xFF4A3324),
  ),
  auburn(
    hair: Color(0xFFA65A35),
    back: Color(0xFF85452A),
    shade: Color(0xFF6B361F),
    light: Color(0xFFC47A55),
    brow: Color(0xFF6E3A22),
  ),
  pink(
    hair: Color(0xFFE58FB4),
    back: Color(0xFFC9739A),
    shade: Color(0xFFB05E84),
    light: Color(0xFFF5B8D2),
    brow: Color(0xFFB86A8C),
  ),
  lavender(
    hair: Color(0xFFA68FD8),
    back: Color(0xFF8A72BD),
    shade: Color(0xFF7460A5),
    light: Color(0xFFC5B4EC),
    brow: Color(0xFF7A66A8),
  ),
  blue(
    hair: Color(0xFF6FA8DC),
    back: Color(0xFF5089C0),
    shade: Color(0xFF3E73A6),
    light: Color(0xFF9CC6EC),
    brow: Color(0xFF4E7AA3),
  );

  const CompanionHairColour({
    required this.hair,
    required this.back,
    required this.shade,
    required this.light,
    required this.brow,
  });

  final Color hair;

  /// The hair behind the head, a shade darker than [hair].
  final Color back;
  final Color shade;
  final Color light;
  final Color brow;
}
