import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';

/// A position in the captured input log — a strict total order over captured
/// (synced, never live-read) metadata, so two devices holding the same log
/// agree on every comparison:
///
/// 1. [at] — capture time. Events append in capture order, which is what makes
///    the rendered tail append-only on a device.
/// 2. [sourceAt] — the chronological sub-key *within* one capture instant: a
///    wake that captures many sources writes them in one transaction with a
///    shared [at], and this orders that batch by source chronology instead of
///    by random ids (an initial capture of an old task renders months of
///    entries in order, not shuffled).
/// 3. [key] — a unique, synced tiebreak.
class EventPosition extends Equatable implements Comparable<EventPosition> {
  /// Creates a position.
  const EventPosition({
    required this.at,
    required this.sourceAt,
    required this.key,
  });

  /// Capture time (the link/message `createdAt`).
  final DateTime at;

  /// Within-instant chronological sub-key: a content event's
  /// `sourceCreatedAt`; a retraction's own capture time.
  final DateTime sourceAt;

  /// Unique deterministic tiebreak (ids sync with the log, so all devices
  /// compare identically).
  final String key;

  @override
  int compareTo(EventPosition other) {
    final byTime = at.compareTo(other.at);
    if (byTime != 0) return byTime;
    final byChrono = sourceAt.compareTo(other.sourceAt);
    if (byChrono != 0) return byChrono;
    return key.compareTo(other.key);
  }

  /// Whether this position sorts strictly after [other].
  bool isAfter(EventPosition other) => compareTo(other) > 0;

  @override
  List<Object?> get props => [at, sourceAt, key];
}

/// One input-log **event** — a `messagePayload` link (user content), an
/// `observation` message (the agent's own note), or an inline event derived
/// from other synced log entities (e.g. a retraction or proposal verdict) —
/// as appended, never folded into per-source state. The event stream is
/// append-only by construction: an edit of a source appends a new event (new
/// digest) and the earlier event keeps its position and content forever.
class InputEvent extends Equatable {
  /// Creates a payload-backed event. [isEdit] is true when an earlier content
  /// event exists for the same [contentEntryId] (computed by
  /// [projectInputEvents]).
  const InputEvent({
    required this.position,
    required this.contentEntryId,
    required this.contentDigest,
    required this.sourceCreatedAt,
    required this.isEdit,
    this.isObservation = false,
  }) : inlineContent = null,
       deferredInline = false;

  /// Creates an event whose content is carried inline rather than behind a
  /// content-addressed payload — for events derived deterministically from
  /// other synced entities (e.g. resolved proposal verdicts), where a payload
  /// row would duplicate data the log already holds.
  const InputEvent.inline({
    required this.position,
    required this.contentEntryId,
    required this.sourceCreatedAt,
    required Map<String, Object?> this.inlineContent,
  }) : contentDigest = null,
       isEdit = false,
       isObservation = false,
       deferredInline = false;

  /// Creates an inline event whose content is **resolved on demand** rather
  /// than carried eagerly — for large, already-synced sources (e.g. day
  /// capture transcripts) where loading every source's content on every wake
  /// is wasteful. The position + [contentEntryId] are enough for ordering and
  /// the checkpoint completeness check (which keys on [contentEntryId], not
  /// content), so a covered event never needs its content loaded again; only
  /// the post-cutoff tail the compactor actually renders is resolved (via
  /// `AgentLogCompactor.resolveInlineContent`).
  const InputEvent.inlineDeferred({
    required this.position,
    required this.contentEntryId,
    required this.sourceCreatedAt,
  }) : contentDigest = null,
       inlineContent = null,
       isEdit = false,
       isObservation = false,
       deferredInline = true;

  /// The event's position in the log.
  final EventPosition position;

  /// The originating entity (provenance).
  final String contentEntryId;

  /// The content-addressed payload this event captured, or null for an
  /// inline event (see [inlineContent]).
  final String? contentDigest;

  /// Inline rendered content for events not backed by a payload, or null
  /// for payload-backed and [deferredInline] events. For a non-deferred event,
  /// exactly one of this and [contentDigest] is set.
  final Map<String, Object?>? inlineContent;

  /// True when this is an inline event whose content is resolved lazily (see
  /// [InputEvent.inlineDeferred]): both [contentDigest] and [inlineContent]
  /// are null, and the compactor fetches content via its resolver only for the
  /// tail events it renders.
  final bool deferredInline;

  /// The source's snapshotted chronological position.
  final DateTime sourceCreatedAt;

  /// True when an earlier content event exists for the same source — the
  /// rendered line carries an `edited` tag so the model knows the line
  /// supersedes one above (or one already folded into the summary).
  final bool isEdit;

  /// True when this event is one of the agent's own journal observations
  /// rather than captured user content. Observations share the log substrate
  /// — same ordering, folds and cutoff — and render with an `observation`
  /// type tag.
  final bool isObservation;

