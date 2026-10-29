import 'package:meta/meta.dart';

/// One entity whose title matched a title search.
@immutable
class TitleMatch {
  const TitleMatch({
    required this.entityId,
    required this.type,
    required this.title,
    this.fuzzy = false,
  });

  final String entityId;

  /// The journal row's `type`, which decides how the match is opened.
  final String type;
  final String title;

  /// True when no title held every word and this one shares most of the
  /// query's letter triples instead — a misspelling's nearest titles.
  final bool fuzzy;
}

/// The lower-cased words of [text] with their accents folded, split the way
/// the index's tokenizers split it: letters (with their combining marks) and
/// digits. Folding as the index does (`remove_diacritics`) is what lets
/// "pinguine" hold "Pingüine" here too, rather than only in SQLite.
List<String> searchWords(String text) => [
  for (final match in _word.allMatches(foldDiacritics(text.toLowerCase())))
    match.group(0)!,
];

final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

/// Lower-case [text] with Latin accents removed: precomposed letters mapped
/// to their base letter, combining accents (U+0300–U+036F) dropped. Other
/// combining marks — the vowel signs Indic scripts write words with — stay.
/// [searchWords] lower-cases before it folds.
String foldDiacritics(String text) {
  final folded = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue;
    final char = String.fromCharCode(rune);
    folded.write(_baseLetters[char] ?? char);
  }
  return folded.toString();
}

final Map<String, String> _baseLetters = {
  for (final MapEntry(key: base, value: accented) in const {
    'a': 'àáâãäåāăąǎȁȃạảấầẩẫậắằẳẵặ',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęěȅȇẹẻẽếềểễệ',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįıǐȉȋịỉ',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňŉ',
    'o': 'òóôõöøōŏőǒȍȏọỏốồổỗộớờởỡợ',
    'r': 'ŕŗř',
    's': 'śŝşšș',
    't': 'ţťŧț',
    'u': 'ùúûüũūŭůűųǔưụủứừửữự',
    'w': 'ŵ',
    'y': 'ýÿŷỳỵỷỹ',
    'z': 'źżž',
  }.entries)
    for (final letter in accented.runes) String.fromCharCode(letter): base,
};

/// The words a trigram index can match: three characters and more.
const minTrigramWordLength = 3;

/// The distinct letter triples of the words in [text], as the trigram
/// tokenizer reads them — never across a space.
Set<String> titleTrigrams(String text) => {
  for (final word in searchWords(text))
    for (var i = 0; i + minTrigramWordLength <= word.length; i++)
      word.substring(i, i + minTrigramWordLength),
};

/// Orders [candidates] — in the index's own order, best first — for a
/// quick-open list, keeping only the titles that hold every word of [query]:
/// the title that is the query, then titles starting with it, then titles
/// with a word starting with its first word, then the rest, each tier in the
/// index's order. A word of one or two letters counts only as the start of
/// a word of the title; a longer one anywhere in it.
List<TitleMatch> rankTitleMatches(
  String query,
  Iterable<TitleMatch> candidates,
) {
  final words = searchWords(query);
  if (words.isEmpty) return const [];
  final phrase = words.join(' ');
  final tiered = <(int, int, TitleMatch)>[];
  for (final (index, candidate) in candidates.indexed) {
    final titleWords = searchWords(candidate.title);
    final title = titleWords.join(' ');
    final holdsEveryWord = words.every(
      (word) => word.length >= minTrigramWordLength
          ? title.contains(word)
          : titleWords.any((titleWord) => titleWord.startsWith(word)),
    );
    if (!holdsEveryWord) continue;
    final tier = title == phrase
        ? 0
        : title.startsWith(phrase)
        ? 1
        : titleWords.any((titleWord) => titleWord.startsWith(words.first))
        ? 2
        : 3;
    tiered.add((tier, index, candidate));
  }
  tiered.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final (_, _, match) in tiered) match];
}

/// The [candidates] close enough to a misspelt [query] — sharing at least
/// half of its letter triples, and two or more — most shared first, marked
/// [TitleMatch.fuzzy].
List<TitleMatch> nearestTitles(String query, Iterable<TitleMatch> candidates) {
  final wanted = titleTrigrams(query);
  if (wanted.length < 2) return const [];
  final needed = (wanted.length / 2).ceil().clamp(2, wanted.length);
  final scored = <(int, int, TitleMatch)>[];
  for (final (index, candidate) in candidates.indexed) {
    final shared = titleTrigrams(candidate.title).intersection(wanted).length;
    if (shared < needed) continue;
    scored.add((shared, index, candidate));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? b.$1 - a.$1 : a.$2 - b.$2);
  return [
    for (final (_, _, match) in scored)
      TitleMatch(
        entityId: match.entityId,
        type: match.type,
        title: match.title,
        fuzzy: true,
      ),
  ];
}
