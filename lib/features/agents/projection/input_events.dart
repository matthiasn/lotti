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

/// One content capture **event** — a `messagePayload` link (user content), an
/// `observation` message (the agent's own note), or an inline event derived
/// from other synced log entities (e.g. a proposal verdict) — as appended,
/// never folded into per-source state. The event stream is append-only by
/// construction: an edit of a source appends a new event (new digest) and the
/// earlier event keeps its position and content forever.
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
  }) : inlineContent = null;

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
       isObservation = false;

  /// The event's position in the log.
  final EventPosition position;

  /// The originating entity (provenance).
  final String contentEntryId;

  /// The content-addressed payload this event captured, or null for an
  /// inline event (see [inlineContent]).
  final String? contentDigest;

  /// Inline rendered content for events not backed by a payload, or null
  /// for payload-backed events. Exactly one of this and [contentDigest] is
  /// set.
  final Map<String, Object?>? inlineContent;

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
  ];
}

/// One retraction event — a system message tagged `retractsContentEntryId`.
/// Deletions are the **single deliberate exception** to append-only rendering:
/// a retraction suppresses every earlier event of that source from the tail
/// (privacy beats cache) and invalidates checkpoints covering the source.
class RetractionEvent extends Equatable {
  /// Creates a retraction event.
  const RetractionEvent({required this.position, required this.contentEntryId});

  /// The retraction's position in the log.
  final EventPosition position;

  /// The source whose earlier events this retraction suppresses.
  final String contentEntryId;

  @override
  List<Object?> get props => [position, contentEntryId];
}

/// The event-log view of an agent's captured inputs: content [events] and
/// [retractions], each sorted by position. Produced by [projectInputEvents].
class InputEventLog extends Equatable {
  /// Wraps a projection result.
  const InputEventLog({required this.events, required this.retractions});

  /// Content capture events in position order.
  final List<InputEvent> events;

  /// Retraction events in position order.
  final List<RetractionEvent> retractions;

  /// True when nothing was ever captured.
  bool get isEmpty => events.isEmpty && retractions.isEmpty;

  @override
  List<Object?> get props => [events, retractions];
}

/// Projects the agent's captured input **event log** (ADR 0016/0020): every
/// non-deleted `messagePayload` link becomes a content event at its capture
/// position, every observation in [observationMessages] an agent-note event,
/// and every retraction message a [RetractionEvent] — nothing is folded into
/// per-source state, so the projection is append-only: appending to the log
/// never changes an existing event's position or content.
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

  events.sort((a, b) => a.position.compareTo(b.position));

  // An event is an edit when any earlier content event exists for its source.
  // Observation ids are unique messages and inline events carry their own
  // identity, so neither trips this.
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

  final retractions = <RetractionEvent>[];
  for (final message in messages) {
    if (message.deletedAt != null) continue;
    final retracted = message.metadata.retractsContentEntryId;
    if (retracted == null) continue;
    retractions.add(
      RetractionEvent(
        position: EventPosition(
          at: message.createdAt,
          sourceAt: message.createdAt,
          key: message.id,
        ),
        contentEntryId: retracted,
      ),
    );
  }
  retractions.sort((a, b) => a.position.compareTo(b.position));

  return InputEventLog(events: events, retractions: retractions);
}

/// The events a wake renders verbatim: every content event positioned strictly
/// after [cutoff] (the active checkpoint's covered log prefix; null means no
/// checkpoint — render from the beginning), minus events suppressed by a later
/// retraction of their source.
///
/// Append-only guarantee: absent retractions, the visible tail for a log `L`
/// is a strict prefix of the visible tail for `L` plus later-appended events —
/// existing lines never change, new lines only append. A retraction is the one
/// deliberate mutation (it removes that source's earlier lines); a source
/// re-captured after its retraction is visible again (the new event post-dates
/// the retraction).
List<InputEvent> visibleTailEvents({
  required InputEventLog log,
  EventPosition? cutoff,
}) {
  // Latest retraction position per source.
  final latestRetraction = <String, EventPosition>{};
  for (final retraction in log.retractions) {
    // Retractions are position-sorted, so the last write wins correctly.
    latestRetraction[retraction.contentEntryId] = retraction.position;
  }

  return [
    for (final event in log.events)
      if ((cutoff == null || event.position.isAfter(cutoff)) &&
          !_isSuppressed(event, latestRetraction))
        event,
  ];
}

bool _isSuppressed(
  InputEvent event,
  Map<String, EventPosition> latestRetraction,
) {
  final retractedAt = latestRetraction[event.contentEntryId];
  return retractedAt != null && retractedAt.isAfter(event.position);
}
