/// Stats for backfill status per host.
class BackfillHostStats {
  const BackfillHostStats({
    required this.receivedCount,
    required this.missingCount,
    required this.requestedCount,
    required this.backfilledCount,
    required this.deletedCount,
    required this.unresolvableCount,
    required this.burnedCount,
  });

  final int receivedCount;
  final int missingCount;
  final int requestedCount;
  final int backfilledCount;
  final int deletedCount;
  final int unresolvableCount;

  /// Authoritative non-events (`SyncSequenceStatus.burned`): counters the
  /// originating host confirmed carry no payload. Benign — split out of
  /// [unresolvableCount] so diagnostics don't read voided counters as loss.
  final int burnedCount;
}

/// Aggregate stats across all hosts.
class BackfillStats {
  const BackfillStats({
    required this.hostStats,
    required this.totalReceived,
    required this.totalMissing,
    required this.totalRequested,
    required this.totalBackfilled,
    required this.totalDeleted,
    required this.totalUnresolvable,
    required this.totalBurned,
  });

  factory BackfillStats.fromHostStats(List<BackfillHostStats> stats) {
    return BackfillStats(
      hostStats: stats,
      totalReceived: stats.fold(0, (sum, s) => sum + s.receivedCount),
      totalMissing: stats.fold(0, (sum, s) => sum + s.missingCount),
      totalRequested: stats.fold(0, (sum, s) => sum + s.requestedCount),
      totalBackfilled: stats.fold(0, (sum, s) => sum + s.backfilledCount),
      totalDeleted: stats.fold(0, (sum, s) => sum + s.deletedCount),
      totalUnresolvable: stats.fold(0, (sum, s) => sum + s.unresolvableCount),
      totalBurned: stats.fold(0, (sum, s) => sum + s.burnedCount),
    );
  }

  final List<BackfillHostStats> hostStats;
  final int totalReceived;
  final int totalMissing;
  final int totalRequested;
  final int totalBackfilled;
  final int totalDeleted;
  final int totalUnresolvable;
  final int totalBurned;

  int get totalEntries =>
      totalReceived +
      totalMissing +
      totalRequested +
      totalBackfilled +
      totalDeleted +
      totalUnresolvable +
      totalBurned;
}

/// Sync and Outbox tuning constants, centralized for easy documentation and
/// future adjustments. Values are chosen to balance responsiveness and UI
/// smoothness while preventing redundant work under bursty conditions.
class SyncTuning {
  // Outbox
  /// Maximum number of text-only outbox rows packed into a single
  /// `SyncOutboxBundle` by `OutboxProcessor`. Tuneable up to 100.
  /// Media-attachment rows (filePath != null) are never bundled — they ship
  /// individually so receivers keep their existing per-attachment handling.
  static const int outboxBundleMaxSize = 50;

  /// Hard cap on the post-gzip size of an outbox bundle's manifest payload.
  /// The cap is a defence-in-depth signal: an outbox bundle of
  /// [outboxBundleMaxSize] text-only rows is expected to land well under this
  /// budget in production. If a bundle's gzipped manifest exceeds this size,
  /// `MatrixMessageSender` aborts the send and the rows stay pending so the
  /// next drain pass can re-claim a smaller batch.
  static const int outboxBundleMaxBytes = 8 * 1024 * 1024;

  /// Schema version for outbox bundle manifests. Bumped when the on-the-wire
  /// shape (envelope/payload record) changes incompatibly. Receivers reject
  /// unknown versions and rely on the surrounding outbox-row retry to
  /// re-deliver under a future-compatible code path.
  static const int outboxBundleManifestVersion = 1;
  static const Duration outboxRetryDelay = Duration(seconds: 5);
  static const Duration outboxErrorDelay = Duration(seconds: 15);
  static const int outboxMaxRetriesDiagnostics = 10; // surface issues w/o loops
  static const Duration outboxSendTimeout = Duration(seconds: 20); // Matrix RTT
  /// Lease duration for an atomically claimed outbox row. If the claiming
  /// worker crashes mid-send and does not release the row (markSent/markRetry),
  /// another worker can re-claim the row once this lease expires. Must stay
  /// comfortably above [outboxSendTimeout] so an in-flight send is never
  /// stolen from a healthy worker.
  static const Duration outboxClaimLease = Duration(minutes: 1);
  static const Duration outboxWatchdogInterval = Duration(seconds: 10);
  static const Duration outboxDbNudgeDebounce = Duration(milliseconds: 50);
  static const Duration outboxIdleThreshold = Duration(milliseconds: 1200);

