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
  // English negation and deferral. The multi-word entries are matched as
  // phrases: "the analytics dashboard idea is out of scope" is a textbook
  // correct deferral that every single-word cue missed, and it only surfaced
  // once the window was clipped to the sentence — before that an unrelated
  // cue nearby happened to excuse it.
  'not', 'no', 'never', 'cannot', "can't", "won't", "isn't", "doesn't",
  "didn't", 'without', 'before', 'until', 'unless', 'pending', 'remains',
  'remain', 'still', 'yet', 'future', 'later', 'deferred', 'excluded',
  'out of scope', 'outside the scope', 'descoped', 'not in scope',
  'nothing concrete to reference', 'nothing was recorded about',
  // German.
  'nicht', 'kein', 'keine', 'keinen', 'ohne', 'bevor', 'noch', 'erst',
  'zurückgestellt', 'zurückgestellte', 'ausstehend', 'offen', 'später',
  'künftig',
  // Spanish.
  'sin', 'antes', 'aún', 'todavía', 'pendiente', 'futuro', 'más',
];

/// Open-question markers, which only count inside the claim's own clause.
///
/// A report can be entirely correct while naming a thing it has NOT committed
/// to — "undecided on March vs. June", "weighing whether to submit" — and none
/// of the negation cues see that. But an open question qualifies the clause it
/// sits in, not the sentence: "Ines is weighing whether to submit, and the
/// March conference is confirmed as the decision" leaves the submission open
/// and still announces a decision. Matched sentence-wide, `whether` excused
/// exactly the invented decision the undecided-evidence scenario exists to
/// reject, so these are only matched inside [_openQuestionBreakPattern]'s
/// scope.
const _openQuestionCues = [
  'undecided',
  'whether',
  'weighing',
  'either',
  'options',
  'open question',
];

final RegExp _openQuestionPattern = RegExp(
  r'(?<![\p{L}])(?:'
  '${_openQuestionCues.map(RegExp.escape).join('|')}'
  r')(?![\p{L}])',
  unicode: true,
);

/// Where an open question's scope ends: a colon or dash, or a comma followed
/// by a conjunction that starts a new statement with its own subject.
///
/// Not every comma. An open question routinely lists its alternatives with
/// commas — "weighing whether the talk should be scheduled for March,
/// confirmed for June, or dropped" — and every item stays governed by the
/// `whether`. What ends it is a second statement: ", and the March conference
/// is confirmed", ", but it was confirmed", ", and Ines confirmed the date".
/// Requiring a fresh subject after the conjunction keeps the last item of a
/// list ("…, and dropped") inside.
///
/// A named subject is only visible in the original casing, so this runs on
/// the report as written: a capitalised word counts when a lowercase word —
/// its predicate — follows it. That keeps a capitalised last list item
/// ("March, June, and August.") inside the question, which matters because
/// month names are exactly the claims these scenarios check.
final RegExp _openQuestionBreakPattern = RegExp(
  '[:–—]|'
  r',\s*(?:and|but|while|whereas|so|yet)\s+(?:(?:the|a|an|this|that|these|'
  'those|it|its|we|they|he|she|i|you|there|our|their|his|her)'
  r'(?![\p{L}])|I(?![\p{L}])|\p{Lu}\p{Ll}+(?=\s+\p{Ll}))',
  unicode: true,
);

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

/// Negators that only count inside the claim's own comma clause.
///
/// These came from live reports ("die Newsletter-Idee bleibt bewusst außen
/// vor", "keiner ist abgeschlossen"), but sentence-wide they excuse too much:
/// "Keiner der vier Schritte fehlt, alle vier sind abgeschlossen" names a
/// negative quantifier and still reports every step finished.
const _clauseNegationCues = [
  'keiner',
  'keines',
  'keinem',
  'außen vor',
  'ausgeklammert',
  'weggelassen',
];

final RegExp _clauseNegationPattern = RegExp(
  r'(?<![\p{L}])(?:'
  '${_clauseNegationCues.map(RegExp.escape).join('|')}'
  r')(?![\p{L}])',
  unicode: true,
);