  @override
  List<Object?> get props => [
    position,
    contentEntryId,
    contentDigest,
    inlineContent,
    sourceCreatedAt,
    isEdit,
    isObservation,
    deferredInline,
  ];
}

/// The event-log view of an agent's captured inputs: [events] in position
/// order. Retractions are not a separate channel — each appears as an inline
/// retraction [InputEvent] in this same stream. Produced by
/// [projectInputEvents].
class InputEventLog extends Equatable {
  /// Wraps a projection result.
  const InputEventLog({required this.events});

  /// Input-log events in position order.
  final List<InputEvent> events;

  /// True when nothing was ever captured.
  bool get isEmpty => events.isEmpty;

  @override
  List<Object?> get props => [events];
}

/// Projects the agent's captured input **event log** (ADR 0016/0020): every
/// non-deleted `messagePayload` link becomes a content event at its capture
/// position, every observation in [observationMessages] an agent-note event,
/// and every retraction message an inline retraction [InputEvent] — nothing is
/// folded into per-source state, so the projection is append-only: appending to
/// the log never changes an existing event's position or content.
///
/// Pure function of the message/link *set* for one agent (input order is
/// irrelevant); two devices holding the same log derive the same event stream.
/// Pre-ADR-0020 payload references (no `contentEntryId`/`sourceCreatedAt`) are
/// not input captures and are skipped, as are soft-deleted rows and
/// observations without a payload pointer.
InputEventLog projectInputEvents({
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
  Iterable<AgentMessageEntity> observationMessages = const [],
  Iterable<InputEvent> inlineEvents = const [],
}) {
  final events = <InputEvent>[...inlineEvents];
  for (final link in links) {
    if (link is! MessagePayloadLink || link.deletedAt != null) continue;
    final entryId = link.contentEntryId;
    final sourceCreatedAt = link.sourceCreatedAt;
    if (entryId == null || sourceCreatedAt == null) continue;
    events.add(
      InputEvent(
        position: EventPosition(
          at: link.createdAt,
          sourceAt: sourceCreatedAt,
          // `|` cannot occur in UUIDs, so the composite cannot alias; the
          // entry-id prefix keeps same-instant same-chronology versions of
          // different sources apart deterministically.
          key: '$entryId|${link.id}',
        ),
        contentEntryId: entryId,
        contentDigest: link.toId,
        sourceCreatedAt: sourceCreatedAt,
        isEdit: false, // recomputed below once the stream is ordered
      ),
    );
  }

  for (final message in observationMessages) {
    if (message.deletedAt != null) continue;
    final payloadId = message.contentEntryId;
    if (payloadId == null) continue;
    events.add(
      InputEvent(
        position: EventPosition(
          at: message.createdAt,
          sourceAt: message.createdAt,
          key: message.id,
        ),
        contentEntryId: message.id,
        contentDigest: payloadId,
        sourceCreatedAt: message.createdAt,
        isEdit: false,
        isObservation: true,
      ),
    );
  }

  for (final message in messages) {
    if (message.deletedAt != null) continue;
    final retracted = message.metadata.retractsContentEntryId;
    if (retracted == null) continue;
    final eventKey = _retractionEventKey(retracted, message.id);
    events.add(
      InputEvent.inline(
        position: EventPosition(
          at: message.createdAt,
          sourceAt: message.createdAt,
          key: eventKey,
        ),
        contentEntryId: eventKey,
        sourceCreatedAt: message.createdAt,
        inlineContent: <String, Object?>{
          'entryType': 'retraction',
          'sourceEntryId': retracted,
          'text': 'no longer appears in the current task context',
        },
      ),
    );
  }

  events.sort((a, b) => a.position.compareTo(b.position));

  // An event is an edit when any earlier content event exists for its source.
  // Observation ids and retraction event ids are unique messages, and other
  // inline events carry their own identity, so none of them trip this.
  final seen = <String>{};
  for (var i = 0; i < events.length; i++) {
    final digest = events[i].contentDigest;
    if (!seen.add(events[i].contentEntryId) &&
        !events[i].isObservation &&
        digest != null) {
      events[i] = InputEvent(
        position: events[i].position,
        contentEntryId: events[i].contentEntryId,
        contentDigest: digest,
        sourceCreatedAt: events[i].sourceCreatedAt,
        isEdit: true,
      );
    }
  }

  return InputEventLog(events: events);
}

/// The events a wake renders verbatim: every event positioned strictly after
/// [cutoff] (the active checkpoint's covered log prefix; null means no
/// checkpoint — render from the beginning).
///
/// Append-only guarantee: the visible tail for a log `L` is a strict prefix of
/// the visible tail for `L` plus later-appended events. Retractions append
/// their own line, documenting the change without removing earlier captures.
List<InputEvent> visibleTailEvents({
  required InputEventLog log,
  EventPosition? cutoff,
}) {
  return [
    for (final event in log.events)
      if (cutoff == null || event.position.isAfter(cutoff)) event,
  ];
}

String _retractionEventKey(String contentEntryId, String messageId) =>
    'retraction|$contentEntryId|$messageId';
