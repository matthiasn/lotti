import 'dart:math' show min;

/// Truncate [text] to [maxLength] characters, collapsing newlines into spaces
/// and appending "…" if truncated.
String truncateAgentText(String text, int maxLength) {
  final singleLine = text.replaceAll('\n', ' ').trim();
  if (maxLength <= 0) return '';
  if (singleLine.length <= maxLength) return singleLine;
  if (maxLength == 1) return '…';
  return '${singleLine.substring(0, min(maxLength - 1, singleLine.length))}…';
}

/// A canonical UUID (v1/v4), the shape of every internal entity id in this app.
const _uuid =
    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

/// Patterns for internal entity ids a model may echo into user-facing report
/// text. The task context hands the model each checklist item's real id (it
/// needs them to call the checklist/label tools), and weaker models copy those
/// ids straight into the report — e.g. `Ship the API (id: 6af9c4b0-…)`. Each
/// pattern strips one such annotation shape, leading whitespace included, so
/// the surrounding prose reads cleanly.
///
/// Deliberately narrow: only `id:`-annotated forms and a lone parenthesized
/// UUID are removed. A UUID inside a `/tasks/<id>` link path or markdown link
/// (`[title](/tasks/<id>)`) is never in one of these shapes, so legitimate
/// proof-of-work links survive.
final _reportIdAnnotationPatterns = <RegExp>[
  // `(id: <uuid>)`, `[id = <uuid>]` — parenthesized/bracketed annotation.
  RegExp('\\s*[(\\[]\\s*id\\s*[:=]\\s*$_uuid\\s*[)\\]]'),
  // ` — id: <uuid>`, ` - id=<uuid>` — dash-prefixed trailing annotation.
  RegExp('\\s*[-–—]\\s*id\\s*[:=]\\s*$_uuid\\b'),
  // ` id: <uuid>` — bare trailing annotation.
  RegExp('\\s+id\\s*[:=]\\s*$_uuid\\b'),
  // ` (<uuid>)` — lone parenthesized UUID.
  RegExp('\\s*\\(\\s*$_uuid\\s*\\)'),
];

/// A bare internal id fragment echoed into prose.
///
/// Goal criterion ids are minted as `habit-<habitId>` (`goal_form_mapping`),
/// so the handle the model legitimately needs for `nextActions[].criterionId`
/// carries a UUID inside it. Weaker models copy it into the sentence — "Close
/// the gap on habit 71ca84b0 — 2 more completions needed".
///
/// Matched by shape rather than by a preceding noun, because the noun is
/// whatever the report's language calls a habit. Deliberately narrow on three
/// axes, so nothing legitimate is caught:
///
///  * **A whole UUID, or eight or more hex digits with at least one letter.**
///    A pure-digit run of that length is a plausible measurement and never
///    matches.
///  * **Preceded by whitespace.** URLs contain none, so a UUID inside a
///    `/tasks/<id>` path or a markdown link target can never be reached — the
///    same guarantee [_reportIdAnnotationPatterns] makes, and one this shared
///    sanitizer owes its task and project callers.
///  * **Not followed by `-`, a word character or `/`.** That leaves a full
///    UUID and any longer token intact rather than beheading them.
///
/// The leading space goes with it, so "on habit 71ca84b0 — 2 more" closes up
/// to "on habit — 2 more" rather than leaving a double space behind.
final _bareIdFragmentPattern = RegExp(
  '\\s`?(?:$_uuid|(?=[0-9a-fA-F]{8})[0-9a-fA-F]*[a-fA-F][0-9a-fA-F]*)'
  r'`?(?![-\w/])',
);

/// Removes internal entity ids a model echoed into a user-facing agent report.
///
/// See [_reportIdAnnotationPatterns] for the annotated shapes, and
/// [_bareIdFragmentPattern] for the bare id fragment; both leave links
/// untouched. Trailing whitespace a removal leaves on a line is trimmed, but
/// only on lines a removal actually touched — a line that still appears
/// verbatim in the input keeps its trailing spaces, so a deliberate Markdown
/// hard break (two trailing spaces) elsewhere in the report survives.
/// Indentation and newlines are untouched so lists and code blocks keep their
/// structure. Returns [text] unchanged when it carries no id annotations.
String sanitizeAgentReportText(String text) {
  var out = text;
  for (final pattern in _reportIdAnnotationPatterns) {
    out = out.replaceAll(pattern, '');
  }
  out = out.replaceAll(_bareIdFragmentPattern, '');
  if (out == text) return text;
  // A removal only deletes characters (a pattern's leading `\s*` can also eat a
  // preceding newline, merging two lines), so any line still present verbatim
  // in the input was untouched and must keep its trailing whitespace.
  final untouched = text.split('\n').toSet();
  return out
      .split('\n')
      .map(
        (line) => untouched.contains(line)
            ? line
            : line.replaceAll(RegExp(r'[ \t]+$'), ''),
      )
      .join('\n');
}