/// A comma, colon or dash ends a clause as well as a sentence — and so does
/// an `und` that starts a new statement.
///
/// German coordinates independent clauses without a comma ("keiner der vier
/// Schritte fehlt und alle vier sind abgeschlossen"), which would otherwise
/// leave a clause cue and the claim it must not reach in one clause. Only an
/// `und` followed by a fresh subject pronoun or quantifier counts: "die
/// Newsletter-Idee und der Blog bleiben außen vor" is one statement about two
/// things, and splitting it would lose the deferral.
final RegExp _clauseBreakPattern = RegExp(
  '[,:–—]|'
  r'(?<![\p{L}])und\s+(?:alle|beide|keiner|keine|keines|keinem|nichts|jeder|'
  'jede|jedes|man|es|sie|er|wir|ich)'
  r'(?![\p{L}])',
  unicode: true,
);

/// How much text around a match is inspected for a negation cue.
///
/// The cue can land on either side: English tends to precede the claim ("the
/// fix cannot be considered validated") while German routinely follows it
/// ("die Newsletter-Idee wurde explizit zurückgestellt"). Wide enough for a
/// clause, and clipped to the claim's own sentence by [_sentenceBounds] so a
/// negation belonging to a different statement cannot excuse an overclaim.
const _claimNegationWindow = 60;

/// Sentence and list-item terminators, including the escaped newlines a
/// report carries once its tool arguments are serialized to JSON.
final RegExp _sentenceBreakPattern = RegExp(r'[.!?;\n\r]|\\n|\\r');

/// The claim's own sentence, as an offset pair clipped to [_claimNegationWindow].
///
/// The character window alone was not enough. Report bodies are several
/// sentences of markdown, and the cue list is broad by necessity — `no`,
/// `still`, `yet`, `remains`, `before` — so in ordinary prose SOME cue lands
/// within 60 characters of almost any claim. "The deployment window has not
/// yet been confirmed … The sync fix was verified in staging and is applied
/// to production" scored as fully negated: two genuine overclaims excused by
/// a cue belonging to an unrelated sentence two clauses away.
///
/// Sentence clipping is what the window was always documented to do. It
/// tightens both suites that share this matcher.
(int, int) _sentenceBounds(String text, int claimStart, int claimEnd) {
  var start = claimStart < _claimNegationWindow
      ? 0
      : claimStart - _claimNegationWindow;
  var stop = claimEnd + _claimNegationWindow >= text.length
      ? text.length
      : claimEnd + _claimNegationWindow;
  // The LAST break before the claim, applied once. Adding each match's end in
  // turn compounds the offsets and walks `start` past the claim itself.
  final leading = _sentenceBreakPattern
      .allMatches(text.substring(start, claimStart))
      .lastOrNull;
  if (leading != null) start += leading.end;
  final tail = _sentenceBreakPattern.firstMatch(text.substring(claimEnd, stop));
  if (tail != null) stop = claimEnd + tail.start;
  return (start, stop);
}

/// Whether [claim] is asserted in [text], ignoring occurrences that are
/// negated.
///
/// Returns false when every occurrence sits inside a negation window, which
/// is how a report may name deferred or unfinished work in order to rule it
/// out. Exposed so the negation rules can be tested directly rather than
/// only through a scenario's aggregate score.
///
/// Negation cues are matched across the claim's sentence by default,
/// open-question cues across the statement they open (list commas included),
/// and clause-only cues never past the claim's comma clause.
/// [clauseScoped] narrows the negation cues to that clause too, for a check
/// whose claim is short and whose reports routinely pair it with an unrelated
/// caveat ("the location was identified, but the fix remains pending").
bool containsAffirmativeReportClaim(
  String text,
  String claim, {
  bool clauseScoped = false,
}) {
  final normalizedText = text.toLowerCase();
  // Lowercasing can change a string's length (a dotted capital I, for one);
  // only then do scope boundaries fall back to the lowercase text.
  final sameShape = normalizedText.length == text.length;
  final needle = claim.toLowerCase();
  var index = normalizedText.indexOf(needle);
  while (index != -1) {
    final end = index + needle.length;
    var (start, stop) = _sentenceBounds(normalizedText, index, end);
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
    if (_isGovernedByGermanModalPassive(normalizedText, index, end)) {
      index = normalizedText.indexOf(needle, end);
      continue;
    }
    // Skip the claim itself so a cue inside it cannot excuse the claim.
    final before = normalizedText.substring(start, index);
    final after = normalizedText.substring(end, stop);
    final clauseBefore = switch (_clauseBreakPattern
        .allMatches(before)
        .lastOrNull) {
      final Match brk => before.substring(brk.end),
      null => before,
    };
    final clauseAfter = switch (_clauseBreakPattern.firstMatch(after)) {
      final Match brk => after.substring(0, brk.start),
      null => after,
    };
    final clause = '$clauseBefore $clauseAfter';
    // Boundaries come from the report as written (see
    // [_openQuestionBreakPattern]); the offsets carry over to the lowercase
    // text because lowercasing kept every character in place.
    final cased = sameShape ? text : normalizedText;
    // Searched through the claim itself, because a named subject's predicate
    // may be the claim ("…, and Ines confirmed"); only a break that ends
    // before the claim counts.
    final questionBefore = switch (_openQuestionBreakPattern
        .allMatches(cased.substring(start, end))
        .where((brk) => brk.end <= index - start)
        .lastOrNull) {
      final Match brk => before.substring(brk.end),
      null => before,
    };
    final questionAfter = switch (_openQuestionBreakPattern.firstMatch(
      cased.substring(end, stop),
    )) {
      final Match brk => after.substring(0, brk.start),
      null => after,
    };
    final negated =
        _claimNegationPattern.hasMatch(
          clauseScoped ? clause : '$before $after',
        ) ||
        _openQuestionPattern.hasMatch('$questionBefore $questionAfter') ||
        _clauseNegationPattern.hasMatch(clause);
    if (!negated) return true;
    index = normalizedText.indexOf(needle, end);
  }
  return false;
}

