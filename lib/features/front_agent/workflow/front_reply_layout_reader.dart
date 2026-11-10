import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// A `reply_to_user` the reader refused, with the error she is told so she
/// can correct it in the same turn.
class FrontReplyLayoutException implements Exception {
  const FrontReplyLayoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Her reply as stored: `text`, her words, which is what is spoken, kept in
/// the conversation and shown when a reply has nothing else; and `parts`,
/// what is drawn, in order.
typedef FrontReplyLayout = ({String text, List<FrontReplyPart> parts});

/// Reads `reply_to_user`'s [message] and [parts] into the reply as stored,
/// or throws a [FrontReplyLayoutException].
///
/// A part is `{"text": …}`, `{"cards": ["task:<id>", …]}` or
/// `{"show": "<attachment>"}`. A card must be a task or project of
/// [visible] — what the turn could see, by `kind:id` — and a `show` one of
/// [available], what this turn's lookups made: nothing is drawn for an id
/// she made up or a chart no lookup produced. A [message] given beside
/// [parts] leads them as words. Her words pass through [link].
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
  if (parts != null && parts is! List) {
    throw const FrontReplyLayoutException(
      'Error: parts is a list of {"text": …}, {"cards": [...]} or '
      '{"show": …}.',
    );
  }
  final words = message is String ? message.trim() : '';
  final read = <FrontReplyPart>[
    if (words.isNotEmpty) FrontReplyText(link(words)),
  ];
  final listed = <String>{};
  final placed = <FrontReplyAttachment>{};
  for (final part in parts as List? ?? const []) {
    switch (part) {
      case {'text': final String text}:
        if (text.trim().isNotEmpty) read.add(FrontReplyText(link(text.trim())));
      case {'cards': final List<Object?> cards}:
        final references = [
          for (final card in cards)
            if (_referenceOf(card, visible) case final reference
                when listed.add('${reference.kind.name}:${reference.id}'))
              reference,
        ];
        if (references.isNotEmpty) read.add(FrontReplyCards(references));
      case {'show': final Object? name}:
        final attachment = FrontReplyAttachment.fromWireName(name);
        if (attachment == null || !available.contains(attachment)) {
          throw FrontReplyLayoutException(
            'Error: show "$name" has nothing to draw this turn; it can show '
            '${available.isEmpty ? 'nothing' : available.map((a) => a.wireName).join(', ')}.',
          );
        }
        if (placed.add(attachment)) read.add(FrontReplyShow(attachment));
      default:
        throw FrontReplyLayoutException(
          'Error: $part is not a part: each is {"text": …}, '
          '{"cards": ["task:<id>", …]} or {"show": …}.',
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
  );
}

/// The kinds a card can show, from the router's.
const Map<FrontDestinationKind, FrontEntityKind> _kinds = {
  FrontDestinationKind.task: FrontEntityKind.task,
  FrontDestinationKind.project: FrontEntityKind.project,
};

/// The card [raw] names, or a [FrontReplyLayoutException] when it is not a
/// task or project of [visible].
FrontEntityReference _referenceOf(
  Object? raw,
  Map<String, FrontIndexRow> visible,
) {
  final row = raw is String ? visible[raw.trim()] : null;
  final kind = row == null ? null : _kinds[row.kind];
  if (row == null || kind == null) {
    throw FrontReplyLayoutException(
      'Error: $raw in cards is not a task or project listed under '
      '<routing_index> or returned by a lookup this turn. Pass each as '
      'listed, e.g. "task:<id>", or leave it out.',
    );
  }
  return FrontEntityReference(kind: kind, id: row.id, title: row.title);
}

/// [rows] by the `kind:id` the index and the lookups list them as.
Map<String, FrontIndexRow> frontVisibleRows(Iterable<FrontIndexRow> rows) => {
  for (final row in rows) '${row.kind.wireName}:${row.id}': row,
};
