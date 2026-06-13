// Text preprocessing for the Supertonic on-device TTS engine.
//
// Faithfully ported from Supertone's open-source Supertonic Flutter example
// (github.com/supertone-inc/supertonic — MIT-licensed sample code) and adapted
// to this codebase's structure. The normalization here is intentionally kept
// 1:1 with upstream: the ONNX models were trained against exactly this
// preprocessing, so any divergence degrades synthesis quality.

/// Languages the Supertonic models accept. `na` is the language-agnostic mode.
const List<String> kSupertonicLangs = <String>[
  'en', 'ko', 'ja', 'ar', 'bg', 'cs', 'da', 'de', 'el', 'es', 'et', 'fi', //
  'fr', 'hi', 'hr', 'hu', 'id', 'it', 'lt', 'lv', 'nl', 'pl', 'pt', 'ro', //
  'ru', 'sk', 'sl', 'sv', 'tr', 'uk', 'vi', 'na', //
];

bool isValidSupertonicLang(String lang) => kSupertonicLangs.contains(lang);

// Hangul Jamo constants for NFKD decomposition.
const int _hangulSyllableBase = 0xAC00;
const int _hangulSyllableEnd = 0xD7A3;
const int _leadingJamoBase = 0x1100;
const int _vowelJamoBase = 0x1161;
const int _trailingJamoBase = 0x11A7;
const int _vowelCount = 21;
const int _trailingCount = 28;

/// Decomposes a Hangul syllable into Jamo (NFKD-like decomposition).
List<int> _decomposeHangulSyllable(int codePoint) {
  if (codePoint < _hangulSyllableBase || codePoint > _hangulSyllableEnd) {
    return [codePoint];
  }

  final syllableIndex = codePoint - _hangulSyllableBase;
  final leadingIndex = syllableIndex ~/ (_vowelCount * _trailingCount);
  final vowelIndex =
      (syllableIndex % (_vowelCount * _trailingCount)) ~/ _trailingCount;
  final trailingIndex = syllableIndex % _trailingCount;

  final result = <int>[
    _leadingJamoBase + leadingIndex,
    _vowelJamoBase + vowelIndex,
  ];

  if (trailingIndex > 0) {
    result.add(_trailingJamoBase + trailingIndex);
  }

  return result;
}

/// Common Latin character decompositions (NFKD) for es, pt, fr, de, …
const Map<int, List<int>> _latinDecompositions = <int, List<int>>{
  // Uppercase acute.
  0x00C1: [0x0041, 0x0301], 0x00C9: [0x0045, 0x0301],
  0x00CD: [0x0049, 0x0301], 0x00D3: [0x004F, 0x0301],
  0x00DA: [0x0055, 0x0301],
  // Lowercase acute.
  0x00E1: [0x0061, 0x0301], 0x00E9: [0x0065, 0x0301],
  0x00ED: [0x0069, 0x0301], 0x00F3: [0x006F, 0x0301],
  0x00FA: [0x0075, 0x0301],
  // Grave.
  0x00C0: [0x0041, 0x0300], 0x00C8: [0x0045, 0x0300],
  0x00CC: [0x0049, 0x0300], 0x00D2: [0x004F, 0x0300],
  0x00D9: [0x0055, 0x0300], 0x00E0: [0x0061, 0x0300],
  0x00E8: [0x0065, 0x0300], 0x00EC: [0x0069, 0x0300],
  0x00F2: [0x006F, 0x0300], 0x00F9: [0x0075, 0x0300],
  // Circumflex.
  0x00C2: [0x0041, 0x0302], 0x00CA: [0x0045, 0x0302],
  0x00CE: [0x0049, 0x0302], 0x00D4: [0x004F, 0x0302],
  0x00DB: [0x0055, 0x0302], 0x00E2: [0x0061, 0x0302],
  0x00EA: [0x0065, 0x0302], 0x00EE: [0x0069, 0x0302],
  0x00F4: [0x006F, 0x0302], 0x00FB: [0x0075, 0x0302],
  // Tilde.
  0x00C3: [0x0041, 0x0303], 0x00D1: [0x004E, 0x0303],
  0x00D5: [0x004F, 0x0303], 0x00E3: [0x0061, 0x0303],
  0x00F1: [0x006E, 0x0303], 0x00F5: [0x006F, 0x0303],
  // Diaeresis / umlaut.
  0x00C4: [0x0041, 0x0308], 0x00CB: [0x0045, 0x0308],
  0x00CF: [0x0049, 0x0308], 0x00D6: [0x004F, 0x0308],
  0x00DC: [0x0055, 0x0308], 0x00E4: [0x0061, 0x0308],
  0x00EB: [0x0065, 0x0308], 0x00EF: [0x0069, 0x0308],
  0x00F6: [0x006F, 0x0308], 0x00FC: [0x0075, 0x0308],
  // Cedilla.
  0x00C7: [0x0043, 0x0327], 0x00E7: [0x0063, 0x0327],
};

