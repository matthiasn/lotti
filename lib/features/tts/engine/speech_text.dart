/// The code points an emoji is made of, as inclusive ranges: the pictographs
/// of Unicode's emoji data (which include ©, ® and ™, the misc-symbol and
/// dingbat blocks, and every plane-1 emoji block with its skin-tone modifiers
/// and flag letters), and the invisible characters that build sequences —
/// the zero-width joiner, variation selectors, the keycap mark and tag
/// characters.
///
/// Plain ranges, not regex property escapes, so the check is the same on
/// every platform the app runs on.
const _emojiRanges = <(int, int)>[
  (0x00A9, 0x00A9),
  (0x00AE, 0x00AE),
  (0x200D, 0x200D),
  (0x203C, 0x203C),
  (0x2049, 0x2049),
  (0x20E3, 0x20E3),
  (0x2122, 0x2122),
  (0x2139, 0x2139),
  (0x2194, 0x2199),
  (0x21A9, 0x21AA),
  (0x231A, 0x231B),
  (0x2328, 0x2328),
  (0x2388, 0x2388),
  (0x23CF, 0x23CF),
  (0x23E9, 0x23F3),
  (0x23F8, 0x23FA),
  (0x24C2, 0x24C2),
  (0x25AA, 0x25AB),
  (0x25B6, 0x25B6),
  (0x25C0, 0x25C0),
  (0x25FB, 0x25FE),
  (0x2600, 0x27BF),
  (0x2934, 0x2935),
  (0x2B05, 0x2B07),
  (0x2B1B, 0x2B1C),
  (0x2B50, 0x2B50),
  (0x2B55, 0x2B55),
  (0x3030, 0x3030),
  (0x303D, 0x303D),
  (0x3297, 0x3297),
  (0x3299, 0x3299),
  (0xFE0E, 0xFE0F),
  (0x1F000, 0x1FAFF),
  (0x1FC00, 0x1FFFD),
  (0xE0020, 0xE007F),
];

bool _isEmoji(int codePoint) {
  // Ranges are sorted; most text is far below the first one.
  if (codePoint < 0xA9) return false;
  for (final (from, to) in _emojiRanges) {
    if (codePoint < from) return false;
    if (codePoint <= to) return true;
  }
  return false;
}

final _spaces = RegExp(r'[ \t]{2,}');
final _spaceBeforeMark = RegExp(r'[ \t]+([,.;:!?…])');
final _spaceAroundBreak = RegExp(r'[ \t]*\n[ \t]*');

/// [text] as a voice should get it: without emoji, which a voice turns into
/// stray, garbled sounds.
///
/// The space an emoji leaves is tidied up — no doubled spaces, none before a
/// punctuation mark, none at the ends of a line — while line breaks stay, as
/// paragraph breaks decide where a voice pauses. A keycap's digit stays
/// ("1️⃣" says "1"). The words the screen shows, and the copy the companion
/// reads her tone from, keep their emoji; only what is spoken loses them.
String withoutEmoji(String text) {
  if (!text.runes.any(_isEmoji)) return text;
  final kept = String.fromCharCodes(text.runes.where((r) => !_isEmoji(r)));
  return kept
      .replaceAll(_spaces, ' ')
      .replaceAllMapped(_spaceBeforeMark, (m) => m[1]!)
      .replaceAll(_spaceAroundBreak, '\n')
      .trim();
}

final _markdownImage = RegExp(r'!\[([^\]\n]*)\]\([^)\n]*\)');
final _markdownLink = RegExp(r'\[([^\]\n]*)\]\([^)\n]*\)');
final _strong = RegExp(r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1');
final _emphasis = RegExp(r'(?<![\w*])([*_])(?=\S)(.+?)(?<=\S)\1(?![\w*])');
final _inlineCode = RegExp('`([^`\n]*)`');
final _lineMarker = RegExp(
  r'^[ \t]*(?:#{1,6}[ \t]+|>[ \t]?|[-*+][ \t]+)',
  multiLine: true,
);

/// [text] as a voice should get it when it was written as Markdown: a link
/// or an image says its label, emphasis and code say their words, and the
/// markers that open a heading, a quote or a bullet are not read out.
///
/// Line breaks stay, as paragraph breaks decide where a voice pauses;
/// numbered items keep their numbers, which are words.
String withoutMarkdown(String text) => text
    .replaceAllMapped(_markdownImage, (m) => m[1]!)
    .replaceAllMapped(_markdownLink, (m) => m[1]!)
    .replaceAllMapped(_strong, (m) => m[2]!)
    .replaceAllMapped(_emphasis, (m) => m[2]!)
    .replaceAllMapped(_inlineCode, (m) => m[1]!)
    .replaceAll(_lineMarker, '');
