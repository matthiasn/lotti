/// Corrects misheard proper names in a transcript against the terms the user
/// has told us to expect.
///
/// Transcription providers disagree on whether they honour a vocabulary hint:
/// Melious' Whisper endpoints accept the OpenAI `prompt` field and ignore it,
/// so a category speech dictionary alone never reaches the words. This runs
/// after the transcript arrives, on every provider alike.
///
/// A word is replaced by a known term only when all of these hold:
///
/// * it is capitalised in the transcript — a name, or in German any noun —
///   so ordinary lower-case words are never touched;
/// * it is not already a known term itself;
/// * it *sounds* the same: identical Kölner Phonetik codes, at least two
///   consonant classes long, so a code like "5" cannot match half the
///   language;
/// * it is *spelled* almost the same once sound-alike spellings are folded
///   (v/w, ck/k, y/i, ie/i, a silent h, doubled letters): at most one edit
///   for short words, a third of the length for longer ones;
/// * exactly one known term qualifies — an ambiguous match is left alone.
///
/// "Vanja" becomes "Wanja", "Frieda Kellsen" becomes "Frida Kjellsen"; "Weg"
/// does not become "Wiggo" although the two share a code, because their
/// spellings are too far apart.
library;

import 'dart:math' as math;

/// One word the corrector replaced: what the provider heard, and the known
/// term it became.
typedef TranscriptTermCorrection = ({String heard, String term});

/// A corrected transcript and the replacements that produced it, in
/// transcript order.
typedef TranscriptTermCorrectionResult = ({
  String text,
  List<TranscriptTermCorrection> corrections,
});

final _word = RegExp(r'\p{L}+', unicode: true);

/// Terms shorter than this are never used as a correction target: a short
/// name carries too little sound to tell it from an ordinary word.
const _minimumTermLength = 3;

/// [first] followed by [rest], trimmed, with blanks and case-insensitive
/// repeats dropped and the first spelling kept.
///
/// Providers that honour a vocabulary hint cap it (Melious and Mistral keep
/// the first 100 terms), so whatever the caller lists first survives the cap.
List<String> mergeSpeechTerms(Iterable<String> first, Iterable<String> rest) {
  final seen = <String>{};
  return [
    for (final term in [...first, ...rest])
      if (term.trim() case final trimmed
          when trimmed.isNotEmpty && seen.add(trimmed.toLowerCase()))
        trimmed,
  ];
}

/// Replaces misheard occurrences of [terms] in [transcript].
///
/// Multi-word terms contribute each of their words, so "Frida Kjellsen" corrects
/// the first and the last name independently. The replacement is the term's
/// own spelling. Returns the transcript unchanged, with no corrections, when
/// nothing qualifies.
TranscriptTermCorrectionResult correctTranscriptTerms(
  String transcript,
  Iterable<String> terms,
) {
  final known = <String, String>{};
  for (final term in terms) {
    for (final match in _word.allMatches(term)) {
      final word = match.group(0)!;
      if (word.length < _minimumTermLength) continue;
      known.putIfAbsent(word.toLowerCase(), () => word);
    }
  }
  if (known.isEmpty) return (text: transcript, corrections: const []);

  final byCode = <String, List<String>>{};
  for (final word in known.values) {
    final code = colognePhonetics(word);
    if (_consonantClasses(code) < 2) continue;
    (byCode[code] ??= []).add(word);
  }

  final corrections = <TranscriptTermCorrection>[];
  final text = transcript.replaceAllMapped(_word, (match) {
    final heard = match.group(0)!;
    final replacement = _replacementFor(heard, known, byCode);
    if (replacement == null) return heard;
    corrections.add((heard: heard, term: replacement));
    return replacement;
  });
  return (text: text, corrections: List.unmodifiable(corrections));
}

String? _replacementFor(
  String heard,
  Map<String, String> known,
  Map<String, List<String>> byCode,
) {
  if (heard.length < _minimumTermLength) return null;
  final first = heard[0];
  if (first == first.toLowerCase()) return null;
  if (known.containsKey(heard.toLowerCase())) return null;
  final candidates = byCode[colognePhonetics(heard)];
  if (candidates == null) return null;
  final heardSpelling = soundAlikeSpelling(heard);
  final close = [
    for (final candidate in candidates)
      if (_withinSpellingTolerance(
        heardSpelling,
        soundAlikeSpelling(candidate),
      ))
        candidate,
  ];
  return close.length == 1 ? close.single : null;
}