/// Applies NFKD-like decomposition (Hangul syllables → Jamo, accented Latin
/// → base + combining mark). Exposed for testing the normalization in
/// isolation.
String applyNfkdDecomposition(String text) {
  final result = <int>[];
  for (final codePoint in text.runes) {
    if (codePoint >= _hangulSyllableBase && codePoint <= _hangulSyllableEnd) {
      result.addAll(_decomposeHangulSyllable(codePoint));
    } else if (_latinDecompositions.containsKey(codePoint)) {
      result.addAll(_latinDecompositions[codePoint]!);
    } else {
      result.add(codePoint);
    }
  }
  return String.fromCharCodes(result);
}

/// Normalizes [text] and wraps it in language tags, ready for tokenization.
///
/// Throws [ArgumentError] when [lang] is not one of [kSupertonicLangs].
String preprocessText(String text, String lang) {
  var out = applyNfkdDecomposition(text);

  // Remove emojis.
  out = out.replaceAll(
    RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
      r'[\u{1F700}-\u{1F77F}]|[\u{1F780}-\u{1F7FF}]|[\u{1F800}-\u{1F8FF}]|'
      r'[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|'
      r'[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F1E6}-\u{1F1FF}]',
      unicode: true,
    ),
    '',
  );

  // Replace various dashes and symbols.
  const replacements = <String, String>{
    '–': '-',
    '‑': '-',
    '—': '-',
    '_': ' ',
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '´': "'",
    '`': "'",
    '[': ' ',
    ']': ' ',
    '|': ' ',
    '/': ' ',
    '#': ' ',
    '→': ' ',
    '←': ' ',
  };
  for (final entry in replacements.entries) {
    out = out.replaceAll(entry.key, entry.value);
  }

  // Remove special symbols.
  out = out.replaceAll(RegExp(r'[♥☆♡©\\]'), '');

  // Replace known expressions.
  out = out.replaceAll('@', ' at ');
  out = out.replaceAll('e.g.,', 'for example, ');
  out = out.replaceAll('i.e.,', 'that is, ');

  // Fix spacing around punctuation.
  out = out
      .replaceAll(' ,', ',')
      .replaceAll(' .', '.')
      .replaceAll(' !', '!')
      .replaceAll(' ?', '?')
      .replaceAll(' ;', ';')
      .replaceAll(' :', ':')
      .replaceAll(" '", "'");

  // Remove duplicate quotes.
  while (out.contains('""')) {
    out = out.replaceAll('""', '"');
  }
  while (out.contains("''")) {
    out = out.replaceAll("''", "'");
  }
  while (out.contains('``')) {
    out = out.replaceAll('``', '`');
  }

  // Collapse whitespace.
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Add a terminal period when the text doesn't already end in punctuation.
  if (out.isNotEmpty &&
      !RegExp(r'[.!?;:,\x27\x22‘’)\]}…。」』】〉》›»]$').hasMatch(out)) {
    out += '.';
  }

  if (!isValidSupertonicLang(lang)) {
    throw ArgumentError(
      'Invalid language: $lang. Available: ${kSupertonicLangs.join(", ")}',
    );
  }

  return '<$lang>$out</$lang>';
}