/// The modals that turn a German passive into planned or possible work.
///
/// Ability, obligation and permission (kann, soll, muss, darf) and the
/// possibility subjunctive (könnte). Deliberately not the epistemic forms
/// dürfte and müsste: "der Review dürfte abgeschlossen sein" says the review is
/// *probably* complete, which is a hedged completion claim, not a plan.
const _germanPlanningModals =
    'kann|können|soll|sollen|muss|müssen|darf|dürfen|könnte|könnten';

/// A German modal earlier in the claim's own clause: "…, kann der Prototyp ".
final RegExp _germanModalBeforeClaim = RegExp(
  '(?<![\\p{L}])(?:$_germanPlanningModals)(?![\\p{L}])'
  r'[^,.;:!?\n\r]{0,60}$',
  unicode: true,
);

/// The passive auxiliary closing that clause right after the claim, directly
/// or after one coordinated participle: " werden", " und die Anmeldung
/// umgesetzt werden".
final RegExp _germanPassiveAfterClaim = RegExp(
  r'^(?:\s+und[^,.;:!?\n\r]{0,60}?)?\s+werden(?![\p{L}])',
  unicode: true,
);

/// The verb-final order of a German subordinate clause, where the passive
/// auxiliary and the modal both follow the participle: "damit der Review
/// abgeschlossen sein kann", "bevor die Anmeldung umgesetzt werden muss".
///
/// Both words sit directly after the participle, so the modal can only be
/// governing that verb.
final RegExp _germanVerbFinalModalAfterClaim = RegExp(
  '^\\s+(?:sein|werden)\\s+(?:$_germanPlanningModals)(?![\\p{L}])',
  unicode: true,
);

/// Whether the participle at [start]..[end] is itself the verb of a German
/// modal passive — "kann der Prototyp abgeschlossen werden" plans the work
/// rather than reporting it done, and so does the subordinate-clause order
/// "damit der Review abgeschlossen sein kann".
///
/// The main-clause form alone missed every subordinate clause: after damit,
/// bevor, sobald or weil German puts the modal last, and a report planning a
/// review "so that it can be completed" failed as claiming it was completed.
///
/// Scoped to the claimed participle on purpose. Modals as ordinary negation
/// cues excused far too much: "Die Newsletter-Idee soll umgesetzt werden" is
/// still a claim about the newsletter, and "wurde abgeschlossen und kann jetzt
/// verwendet werden" is still a completion — the modal there governs another
/// verb.
bool _isGovernedByGermanModalPassive(String text, int start, int end) {
  final after = text.substring(end);
  if (_germanVerbFinalModalAfterClaim.hasMatch(after)) return true;
  return _germanModalBeforeClaim.hasMatch(text.substring(0, start)) &&
      _germanPassiveAfterClaim.hasMatch(after);
}

final RegExp _letterPattern = RegExp(r'\p{L}', unicode: true);

bool _isLetterAt(String text, int index) =>
    _letterPattern.hasMatch(text[index]);
