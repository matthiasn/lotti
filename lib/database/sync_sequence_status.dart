part of 'sync_db.dart';

/// Producer tag for an [InboundEventQueueItem]. Identifies which
/// ingestion path enqueued the event so diagnostics can break down
/// queue depth by source and so bootstrap-specific back-pressure can
/// target the right writer.
enum InboundEventProducer { live, bridge, bootstrap, backfill }

/// Status for entries in the sync sequence log.
/// Tracks whether an entry was received, is missing, or has been backfilled.
enum SyncSequenceStatus {
  /// Entry was received and processed successfully
  received,

  /// Gap detected - entry expected but not yet received
  missing,

  /// Backfill request has been sent for this entry
  requested,

  /// Entry was received via backfill after being marked missing
  backfilled,

  /// Responder confirmed the entry was purged/deleted
  deleted,

  /// Receiver give-up: a `missing`/`requested` row that never resolved after
  /// exhausting backfill retries (`retireExhaustedRequestedEntries`) or aging
  /// past the amnesty window (`retireAgedOutRequestedEntries`). The payload's
  /// fate is genuinely unknown — it may still be recoverable from a peer, so
  /// the row stays reopenable: a later backfill hint flips it back to
  /// [requested], and the "Ask peers again for unresolvable" action re-asks.
  /// Counts as resolved for the watermark so a permanently lost counter does
  /// not block the contiguous prefix forever. Distinct from the authoritative
  /// [burned] non-event.
  unresolvable,

  /// Own-host counter was reserved but has not yet been bound to an outbound
  /// payload. This is a durable crash-recovery marker: if the process exits
  /// before a later `recordSentEntry` overwrites it, the row stays forensic
  /// instead of disappearing into an unexplained sequence hole.
  reserved,

  /// Own-host reservation was explicitly released without a payload, but the
  /// durable broadcast has not completed yet. Startup reconciliation retries
  /// these rows, upgrading each to a [burned] marker once the outbound
  /// `unresolvable=true` broadcast is enqueued.
  burnPending,

  /// Authoritative non-event: the originating host confirmed this counter
  /// carries no payload — a vector-clock reservation released without a
  /// write, or a value superseded before being recorded. Terminal and
  /// benign, like a voided number in a monotonic invoice sequence: there is
  /// nothing to fetch. Reached on the originator via
  /// `recordOwnUnresolvableSequenceCounter` and on a peer when a backfill
  /// response carries `unresolvable=true` (the originator is authoritative
  /// for its own counters). Counts as resolved for the watermark so it never
  /// blocks the contiguous prefix. Distinct from [unresolvable].
  burned,
}

/// Terminal sequence states that satisfy the contiguous-prefix watermark.
///
/// Single source of truth for the "resolved" set. The watermark CTEs in
/// [SyncDatabase] and the partial index
/// `idx_sync_sequence_log_resolved_host_counter` inline the matching status
/// indices as SQL literals (`IN (0, 3, 4, 5, 8)`); keep those aligned with
/// this getter — a property test pins them together.
extension SyncSequenceStatusX on SyncSequenceStatus {
  /// Whether this status counts as resolved for the contiguous-prefix
  /// watermark — i.e. it will never carry a future payload and so must not
  /// block the prefix from advancing past its counter.
  bool get isResolved =>
      this == SyncSequenceStatus.received ||
      this == SyncSequenceStatus.backfilled ||
      this == SyncSequenceStatus.deleted ||
      this == SyncSequenceStatus.unresolvable ||
      this == SyncSequenceStatus.burned;
}

bool _isResolvedSequenceStatusIndex(int status) =>
    status >= 0 &&
    status < SyncSequenceStatus.values.length &&
    SyncSequenceStatus.values[status].isResolved;
