import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// A reply the reader refused: one without prose, which leaves nothing to
/// say. Its message says what was missing.
class FrontReplyException implements Exception {
  const FrontReplyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Her reply as read: `text`, her prose — a list she wrote in it included,
/// since cards are not read aloud — which is what is spoken, kept in the
/// conversation and shown when a reply is words alone; `components`, what is
/// drawn, in order, each a `{component, …properties}` map for
/// `FrontReplySurface.compose`; and `dropped`, a note per component that
/// could not be drawn and was left out, for the log.
typedef FrontReply = ({
  String text,
  List<Map<String, Object?>> components,
  List<String> dropped,
});

/// How many replies to tap a reply may offer.
const int frontQuickRepliesMax = 3;

/// Reads her [prose] and the [components] she composed into her reply.
///
/// Her answer has one place for words, her prose, which leads what is
/// drawn. The components are the catalog's (`FrontReplyComponents`), as she
/// writes them: `Text`, a short label shown between other parts and not
/// spoken; `TaskCards` with `ids`, each `task:<id>`, `project:<id>` or a
/// task's bare id, and optionally `notes`, a few words per id for its card;
/// `ClosedTasks`, `LoggedTimeChart` and `PullRequestChart`, placing what a
/// lookup made; and `QuickReplies` with up to [frontQuickRepliesMax]
/// `options`. A `caption`, where she gave one, is kept as the component's
/// accessibility label. Her prose passes through [link].
///
/// A card must be a task or project of [visible] — what the turn could see,
/// by `kind:id` — and a lookup's component one of [available]: nothing is
/// drawn for an id she made up or a chart no lookup produced. Such a
/// component is dropped and named in `dropped`, never a reason to lose her
/// answer. Only a reply without prose throws a [FrontReplyException] —
/// unless [proseRequired] is false, for an answer still being written,
/// whose UI comes before its prose.
///
/// **Cards never hinge on her remembering the component.** A list in her
/// prose whose lines each link one task or project of [visible] is drawn as
/// `TaskCards` in its place, what else the line says kept as the card's
/// note (a project line that says more stays her words, since only a
/// task's card shows a note; so does a line that says more than
/// [frontCardNoteMax] characters, a sentence rather than a label). The list
/// stays in `text`, so it is still spoken. Nothing a lookup found is lost
/// either: the tasks of [dueRows] she listed nowhere follow as one more
/// list, and [available] components she did not place follow in catalog
/// order. A task is listed once, where it first stands, and never when it
/// is one of [closedTaskIds], whose cards show it.
FrontReply readFrontReply({
  required String prose,
  required List<Object?> components,
  required Map<String, FrontIndexRow> visible,
  required Set<String> available,
  required List<FrontIndexRow> dueRows,
  required String Function(String words) link,
  Set<String> closedTaskIds = const {},
  bool proseRequired = true,
}) {
  if (proseRequired && prose.trim().isEmpty) {
    throw const FrontReplyException('The reply has no prose.');
  }
  final dropped = <String>[];
  final read = <Map<String, Object?>>[];
  final listed = <String>{
    for (final id in closedTaskIds) 'task:$id',
  };
  final placed = <String>{};

  void cards(Iterable<FrontEntityReference> references, {Object? caption}) {
    final items = [
      for (final reference in references)
        if (listed.add('${reference.kind.name}:${reference.id}'))
          reference.toJson(),
    ];
    if (items.isEmpty) return;
    read.add({
      'component': FrontReplyComponents.taskCards,
      'items': items,
      'caption': ?_caption(caption),
    });
  }

  void words(String text) {
    for (final piece in _wordsAndLists(text, visible)) {
      switch (piece) {
        case final String text:
          read.add({'component': FrontReplyComponents.text, 'text': text});
        case final List<FrontEntityReference> references:
          cards(references);
      }
    }
  }

  final said = link(prose.trim());
  words(said);
  for (final component in components) {
    final type = component is Map ? component['component'] : null;
    switch (component) {
      case {'text': final String text} when type == FrontReplyComponents.text:
        if (text.trim().isNotEmpty) words(link(text.trim()));
      case {'ids': final List<Object?> ids}
          when type == FrontReplyComponents.taskCards:
        final notes = component['notes'];
        final references = <FrontEntityReference>[];
        for (final (index, id) in ids.indexed) {
          final reference = _referenceOf(
            id,
            notes is List && index < notes.length ? notes[index] : null,
            visible,
          );
          if (reference == null) {
            dropped.add(
              '$id, not a task or project listed under <routing_index> or '
              'returned by a lookup this turn',
            );
          } else {
            references.add(reference);
          }
        }
        cards(references, caption: component['caption']);
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
      case final Map<Object?, Object?> lookup
          when FrontReplyComponents.fromLookups.contains(type):
        if (!available.contains(type)) {
          dropped.add('$type, which no lookup made this turn');
        } else if (placed.add(type! as String)) {
          read.add({
            'component': type,
            'caption': ?_caption(lookup['caption']),
          });
        }
      default:
        dropped.add('$component, not a component of the reply catalog');
    }
  }

  cards([
    for (final row in dueRows)
      if (_kinds[row.kind] case final kind?)
        FrontEntityReference(kind: kind, id: row.id, title: row.title),
  ]);
  return (
    text: said,
    components: [
      ...read,
      for (final type in FrontReplyComponents.fromLookups)
        if (available.contains(type) && !placed.contains(type))
          {'component': type},
    ],
    dropped: dropped,
  );
}

/// A component's accessibility label, when she gave one.
String? _caption(Object? caption) =>
    caption is String && caption.trim().isNotEmpty ? caption.trim() : null;

/// The longest a list line's other words may be to become a card's note: a
/// time, a label. A line that says a sentence stays her words, where it
/// can be read whole.
const int frontCardNoteMax = 40;

/// The kinds a card can show, from the router's.
const Map<FrontDestinationKind, FrontEntityKind> _kinds = {
  FrontDestinationKind.task: FrontEntityKind.task,
  FrontDestinationKind.project: FrontEntityKind.project,
};

/// The card [id] names — `task:<id>`, `project:<id>`, or a task's bare id —
/// with [note] as what its card says, or null when it is not a task or
/// project of [visible].
FrontEntityReference? _referenceOf(
  Object? id,
  Object? note,
  Map<String, FrontIndexRow> visible,
) {
  final ref = id is String ? id.trim() : null;
  final row = ref == null ? null : visible[ref] ?? visible['task:$ref'];
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
