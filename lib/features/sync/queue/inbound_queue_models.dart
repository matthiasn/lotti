import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:matrix/matrix.dart';

/// Public result of a queue-side enqueue call. `accepted + dupes +
/// filteredOutByType + deferredPendingDecryption` always equals the
/// number of events passed in.
class EnqueueResult {
  const EnqueueResult({
    required this.accepted,
    required this.duplicatesDropped,
    required this.filteredOutByType,
    required this.deferredPendingDecryption,
  });

  final int accepted;
  final int duplicatesDropped;

  /// Rejected because `MatrixEventClassifier.isSyncPayloadEvent` was
  /// false — state events, redactions, etc. (F4).
  final int filteredOutByType;

  /// Rejected because the Matrix event was still encrypted at enqueue
  /// time. Producers must lower the durable resume floor before skipping it
  /// so a later bridge revisits the event after the Matrix SDK receives its
  /// decryption key (F3).
  final int deferredPendingDecryption;

  static const empty = EnqueueResult(
    accepted: 0,
    duplicatesDropped: 0,
    filteredOutByType: 0,
    deferredPendingDecryption: 0,
  );
}

/// Retry classification the worker hands back to the queue.
enum RetryReason {
  missingBase,
  retriable,
  decryptionPending,

  /// A protocol barrier is waiting for an older row in the same room to
  /// leave the active queue. Unlike generic retries, this is not capped by an
  /// attempt count: the older row owns its own retry/abandon lifecycle, and
  /// the barrier must remain ordered behind it until that lifecycle settles.
  pendingBarrier,

  /// Waiting for an attachment JSON (descriptor or agent entity
  /// payload) to land on disk. Retried with a longer backoff ladder
  /// and a wall-clock timeout instead of the generic attempt cap —
  /// see `ApplyOutcome.pendingAttachment`.
  pendingAttachment,
}

/// A queue row materialised for the worker. [rawJson] is the bytes the
/// worker passes to `Event.fromJson(room, ...)` at apply time; the
/// queue itself does not keep SDK objects alive.
class InboundQueueEntry {
  const InboundQueueEntry({
    required this.queueId,
    required this.eventId,
    required this.roomId,
    required this.originTs,
    required this.enqueuedAt,
    required this.attempts,
    required this.rawJson,
  });

  /// Hydrates an entry from its database [row].
  factory InboundQueueEntry.fromRow(InboundEventQueueItem row) =>
      InboundQueueEntry(
        queueId: row.queueId,
        eventId: row.eventId,
        roomId: row.roomId,
        originTs: row.originTs,
        enqueuedAt: row.enqueuedAt,
        attempts: row.attempts,
        rawJson: row.rawJson,
      );

  final int queueId;
  final String eventId;
  final String roomId;
  final int originTs;
  final int enqueuedAt;
  final int attempts;
  final String rawJson;

  /// Materialises the stored event against the given [room]. The room
  /// must belong to the same client the event was enqueued from.
  Event toEvent(Room room) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return Event.fromJson(decoded, room);
  }
}

/// Lightweight depth snapshot emitted on the queue's depth-change stream so UI
/// and back-pressure logic can react without re-querying the database.
class QueueDepthSignal {
  const QueueDepthSignal({
    required this.total,
    this.abandoned = 0,
  });

  /// Active depth — `enqueued` + `leased` + `retrying`. Never
  /// includes `applied` or `abandoned` rows so "queue is empty"
  /// still means "nothing to drain."
  final int total;

  /// Count of abandoned ledger rows — sync events the worker gave
  /// up on after exhausting retries. Feeds the Sync Settings badge
  /// + "Retry skipped" action.
  final int abandoned;
}

/// Fuller queue snapshot than [QueueDepthSignal]: alongside active depth it
/// carries the `applied`/`abandoned`/`retrying` ledger counts for diagnostics
/// and the Sync Settings UI.
class QueueStats {
  const QueueStats({
    required this.total,
    required this.byProducer,
    required this.oldestEnqueuedAt,
    this.applied = 0,
    this.abandoned = 0,
    this.retrying = 0,
  });

  /// Active-queue depth — rows the worker can still drain (`enqueued`
  /// + `leased` + `retrying`). Excludes `applied` and `abandoned` so
  /// callers that throttle against depth (bootstrap back-pressure,
  /// UI) do not inflate their numbers with the ledger history.
  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int? oldestEnqueuedAt;

  /// Count of `status='applied'` rows — the ledger of everything the
  /// queue has successfully committed. Diagnostic / UI only.
  final int applied;

  /// Count of `status='abandoned'` rows — events the worker gave up
  /// on. Resurrection via `AttachmentIndex.pathRecorded` or
  /// `JournalDb.updateStream` (or a user-triggered retry) flips them
  /// back to `enqueued`.
  final int abandoned;

  /// Count of `status='retrying'` rows with a future `next_due_at`.
  final int retrying;
}

/// Resolves a stored `producer` column value back to the enum.
/// Unknown names (from a future producer this build does not know
/// about) fall back to [InboundEventProducer.live].
InboundEventProducer producerFromName(String name) {
  for (final p in InboundEventProducer.values) {
    if (p.name == name) return p;
  }
  return InboundEventProducer.live;
}

/// Status values mirroring the `status` column on
/// `inbound_event_queue`. Lifecycle diagram:
///
///     enqueued ─► leased ─┬─► applied  (commitApplied)
///         ▲               ├─► retrying ─► leased ...
///         │               └─► abandoned (markSkipped after max attempts)
///         │
///         └── resurrectByPaths / resurrectAll (from abandoned)
///
/// The string literals must stay in sync with the partial-index DDL
/// in `lib/database/sync_db.dart` (and the literal SQL fragments in
/// `QueueMarkerAdvancer` / `InboundQueueResurrection`), which inline
/// the same values so the SQLite planner can match the partial
/// indices at plan time.
abstract final class InboundQueueStatuses {
  static const String enqueued = 'enqueued';
  static const String leased = 'leased';
  static const String retrying = 'retrying';
  static const String applied = 'applied';
  static const String abandoned = 'abandoned';

  /// Statuses the worker can still drain. Peek + clamp queries filter
  /// on this set so the applied ledger (bounded only by retention, not
  /// by correctness) never touches the hot paths.
  static const List<String> active = <String>[enqueued, leased, retrying];
}
