import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// A `reply_to_user` the reader refused: one without words, which leaves
/// nothing to deliver. Its message is the error she is told.
class FrontReplyLayoutException implements Exception {
  const FrontReplyLayoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Her reply as stored: `text`, her words, which is what is spoken, kept in
/// the conversation and shown when a reply has nothing else; `parts`, what
/// is drawn, in order; and `dropped`, a note per part that could not be
/// drawn and was left out — what her tool result and the log say.
typedef FrontReplyLayout = ({
  String text,
  List<FrontReplyPart> parts,
  List<String> dropped,
});

/// Reads `reply_to_user`'s [message] and [parts] into the reply as stored.
///
/// A part is `{"text": …}`, `{"cards": ["task:<id>", …]}` or
/// `{"show": "<attachment>"}`. A card must be a task or project of
/// [visible] — what the turn could see, by `kind:id` — and a `show` one of
/// [available], what this turn's lookups made: nothing is drawn for an id
/// she made up or a chart no lookup produced. Such a part is dropped and
/// named in `dropped`, never a reason to lose her answer: refusing it could
/// end a turn with no budget left for another call without any reply. A
/// [message] given beside [parts] leads them as words. Her words pass
/// through [link].
///
/// Throws a [FrontReplyLayoutException] only for a reply without words.
///
/// Nothing a lookup found is lost to a part she forgot: the tasks of
/// [dueRows] no part listed follow as one more list, and [available]
/// attachments she did not place follow in the order of
/// [FrontReplyAttachment]. A task is listed once, where she first put it.
FrontReplyLayout readFrontReplyLayout({
  required Object? message,
  required Object? parts,
  required Map<String, FrontIndexRow> visible,
  required Set<FrontReplyAttachment> available,
  required List<FrontIndexRow> dueRows,
  required String Function(String words) link,
}) {
  final dropped = <String>[];
  final words = message is String ? message.trim() : '';
  final read = <FrontReplyPart>[
    if (words.isNotEmpty) FrontReplyText(link(words)),
  ];
  final listed = <String>{};
  final placed = <FrontReplyAttachment>{};
  if (parts != null && parts is! List) {
    dropped.add('parts, which is not a list');
  }
  for (final part in parts is List ? parts : const <Object?>[]) {
    switch (part) {
      case {'text': final String text}:
        if (text.trim().isNotEmpty) read.add(FrontReplyText(link(text.trim())));
      case {'cards': final List<Object?> cards}:
        final references = <FrontEntityReference>[];
        for (final card in cards) {
          final reference = _referenceOf(card, visible);
          if (reference == null) {
            dropped.add(
              '$card, not a task or project listed under <routing_index> or '
              'returned by a lookup this turn',
            );
          } else if (listed.add('${reference.kind.name}:${reference.id}')) {
            references.add(reference);
          }
        }
        if (references.isNotEmpty) read.add(FrontReplyCards(references));
      case {'show': final Object? name}:
        final attachment = FrontReplyAttachment.fromWireName(name);
        if (attachment == null || !available.contains(attachment)) {
          dropped.add('show "$name", which no lookup made this turn');
        } else if (placed.add(attachment)) {
          read.add(FrontReplyShow(attachment));
        }
      default:
        dropped.add(
          '$part, not a part: each is {"text": …}, {"cards": [...]} or '
          '{"show": …}',
        );
    }
  }
  final texts = [
    for (final part in read)
      if (part is FrontReplyText) part.markdown,
  ];
  if (texts.isEmpty) {
    throw const FrontReplyLayoutException(
      'Error: reply_to_user needs your words: a message, or a text part.',
    );
  }
  final unlisted = [
    for (final row in dueRows)
      if (_kinds[row.kind] case final kind?
          when listed.add('${kind.name}:${row.id}'))
        FrontEntityReference(kind: kind, id: row.id, title: row.title),
  ];
  return (
    text: texts.join('\n\n'),
    parts: [
      ...read,
      if (unlisted.isNotEmpty) FrontReplyCards(unlisted),
      for (final attachment in FrontReplyAttachment.values)
        if (available.contains(attachment) && !placed.contains(attachment))
          FrontReplyShow(attachment),
    ],
    dropped: dropped,
  );
}

/// The kinds a card can show, from the router's.
const Map<FrontDestinationKind, FrontEntityKind> _kinds = {
  FrontDestinationKind.task: FrontEntityKind.task,
  FrontDestinationKind.project: FrontEntityKind.project,
};

/// The card [raw] names, or null when it is not a task or project of
/// [visible].
FrontEntityReference? _referenceOf(
  Object? raw,
  Map<String, FrontIndexRow> visible,
) {
  final row = raw is String ? visible[raw.trim()] : null;
  final kind = row == null ? null : _kinds[row.kind];
  if (row == null || kind == null) return null;
  return FrontEntityReference(kind: kind, id: row.id, title: row.title);
}

/// [rows] by the `kind:id` the index and the lookups list them as.
Map<String, FrontIndexRow> frontVisibleRows(Iterable<FrontIndexRow> rows) => {
  for (final row in rows) '${row.kind.wireName}:${row.id}': row,
};