  /// Settle window after a successful drain pass before attempting one more
  /// drain. Lets bursty enqueues (rapid edits, imports, multi-entity flows)
  /// coalesce into the next bundle so the outbox ships fewer, fuller trains
  /// instead of one bundle per write. Sized well above [outboxDbNudgeDebounce]
  /// so a row landing in DB during the settle is reliably observed by the
  /// follow-up drain.
  static const Duration outboxPostDrainSettle = Duration(milliseconds: 1500);

  /// Upper bound on a single Matrix attachment download + decrypt. A hang
  /// here used to stall the entire apply pipeline — the scan never
  /// completed, `_scanInFlight` stayed set, and every subsequent timeline
  /// signal was silently coalesced into `_liveScanDeferred`. Converting
  /// the hang into a `FileSystemException` lets the retry tracker
  /// reschedule with backoff and frees the pipeline for other events.
  static const Duration attachmentDownloadTimeout = Duration(seconds: 45);

  // Historical windows
  static const int catchupMaxLookback =
      10000; // Increased from 1000 to handle larger backlogs

  // Backfill tuning - self-healing sync for missing entries
  static const Duration backfillRequestInterval = Duration(minutes: 2);
  static const int backfillMaxRequestCount = 10;

  /// Grace window between a row being first flagged as `missing` by gap
  /// detection and the first backfill request firing for it.
  ///
  /// Baseline sync is now reliable (0 missing after a 460-entry offline
  /// catch-up with backfill disabled), so any "missing" row is almost
  /// always a transient reordering artifact — priority messages can jump
  /// ahead of standard ones and briefly make them look missing. Without
  /// this delay, a single priority message arriving out of sequence can
  /// cause hundreds of backfill requests that duplicate traffic already
  /// in flight. With the delay, the normal sync path gets a chance to
  /// deliver the older messages first; only rows that are STILL missing
  /// after the window become eligible for a backfill request.
  ///
  /// Enforced at query time in `SyncDatabase.getMissingEntries` and
  /// `SyncDatabase.getMissingEntriesWithLimits` — rows that transition
  /// out of `missing` during the window are no longer returned (no
  /// cancellation logic needed).
  static const Duration backfillMissingDebounce = Duration(minutes: 10);

  // Large-gap logging threshold.
  // Gaps larger than this are still fully materialized so backfill can recover
  // them, but they are logged explicitly for diagnostics.
  static const int maxGapSize = 100;
  // Materialize large gaps in bounded chunks so a pathological counter jump
  // does not require a single huge in-memory batch.
  static const int gapMaterializationChunkSize = 5000;
  // Additional warning threshold for extreme gaps. We still preserve the full
  // gap for correctness; this only improves observability.
  static const int extremeGapWarningSize = 10000;

  // Upper bound on events committed together in a single
  // `_journalDb.transaction` inside `MatrixStreamProcessor._processOrderedInternal`.
  // Holding one transaction for the full ordered slice lets Drift coalesce
  // stream emissions but also holds the writer lock, so a 87-event catch-up
  // blocks user-driven entry writes for the whole slice. Committing in
  // chunks lets user writes interleave between chunks while still coalescing
  // per chunk. Tune together with the attachment download concurrency —
  // commits are expected to take roughly chunkSize × per-event cost.
  static const int processOrderedChunkSize = 20;

  // Maximum number of attachment-descriptor events that the bootstrap
  // catch-up sink processes concurrently. The inner queue sink does not
  // wait for attachment work (fire-and-forget by contract), but the pre-
  // existing loop fired `unawaited(_processAttachment(event))` per event
  // in a page — which, on a 200-event page, means 200 async bodies run
  // up to their first await synchronously on the main isolate before it
  // gets to yield. On slow disks (Parallels-backed Linux) this shows up
  // as visible UI stalls during catch-up. Cap the fan-out to a small
  // worker pool so the main isolate can breathe between attachments.
  // Downloads themselves stay gated by AttachmentIngestor's own
  // `_maxConcurrentDownloads` — this bound is purely about scheduling
  // cost per page.
  static const int bootstrapAttachmentConcurrency = 4;

  // Default upper bound for the queue's generic `peekBatchReady` call
  // — used by ad-hoc inspection paths (settings UI, tests) where
  // returning more rows is harmless. The InboundWorker overrides this
  // at every call site with its own [inboundWorkerBatchSize] policy.
  static const int peekBatchReadyDefault = processOrderedChunkSize;

