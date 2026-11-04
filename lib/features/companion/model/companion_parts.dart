import 'dart:ui';

/// The parts a person puts a character together from. Every part combines
/// with every other, and with every human character: no hairstyle or colour
/// belongs to a skin tone or to one character, and no part is named after a
/// people (plan 2026-10-12, "Revision"). They are illustration colours, like
/// the rest of the character, not interface colours.

/// The hair's shape: Lotti's bun of the pitch videos, the grandpa's short
/// cut, and the styles a person may give either instead.
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

  /// Short and neat, parted at the side, clear of the ears.
  short,

  /// A bare crown with a fringe of hair round the back and over the ears.
  balding,

  /// Straight, parted in the middle, falling past the shoulders.
  long,

  /// Soft waves to the shoulders, parted on the left, a fringe swept across.
  waves,

  /// Pulled back smooth into a tail that swings behind.
  ponytail,
}

/// Her skin, light to deep. Numbered rather than named: the picker shows a
/// swatch, and a screen reader says "Skin tone 3".
enum CompanionSkinTone {
  tone1(
    eyes: CompanionEyeColour.blue,
    skin: Color(0xFFF1D2BD),
    shade: Color(0xFFD9B39B),
    deep: Color(0xFFC0957C),
    light: Color(0xFFF9E3D2),
  ),
  tone2(
    eyes: CompanionEyeColour.hazel,
    skin: Color(0xFFE6BC98),
    shade: Color(0xFFCF9F7C),
    deep: Color(0xFFB38262),
    light: Color(0xFFF2D3B6),
  ),
  tone3(
    eyes: CompanionEyeColour.brown,
    skin: Color(0xFFD19C72),
    shade: Color(0xFFB88159),
    deep: Color(0xFF9B6644),
    light: Color(0xFFE3B994),
  ),
  tone4(
    eyes: CompanionEyeColour.brown,
    skin: Color(0xFFB47A50),
    shade: Color(0xFF9A623C),
    deep: Color(0xFF7E4C2C),
    light: Color(0xFFC99670),
    lips: Color(0xFFB5585C),
    lipsUpper: Color(0xFF9C4A4E),
    lipsLight: Color(0xFFCF8085),
  ),
  tone5(
    eyes: CompanionEyeColour.darkBrown,
    skin: Color(0xFF8D5A3A),
    shade: Color(0xFF754829),
    deep: Color(0xFF5C3520),
    light: Color(0xFFA87552),
    lips: Color(0xFF9E4D4F),
    lipsUpper: Color(0xFF844043),
    lipsLight: Color(0xFFBA6E70),
  ),
  tone6(
    eyes: CompanionEyeColour.darkBrown,
    skin: Color(0xFF5E3B26),
    shade: Color(0xFF4C2E1C),
    deep: Color(0xFF3A2114),
    light: Color(0xFF7A5238),
    lips: Color(0xFF7E3C3E),
    lipsUpper: Color(0xFF6A3133),
    lipsLight: Color(0xFF9C5A5C),
  ),

  /// The deepest: added after the six, so a stored tone keeps its number.
  tone7(
    eyes: CompanionEyeColour.darkBrown,
    skin: Color(0xFF452A19),
    shade: Color(0xFF382114),
    deep: Color(0xFF29170C),
    light: Color(0xFF5E3D29),
    lips: Color(0xFF6E3638),
    lipsUpper: Color(0xFF5C2C2E),
    lipsLight: Color(0xFF8A4E50),
  );

  const CompanionSkinTone({
    required this.eyes,
    required this.skin,
    required this.shade,
    required this.deep,
    required this.light,
    this.lips,
    this.lipsUpper,
    this.lipsLight,
  });

  /// The eyes this skin has until a person picks others: the colours eyes
  /// most often are beside it, so a deep tone is not left with blue ones.
  /// Lotti's own, the first tone's, stay the blue of the pitch videos.
  final CompanionEyeColour eyes;

  final Color skin;
  final Color shade;
  final Color deep;
  final Color light;

  /// A man's lips on this skin: its own colour, a little deeper and warmer,
  /// never a woman's rose — the upper lip in shade, the lit lower lip close
  /// to the skin.
  ({Color lips, Color upper, Color light}) get naturalLips => (
    lips: Color.lerp(Color.lerp(shade, deep, 0.35), _lipWarmth, 0.18)!,
    upper: Color.lerp(Color.lerp(shade, deep, 0.7), _lipWarmth, 0.12)!,
    light: Color.lerp(skin, _lipWarmth, 0.15)!,
  );

  /// Lips a touch deeper on the deeper tones, so they still read as lips;
  /// null keeps the outfit's.
  final Color? lips;
  final Color? lipsUpper;
  final Color? lipsLight;
}

/// The warm red a man's lips take a little of.
const _lipWarmth = Color(0xFFA0524C);

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

/// The eyes' colour: the browns most eyes are, hazel and amber between them
/// and the lighter ones, and green, grey and blue. Every colour goes with
/// every skin tone; each tone also has one it matches by default
/// ([CompanionSkinTone.eyes]).
enum CompanionEyeColour {
  darkBrown(iris: Color(0xFF3B2416), light: Color(0xFF6A4630)),
  brown(iris: Color(0xFF5C3A21), light: Color(0xFF8E6440)),
  hazel(iris: Color(0xFF7A6A35), light: Color(0xFFA89A5A)),
  amber(iris: Color(0xFF9C6A1E), light: Color(0xFFC99A45)),
  green(iris: Color(0xFF4E7A45), light: Color(0xFF86AE6C)),
  grey(iris: Color(0xFF6F7E88), light: Color(0xFFA5B3BC)),

  /// The pitch videos' blue, Lotti's own.
  blue(iris: Color(0xFF4A6F8F), light: Color(0xFF7EA2C0));

  const CompanionEyeColour({required this.iris, required this.light});

  /// The iris, and the lit side of it.
  final Color iris;
  final Color light;
}
