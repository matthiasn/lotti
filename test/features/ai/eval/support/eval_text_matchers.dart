/// Shared text matchers for eval assertion vocabularies.
///
/// Extracted from the task-agent inference eval so that every eval suite
/// (task agent, goal agent, …) scores required-term groups and forbidden
/// claims with identical semantics — divergent matcher behaviour between
/// suites would make cross-suite scores incomparable.
library;

/// Whether any of [terms] occurs in [text], case-insensitively.
///
/// A term group is satisfied by ANY of its members — groups express "the
/// report must mention X in some phrasing", with the members enumerating
/// accepted phrasings.
bool containsAnyEvalTerm(String text, List<String> terms) {
  final normalizedText = text.toLowerCase();
  return terms.any((term) => normalizedText.contains(term.toLowerCase()));
}

/// Negation cues that turn a claim into its opposite, in the languages the
/// scenario suites actually use.
///
/// A report saying "the fix is not yet validated" is doing exactly what a
/// resurfaced-item scenario asks for, so a bare substring blacklist scores
/// correct behaviour as a violation. Every candidate model failed such a
/// scenario for this reason alone before negation awareness was added.
const _claimNegationCues = [
  // English negation and deferral.
  'not', 'no', 'never', 'cannot', "can't", "won't", "isn't", "doesn't",
  "didn't", 'without', 'before', 'until', 'unless', 'pending', 'remains',
  'remain', 'still', 'yet', 'future', 'later', 'deferred', 'excluded',
  // German.
  'nicht', 'kein', 'keine', 'keinen', 'ohne', 'bevor', 'noch', 'erst',
  'zurückgestellt', 'zurückgestellte', 'ausstehend', 'offen', 'später',
  'künftig',
  // Spanish.
  'sin', 'antes', 'aún', 'todavía', 'pendiente', 'futuro', 'más',
];

/// Matches any cue as a whole word.
///
/// Substring matching is far too lenient here: "not" appears inside "notes",
/// "another" and "notice", so a report claiming "another dashboard was
/// delivered" would be excused as negated. Unicode-aware letter boundaries
/// keep "zurückgestellt" and "aún" matchable while closing that hole.
final RegExp _claimNegationPattern = RegExp(
  r'(?<![\p{L}])(?:'
  '${_claimNegationCues.map(RegExp.escape).join('|')}'
  r')(?![\p{L}])',
  unicode: true,
);

/// How much text around a match is inspected for a negation cue.
///
/// The cue can land on either side: English tends to precede the claim ("the
/// fix cannot be considered validated") while German routinely follows it
/// ("die Newsletter-Idee wurde explizit zurückgestellt"). Wide enough for a
/// clause, narrow enough that a negation in a neighbouring sentence does not
/// excuse a genuine overclaim.
const _claimNegationWindow = 60;

/// Whether [claim] is asserted in [text], ignoring occurrences that are
/// negated.
///
/// Returns false when every occurrence sits inside a negation window, which
/// is how a report may name deferred or unfinished work in order to rule it
/// out. Exposed so the negation rules can be tested directly rather than
/// only through a scenario's aggregate score.
bool containsAffirmativeReportClaim(String text, String claim) {
  final normalizedText = text.toLowerCase();
  final needle = claim.toLowerCase();
  var index = normalizedText.indexOf(needle);
  while (index != -1) {
    final end = index + needle.length;
    var start = index < _claimNegationWindow ? 0 : index - _claimNegationWindow;
    var stop = end + _claimNegationWindow >= normalizedText.length
        ? normalizedText.length
        : end + _claimNegationWindow;
    // A cut mid-word would fabricate a cue: "casino" truncated at the
    // window edge leaves "no", which the whole-word pattern then matches
    // (the lookbehind sees the string start, not the severed letters).
    // Drop the partial word on either edge instead of keeping it.
    while (start > 0 &&
        start < index &&
        _isLetterAt(normalizedText, start - 1) &&
        _isLetterAt(normalizedText, start)) {
      start++;
    }
    while (stop < normalizedText.length &&
        stop > end &&
        _isLetterAt(normalizedText, stop - 1) &&
        _isLetterAt(normalizedText, stop)) {
      stop--;
    }
    // Skip the claim itself so a cue inside it cannot excuse the claim.
    final context =
        '${normalizedText.substring(start, index)} '
        '${normalizedText.substring(end, stop)}';
    if (!_claimNegationPattern.hasMatch(context)) return true;
    index = normalizedText.indexOf(needle, end);
  }
  return false;
}

final RegExp _letterPattern = RegExp(r'\p{L}', unicode: true);

bool _isLetterAt(String text, int index) =>
    _letterPattern.hasMatch(text[index]);