  // Size of the batch the InboundWorker drains in a single
  // `runWithDeferredMissingEntries` window.
  //
  // Originally aliased to [processOrderedChunkSize] (20) under the
  // assumption that each queue entry was a thin envelope (~2 KB on the
  // wire, one entity per Matrix event); 20-way parallel prepare paid
  // off because the per-entry I/O was a single small attachment
  // download.
  //
  // With dequeue-time outbox bundling (`SyncMessage.outboxBundle`),
  // one queue entry now carries up to [outboxBundleMaxSize] inline
  // children plus their `JournalEntity` payloads in a single gzipped
  // manifest. Twenty bundles in flight = up to 1000 entities + 1000
  // saveJson calls + ~50 MB of decoded entity objects sitting in
  // memory before any of them commits. The receiver-side stalls and
  // step-of-20 progress jumps observed during heavy backfill
  // (PR #3038) traced back to that fan-out.
  //
  // A bundle already amortizes 50 entities into a single download, so
  // the per-batch parallelism added little on top. Drop the worker to
  // batch size 1: each entry runs prepare → apply → commit in
  // sequence, queue depth ticks down per row (smooth visible
  // progress), memory peak is bounded by one bundle, and thermal load
  // drops because we no longer fan out 20 compute-isolate decode hops
  // in parallel.
  static const int inboundWorkerBatchSize = 1;

  // Worker lease TTL stamped onto a queue entry by `peekBatchReady`.
  // Survives crashes: an expired lease makes the entry peekable
  // again, so a killed worker cannot strand rows indefinitely.
  // Generously larger than the expected per-entry apply time so
  // normal apply never hits a self-expiring lease.
  static const Duration inboundWorkerLeaseDuration = Duration(seconds: 60);

  // Maximum entries to process from an incoming backfill request.
  // Prevents a single large request from flooding the outbox.
  static const int maxBackfillResponseBatchSize = 2000;

  // Maximum entries to process per processing cycle
  static const int backfillProcessingBatchSize = 2000;

  // Response deduplication - prevents responding to the same (hostId, counter)
  // pair multiple times across request cycles (N-device amplification prevention).
  static const Duration backfillResponseCooldown = Duration(minutes: 5);

  // Rate limiting - caps total backfill responses per time window to prevent
  // outbox flooding during amplification storms.
  static const Duration backfillResponseRateWindow = Duration(minutes: 1);
  static const int backfillResponseRateLimit = 10000;

  // Maximum number of entry links to embed inline in a SyncJournalEntity
  // envelope. Links beyond this cap are omitted from the envelope — they sync
  // independently as SyncEntryLink messages. This prevents entries with many
  // links from creating oversized Matrix messages.
  static const int maxEmbeddedEntryLinks = 25;

  // Default limits for automatic backfill (prevents unbounded historical sync)
  // Only request entries from the last day OR 250 entries per host, whichever
  // is more restrictive. Deeper historical backfill requires manual trigger.
  static const Duration defaultBackfillMaxAge = Duration(days: 1);
  static const int defaultBackfillMaxEntriesPerHost = 250;

  // Amnesty window for age-based sequence-log retirement. Rows in
  // `missing`/`requested` status older than this are promoted to
  // `unresolvable` by `retireAgedOutRequestedEntries` regardless of
  // `request_count` or `last_requested_at`. Must be wider than
  // [defaultBackfillMaxAge] so rows have a fair window to be requested
  // before retirement, but narrow enough that truly stuck rows do not
  // accumulate indefinitely and block the sequence-log watermark.
  static const Duration backfillAmnestyWindow = Duration(days: 7);

  // Outbox retention for `status = sent` rows. Error rows are kept
  // forever so a human can inspect persistently failed sends. Pending
  // and sending rows are live state and never eligible for pruning.
  // Observed growth without pruning: 395k rows on desktop, 265k on
  // mobile — direct contributor to slow outbox enqueue/dedup queries.
  // 7 days is enough for any forensic lookup in the recent-past
  // window; dedup on `outbox_entry_id` only needs overlap across
  // in-flight edits (seconds), so a week is already far more than
  // strictly required.
  static const Duration outboxSentRetention = Duration(days: 7);

  // Cadence at which [OutboxService] runs the sent-outbox prune in the
  // background. Daily is plenty: the prune deletes a whole day of
  // newly-expired rows in a single pass and is cheap enough that
  // running more often buys nothing.
  static const Duration outboxPruneInterval = Duration(hours: 24);
}
