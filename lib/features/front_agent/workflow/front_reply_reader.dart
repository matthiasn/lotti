import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// A `reply_to_user` the reader refused: one without words, which leaves
/// nothing to deliver. Its message is the error she is told.
class FrontReplyException implements Exception {
  const FrontReplyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Her reply as read: `text`, her words as she wrote them — a list she
/// wrote included, since cards are not read aloud — which is what is
/// spoken, kept in the conversation and shown when a reply is words alone;
/// `components`,
/// what is drawn, in order, each a `{component, …properties}` map for
/// `FrontReplySurface.compose`; and `dropped`, a note per component that
/// could not be drawn and was left out — what her tool result and the log
/// say.
typedef FrontReply = ({
  String text,
  List<Map<String, Object?>> components,
  List<String> dropped,
});

/// How many replies to tap a reply may offer.
const int frontQuickRepliesMax = 3;

/// Reads `reply_to_user`'s [message] and [components] into her reply.
///
/// She composes a reply from the catalog (`FrontReplyComponents`): `Text`
/// with her words; `TaskCards` with `items`, each `task:<id>` or
/// `project:<id>` — or `{"ref": …, "note": …}` to say a few words on its
/// card; `ClosedTasks`, `LoggedTimeChart` and `PullRequestChart`, placing
/// what a lookup made; and `QuickReplies` with up to
/// [frontQuickRepliesMax] `options`. Her words are said once: a [message]
/// leads [components], unless it repeats what their `Text` says. Her words
/// pass through [link].
///
/// A card must be a task or project of [visible] — what the turn could see,
/// by `kind:id` — and a lookup's component one of [available]: nothing is
/// drawn for an id she made up or a chart no lookup produced. Such a
/// component is dropped and named in `dropped`, never a reason to lose her
/// answer: refusing it could end a turn with no call left without any
/// reply. Only a reply without words throws a [FrontReplyException].
///
/// **Cards never hinge on her remembering the component.** A list in her
/// words whose lines each link one task or project of [visible] is drawn as
/// `TaskCards` in its place, what else the line says kept as the card's
/// note (a project line that says more stays her words, since only a
/// task's card shows a note; so does a line that says more than
/// [frontCardNoteMax] characters, a sentence rather than a label). The list stays in `text`, so it is still spoken. Nothing a lookup found is lost either: the tasks of [dueRows] she
/// listed nowhere follow as one more list, and [available] components she
/// did not place follow in catalog order. A task is listed once, where it
/// first stands, and never when it is one of [closedTaskIds], whose cards
/// show it.
FrontReply readFrontReply({
  required Object? message,
  required Object? components,
  required Map<String, FrontIndexRow> visible,
  required Set<String> available,
  required List<FrontIndexRow> dueRows,
  required String Function(String words) link,
  Set<String> closedTaskIds = const {},
}) {
  final dropped = <String>[];
  final read = <Map<String, Object?>>[];
  final listed = <String>{
    for (final id in closedTaskIds) 'task:$id',
  };
  final placed = <String>{};

  void cards(Iterable<FrontEntityReference> references) {
    final items = [
      for (final reference in references)
        if (listed.add('${reference.kind.name}:${reference.id}'))
          reference.toJson(),
    ];
    if (items.isEmpty) return;
    read.add({'component': FrontReplyComponents.taskCards, 'items': items});
  }

  // Her words as she wrote them, lists included: what is spoken and kept.
  final said = <String>[];

  void words(String text) {
    final linked = link(text.trim());
    said.add(linked);
    for (final piece in _wordsAndLists(linked, visible)) {
      switch (piece) {
        case final String text:
          read.add({'component': FrontReplyComponents.text, 'text': text});
        case final List<FrontEntityReference> references:
          cards(references);
      }
    }
  }

  // A model that composes components tends to repeat its words in
  // `message` too. Her words are said once: a message that says what the
  // Text components say — or that they are part of — is left out; one that
  // adds words leads them.
  final composed = _normalized(
    [
      if (components is List)
        for (final component in components)
          if (component case {
            'component': FrontReplyComponents.text,
            'text': final String text,
          })
            text,
    ].join(' '),
  );
  final lead = message is String ? message.trim() : '';
  final repeats =
      composed.isNotEmpty &&
      (composed.contains(_normalized(lead)) ||
          _normalized(lead).contains(composed));
  if (lead.isNotEmpty && !repeats) words(lead);
  if (components != null && components is! List) {
    dropped.add('components, which is not a list');
  }
  for (final component in components is List ? components : const <Object?>[]) {
    final type = component is Map ? component['component'] : null;
    switch (component) {
      case {'text': final String text} when type == FrontReplyComponents.text:
        if (text.trim().isNotEmpty) words(text);
      case {'items': final List<Object?> items}
          when type == FrontReplyComponents.taskCards:
        cards([
          for (final item in items)
            if (_referenceOf(item, visible) case final reference?)
              reference
            else
              ?_drop(
                dropped,
                '${item is Map ? item['ref'] : item}, not a task or project '
                'listed under <routing_index> or returned by a lookup this '
                'turn',
              ),
        ]);
      case {'options': final List<Object?> options}
          when type == FrontReplyComponents.quickReplies:
        final replies = [
          for (final option in options)
            if (option is String && option.trim().isNotEmpty) option.trim(),
        ].take(frontQuickRepliesMax).toList();
        if (replies.isNotEmpty) {
          read.add({
            'component': FrontReplyComponents.quickReplies,
            'options': replies,
          });
        }
      case _ when FrontReplyComponents.fromLookups.contains(type):
        if (!available.contains(type)) {
          dropped.add('$type, which no lookup made this turn');
        } else if (placed.add(type! as String)) {
          read.add({'component': type});
        }
      default:
        dropped.add(
          '$component, not a component: each names one of '
          '${FrontReplyComponents.composable.join(', ')} as its component, '
          'with its properties',
        );
    }
  }

  if (said.isEmpty) {
    throw const FrontReplyException(
      'Error: reply_to_user needs your words: a message, or a Text component.',
    );
  }
  cards([
    for (final row in dueRows)
      if (_kinds[row.kind] case final kind?)
        FrontEntityReference(kind: kind, id: row.id, title: row.title),
  ]);
  return (
    text: said.join('\n\n'),
    components: [
      ...read,
      for (final type in FrontReplyComponents.fromLookups)
        if (available.contains(type) && !placed.contains(type))
          {'component': type},
    ],
    dropped: dropped,
  );
}

/// [text] for comparing what was said: lower case, whitespace collapsed.
String _normalized(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// The longest a list line's other words may be to become a card's note: a
/// time, a label. A line that says a sentence stays her words, where it
/// can be read whole.
const int frontCardNoteMax = 40;

/// Records [note] in [dropped]; null, so it can stand where a value would.
Never? _drop(List<String> dropped, String note) {
  dropped.add(note);
  return null;
}

/// The kinds a card can show, from the router's.
const Map<FrontDestinationKind, FrontEntityKind> _kinds = {
  FrontDestinationKind.task: FrontEntityKind.task,
  FrontDestinationKind.project: FrontEntityKind.project,
};

/// The card [raw] names — `kind:id`, or `{ref, note}` — or null when it is
/// not a task or project of [visible].
FrontEntityReference? _referenceOf(
  Object? raw,
  Map<String, FrontIndexRow> visible,
) {
  final (ref, note) = switch (raw) {
    final String ref => (ref, null),
    {'ref': final String ref} => (ref, raw['note']),
    _ => (null, null),
  };
  final row = ref == null ? null : visible[ref.trim()];
  final kind = row == null ? null : _kinds[row.kind];
  if (row == null || kind == null) return null;
  return FrontEntityReference(
    kind: kind,
    id: row.id,
    title: row.title,
    // Only a task's card shows a note.
    note:
        kind == FrontEntityKind.task && note is String && note.trim().isNotEmpty
        ? note.trim()
        : null,
  );
}

/// A line of a Markdown list: its marker, then what it says.
final RegExp _listLine = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s+(.*)$');

/// A link to a task or project, as her words are linked.
final RegExp _entityLink = RegExp(
  r'\[([^\]\n]*)\]\(lotti://(task|project)s?/([^)\s/]+)\)',
);

/// What a list line says around its link, once the list's own punctuation
/// is gone: a checkbox, emphasis, and the dashes, colons and brackets that
/// joined the words to the link.
final RegExp _checkbox = RegExp(r'^\s*\[[ xX]\]\s*');
final RegExp _emphasis = RegExp('[*_`]+');
final RegExp _joiners = RegExp(r'^[\s—–\-:·,;()|]+|[\s—–\-:·,;()|.]+$');

/// [text] cut into her words and the lists of tasks in them, in order: a
/// `String` per stretch of words, a `List<FrontEntityReference>` per list.
///
/// A list is consecutive list lines — blank lines between them included —
/// that each hold exactly one link to a task or project of [visible],
/// wherever on the line it stands. What else the line says becomes the
/// card's note. Any other line stays her words.
List<Object> _wordsAndLists(String text, Map<String, FrontIndexRow> visible) {
  final pieces = <Object>[];
  final words = <String>[];
  var run = <FrontEntityReference>[];
  final blanks = <String>[];

  void flushWords() {
    final said = words.join('\n').trim();
    if (said.isNotEmpty) pieces.add(said);
    words.clear();
  }

  void flushRun() {
    if (run.isEmpty) return;
    flushWords();
    pieces.add(run);
    run = [];
  }

  for (final line in text.split('\n')) {
    if (run.isNotEmpty && line.trim().isEmpty) {
      blanks.add(line);
      continue;
    }
    final card = _cardOfLine(line, visible);
    if (card != null) {
      run.add(card);
      blanks.clear();
      continue;
    }
    flushRun();
    words
      ..addAll(blanks)
      ..add(line);
    blanks.clear();
  }
  flushRun();
  flushWords();
  return pieces;
}

/// The card a list [line] is, or null when it is not a list line with
/// exactly one link to a task or project of [visible].
FrontEntityReference? _cardOfLine(
  String line,
  Map<String, FrontIndexRow> visible,
) {
  final said = _listLine.firstMatch(line)?.group(1);
  if (said == null) return null;
  final links = _entityLink.allMatches(said).toList();
  if (links.length != 1) return null;
  final link = links.single;
  final row = visible['${link.group(2)}:${link.group(3)}'];
  final kind = row == null ? null : _kinds[row.kind];
  if (row == null || kind == null) return null;
  final note = said
      .replaceRange(link.start, link.end, ' ')
      .replaceFirst(_checkbox, '')
      .replaceAll(_emphasis, '')
      .replaceAll(_joiners, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Only a task's card shows a note: a project line that says more stays
  // her words, so nothing she wrote is lost.
  if (note.isNotEmpty && kind != FrontEntityKind.task) return null;
  if (note.length > frontCardNoteMax) return null;
  return FrontEntityReference(
    kind: kind,
    id: row.id,
    title: row.title,
    note: note.isEmpty ? null : note,
  );
}

/// [rows] by the `kind:id` the index and the lookups list them as.
Map<String, FrontIndexRow> frontVisibleRows(Iterable<FrontIndexRow> rows) => {
  for (final row in rows) '${row.kind.wireName}:${row.id}': row,
};
