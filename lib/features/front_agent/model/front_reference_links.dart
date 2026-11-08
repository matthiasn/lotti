import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// The kinds her words may link to: the ones with a page of their own.
const Set<FrontDestinationKind> _linkableKinds = {
  FrontDestinationKind.task,
  FrontDestinationKind.project,
};

/// The link that names one task or project in her words —
/// `lotti://task/<id>`, `lotti://project/<id>` — which opens its page.
String frontReferenceUrl(FrontDestinationKind kind, String id) =>
    'lotti://${kind.wireName}/$id';

/// The markdown link for [row]: its title, opening its page.
String frontReferenceLink(FrontIndexRow row) =>
    '[${_label(row.title)}](${frontReferenceUrl(row.kind, row.id)})';

/// [text] with every task or project of [rows] that it names by id turned
/// into a link titled as the row is.
///
/// The prompt asks her to write links; this is the guard for when she
/// recites an id anyway — `task:<id>`, or the bare id when it has a digit
/// and so cannot be a word, either in backticks.
/// A reference in parentheses right after the row's own title
/// (`Feed the penguins (task:<id>)`) becomes one link over that title
/// rather than the title twice. Links already in the text are left as
/// they are, and an id no row lists stays text: only what the turn could
/// see is linked — except a link she wrote with the id as its url
/// (`[title](task:<id>)`, the form the tools list rows in), which gets the
/// row's url: it would neither open nor be drawn as a row.
///
/// A row of [titled] — what a lookup of the turn returned, the tasks she
/// lists from it — is linked by its title too: a list of due tasks names
/// them by title alone, and each must still open. Only the whole title,
/// ignoring case; a title two rows share stays text.
String linkFrontReferences(
  String text,
  Iterable<FrontIndexRow> rows, {
  Iterable<FrontIndexRow> titled = const [],
}) => _linkTitles(_linkIds(text, rows), titled);

String _linkIds(String text, Iterable<FrontIndexRow> rows) {
  final byId = <String, FrontIndexRow>{
    for (final row in rows)
      if (_linkableKinds.contains(row.kind) && row.id.isNotEmpty) row.id: row,
  };
  if (byId.isEmpty || text.isEmpty) return text;
  // Longest first, so an id that prefixes another never wins the match.
  final ids = byId.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    // An existing markdown link: kept whole.
    r'\[(?<label>[^\]\n]*)\]\((?<url>[^)\n]*)\)'
    '|'
    r'(?<open>\(\s*)?(?<tick>`)?(?<![\w-])(?<kind>(?:task|project):)?'
    '(?<id>${ids.map(RegExp.escape).join('|')})'
    r'(?![\w-])(?<untick>`)?(?<close>\s*\))?',
  );

  final out = StringBuffer();
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.namedGroup('url') case final url?) {
      final row = _rowOfIdUrl(url.trim(), byId);
      if (row == null) continue;
      out
        ..write(text.substring(last, match.start))
        ..write(
          '[${match.namedGroup('label')}]'
          '(${frontReferenceUrl(row.kind, row.id)})',
        );
      last = match.end;
      continue;
    }
    final id = match.namedGroup('id');
    // A bare id is linked only when no word could be it: one with a digit,
    // as every UUID has.
    if (id == null ||
        (match.namedGroup('kind') == null && !_digit.hasMatch(id))) {
      continue;
    }
    final row = byId[id]!;
    final open = match.namedGroup('open');
    final close = match.namedGroup('close');
    final wrapped = open != null && close != null;
    final before = text.substring(last, match.start);
    final folded = wrapped ? _withoutTrailingTitle(before, row.title) : null;
    if (folded != null) {
      out
        ..write(folded)
        ..write(frontReferenceLink(row));
    } else {
      // Backticks around the id go with it; a lone one, and any
      // parenthesis, belong to the sentence.
      final tick = match.namedGroup('tick');
      final untick = match.namedGroup('untick');
      final ticked = tick != null && untick != null;
      out
        ..write(before)
        ..write(open ?? '')
        ..write(ticked ? '' : (tick ?? ''))
        ..write(frontReferenceLink(row))
        ..write(ticked ? '' : (untick ?? ''))
        ..write(close ?? '');
    }
    last = match.end;
  }
  if (last == 0) return text;
  out.write(text.substring(last));
  return out.toString();
}

/// The row a link's [url] names when it is an id rather than a url —
/// `task:<id>`, `project:<id>` or the id alone — or null.
FrontIndexRow? _rowOfIdUrl(String url, Map<String, FrontIndexRow> byId) {
  final colon = url.indexOf(':');
  final kind = colon < 0 ? null : url.substring(0, colon);
  final row = byId[colon < 0 ? url : url.substring(colon + 1)];
  if (row == null || (kind != null && kind != row.kind.wireName)) return null;
  return row;
}

String _linkTitles(String text, Iterable<FrontIndexRow> rows) {
  final byTitle = <String, FrontIndexRow?>{};
  for (final row in rows) {
    final title = _label(row.title).toLowerCase();
    if (!_linkableKinds.contains(row.kind) || title.length < 3) continue;
    // A title two rows share names neither: null marks it ambiguous. A
    // row is the same one only as the same kind with the same id.
    final seen = byTitle[title];
    byTitle[title] =
        byTitle.containsKey(title) &&
            (seen?.id != row.id || seen?.kind != row.kind)
        ? null
        : row;
  }
  byTitle.removeWhere((_, row) => row == null);
  if (byTitle.isEmpty || text.isEmpty) return text;
  final titles = byTitle.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    // An existing markdown link: kept whole.
    r'\[[^\]\n]*\]\([^)\n]*\)'
    '|'
    // A title is whole only between non-letters in any script: "Plan"
    // never inside "Planète".
    r'(?<![\p{L}\p{N}_-])(?<title>'
    '${titles.map(RegExp.escape).join('|')}'
    r')(?![\p{L}\p{N}_-])',
    caseSensitive: false,
    unicode: true,
  );
  return text.replaceAllMapped(pattern, (match) {
    final title = (match as RegExpMatch).namedGroup('title');
    if (title == null) return match[0]!;
    // The regex folds case more widely than toLowerCase ("Aſk" matches
    // "Ask"): a match with no key of its own stays text.
    final row = byTitle[title.toLowerCase()];
    if (row == null) return title;
    return '[$title](${frontReferenceUrl(row.kind, row.id)})';
  });
}

/// [before] without the [title] it ends with — plain, quoted or bold — or
/// null when it does not end with it.
String? _withoutTrailingTitle(String before, String title) {
  final trimmed = before.trimRight();
  final wanted = title.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final (open, close) in const [
    ('', ''),
    ('"', '"'),
    ('“', '”'),
    ('**', '**'),
  ]) {
    final form = '$open$wanted$close';
    if (trimmed.toLowerCase().endsWith(form)) {
      return trimmed.substring(0, trimmed.length - form.length);
    }
  }
  return null;
}

final _digit = RegExp(r'\d');

/// A title as a link label: brackets would end the label early.
String _label(String title) => title
    .replaceAll('[', '(')
    .replaceAll(']', ')')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
