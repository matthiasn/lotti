/// Emoji and the invisible characters that build them: pictographs (which
/// include ©, ® and ™), skin-tone modifiers, flag letters, the zero-width
/// joiner, variation selectors, the keycap mark and tag characters.
final _emoji = RegExp(
  r'[\p{Extended_Pictographic}\p{Emoji_Modifier}\p{Regional_Indicator}'
  r'\u{200D}\u{FE0E}\u{FE0F}\u{20E3}\u{E0020}-\u{E007F}]',
  unicode: true,
);

/// [text] as a voice should get it: without emoji, which a voice turns into
/// stray, garbled sounds.
///
/// The space an emoji leaves is tidied up — no doubled spaces, none before a
/// punctuation mark, none at the ends of a line — while line breaks stay, as
/// paragraph breaks decide where a voice pauses. A keycap's digit stays
/// ("1️⃣" says "1"). The words the screen shows, and the copy the companion
/// reads her tone from, keep their emoji; only what is spoken loses them.
String withoutEmoji(String text) {
  if (!_emoji.hasMatch(text)) return text;
  return text
      .replaceAll(_emoji, '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAllMapped(RegExp(r'[ \t]+([,.;:!?…])'), (m) => m[1]!)
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .trim();
}