bool _withinSpellingTolerance(String a, String b) {
  final allowed = math.max(1, math.max(a.length, b.length) ~/ 3);
  return levenshteinDistance(a, b) <= allowed;
}

int _consonantClasses(String code) => code.replaceAll('0', '').length;

const _foldedLetters = {
  'ä': 'ae',
  'ö': 'oe',
  'ü': 'ue',
  'ß': 'ss',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ø': 'oe',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

String _fold(String word) {
  final buffer = StringBuffer();
  for (final rune in word.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedLetters[char] ?? char);
  }
  return buffer.toString();
}

/// [word] spelled so that common sound-alike spellings coincide: lower case,
/// diacritics folded, `ph`→`f`, `th`→`t`, `ck`/`c`→`k`, `qu`→`kw`, `v`→`w`,
/// `y`→`i`, `ie`→`i`, `h` dropped after a vowel, doubled letters collapsed.
///
/// Only a distance gate reads this; it is never shown or stored.
String soundAlikeSpelling(String word) {
  var s = _fold(word)
      .replaceAll('ph', 'f')
      .replaceAll('th', 't')
      .replaceAll('dt', 't')
      .replaceAll('ck', 'k')
      .replaceAll('qu', 'kw')
      .replaceAll('sch', '§')
      .replaceAll('ch', '¢')
      .replaceAll('c', 'k')
      .replaceAll('v', 'w')
      .replaceAll('y', 'i')
      .replaceAll('ie', 'i')
      .replaceAll(RegExp('(?<=[aeiou])h'), '');
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
  return s.replaceAll('§', 'sch').replaceAll('¢', 'ch');
}

/// Kölner Phonetik (Cologne phonetics) of [word]: the German counterpart of
/// Soundex, which suits the German and English names this app hears.
///
/// Returns digit classes with adjacent repeats collapsed and every `0`
/// (vowel) dropped except a leading one. Letters outside the German alphabet
/// are folded first; anything still unknown is skipped.
String colognePhonetics(String word) {
  final letters = _fold(word).toUpperCase();
  final raw = StringBuffer();
  for (var i = 0; i < letters.length; i++) {
    final c = letters[i];
    final previous = i > 0 ? letters[i - 1] : '';
    final next = i + 1 < letters.length ? letters[i + 1] : '';
    final digit = switch (c) {
      'A' || 'E' || 'I' || 'J' || 'O' || 'U' || 'Y' => '0',
      'H' => '',
      'B' => '1',
      'P' => next == 'H' ? '3' : '1',
      'D' || 'T' => 'CSZ'.contains(next) && next.isNotEmpty ? '8' : '2',
      'F' || 'V' || 'W' => '3',
      'G' || 'K' || 'Q' => '4',
      'C' => _cologneC(previous: previous, next: next, atStart: i == 0),
      'X' => 'CKQ'.contains(previous) && previous.isNotEmpty ? '8' : '48',
      'L' => '5',
      'M' || 'N' => '6',
      'R' => '7',
      'S' || 'Z' => '8',
      _ => '',
    };
    raw.write(digit);
  }
  final collapsed = raw.toString().replaceAllMapped(
    RegExp(r'(\d)\1+'),
    (m) => m.group(1)!,
  );
  if (collapsed.isEmpty) return collapsed;
  return collapsed[0] + collapsed.substring(1).replaceAll('0', '');
}

String _cologneC({
  required String previous,
  required String next,
  required bool atStart,
}) {
  if (atStart) {
    return next.isNotEmpty && 'AHKLOQRUX'.contains(next) ? '4' : '8';
  }
  if (previous.isNotEmpty && 'SZ'.contains(previous)) return '8';
  return next.isNotEmpty && 'AHKOQUX'.contains(next) ? '4' : '8';
}

/// Classic Levenshtein edit distance between [a] and [b].
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[b.length];
}
