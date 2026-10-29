/// Turns what a user typed into an FTS5 `MATCH` expression that cannot fail
/// to parse.
///
/// FTS5 gives meaning to quotes, `-`, `:`, `*`, `^`, parentheses and the
/// bare words `AND`, `OR`, `NOT` and `NEAR`; passed through raw, an
/// apostrophe or a hyphenated word is a syntax error and a stray `OR` an
/// operator. So the expression is rebuilt from the input's words instead:
///
/// - every whitespace-separated word becomes a quoted phrase of the letters
///   and digits in it, the way the `unicode61` tokenizer splits it —
///   `self-care` is the phrase `"self care"`, `don't` is `"don t"`;
/// - text in double quotes stays one phrase, matched exactly;
/// - with [prefixLastWord], the last word, unless quoted or followed by a
///   space, also matches as a prefix (`"pengu"*`), so results keep up while
///   the word is being typed — from its second character, below which a
///   prefix matches almost everything;
/// - the phrases are all required, or with [anyTerm] any one of them is
///   enough.
///
/// Returns null when the input holds no letter or digit, which no index
/// matches. At most [maxPhrases] phrases are kept, which bounds the cost of a
/// pasted paragraph.
String? ftsMatchExpression(
  String input, {
  bool anyTerm = false,
  bool prefixLastWord = true,
  int maxPhrases = 16,
}) {
  final phrases = <String>[];
  var prefixLast = false;
  for (final segment in _segment.allMatches(input)) {
    if (phrases.length == maxPhrases) break;
    final quoted = segment.group(1);
    final tokens = [
      for (final token in _token.allMatches(quoted ?? segment.group(0)!))
        token.group(0)!,
    ];
    if (tokens.isEmpty) continue;
    phrases.add('"${tokens.join(' ')}"');
    prefixLast =
        prefixLastWord &&
        quoted == null &&
        segment.end == input.length &&
        tokens.last.length >= _minPrefixLength;
  }
  if (phrases.isEmpty) return null;
  if (prefixLast) phrases.last = '${phrases.last}*';
  return phrases.join(anyTerm ? ' OR ' : ' ');
}

/// A double-quoted run (closed or still being typed), or a bare word.
final _segment = RegExp(r'"([^"]*)"?|[^\s"]+');

/// What the `unicode61` tokenizer keeps as a token: letters (with their
/// combining marks, which Indic scripts write vowels with) and digits.
final _token = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

const _minPrefixLength = 2;
