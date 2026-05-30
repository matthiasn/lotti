import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

const _logSub = 'queue.apply';

/// Bridges [InboundWorker] to the existing
/// [SyncEventProcessor.prepare]/[SyncEventProcessor.apply] path.
///
/// The queue keeps events as JSON and hands the worker an
/// [InboundQueueEntry]. This adapter materialises the Event against the
/// current Room, runs prepare outside a write transaction, and runs
/// apply inside a short `journalDb.transaction` — mirroring the P1
/// freeze fix the legacy pipeline already shipped (PR #2981).
///
/// Per-batch parallel prepare: [bindPrepareBatch] returns a hook that
/// `InboundWorker._runBatch` calls with the whole batch before its
/// per-entry apply loop. Prepare is I/O-bound (attachment downloads,
/// gzip decode, JSON decode) with no shared state, so fanning it out
/// via `Future.wait` collapses the prepare latency of the slowest
/// entry down to the batch's critical path. Apply still runs
/// sequentially inside `journalDb.transaction` to preserve the M1
/// writer-lock discipline. Prepared results are cached by `eventId`
/// so the subsequent per-entry apply call reuses them instead of
/// preparing a second time.
class QueueApplyAdapter {
  QueueApplyAdapter({
    required this._processor,
    required this._journalDb,
    required this._logging,
  });

  final SyncEventProcessor _processor;
  final JournalDb _journalDb;
  final DomainLogger _logging;

  /// Cached prepare outcomes keyed by `eventId`, populated by
  /// [_prepareBatch] and drained one entry at a time by [_applyOne].
  /// A lingering entry here (e.g. a caller asked prepareBatch but
  /// never applied the row) does no harm: the next prepareBatch for
  /// the same eventId simply overwrites it, and apply always
  /// `remove`s so a cache entry survives at most one apply cycle.
  final Map<String, _PreparedState> _preparedCache = <String, _PreparedState>{};

  /// Returns an [InboundApplyFn] ready to wire into an [InboundWorker].
  ///
  /// The function prefers a [_PreparedState] cached by [bindPrepareBatch]
  /// and only re-runs prepare inline when no cache entry is found —
  /// which is the right fallback for direct callers (tests, worker
  /// builds that skip the batch hook) and for the repair path on a
  /// row that was enqueued after the batch's prepare pass.
  InboundApplyFn bind() => _applyOne;

  /// Returns a batch-level prepare hook suitable for the
  /// `prepareBatch` parameter on [InboundWorker]. The hook runs prepare
  /// for every
  /// entry in parallel via `Future.wait` and stores each result in
  /// [_preparedCache]. It never throws — per-entry failures are
  /// captured as a cached terminal [ApplyOutcome] so the subsequent
  /// per-entry apply call can return that outcome without re-running
  /// prepare.
  InboundPrepareBatchFn bindPrepareBatch() => _prepareBatch;

  Future<void> _prepareBatch(
    List<InboundQueueEntry> entries,
    Room room,
  ) async {
    if (entries.isEmpty) return;
    await Future.wait(
      entries.map((entry) async {
        final state = await _prepareEntry(entry, room);
        _preparedCache[entry.eventId] = state;
      }),
    );
  }

  Future<ApplyOutcome> _applyOne(
    InboundQueueEntry entry,
    Room room,
  ) async {
    final cached = _preparedCache.remove(entry.eventId);
    final state = cached ?? await _prepareEntry(entry, room);
    final terminal = state.terminalOutcome;
    if (terminal != null) {
      return terminal;
    }
    return _applyPrepared(entry, state.prepared!);
  }

  /// Deserialises the event and runs prepare. Returns a terminal
  /// outcome when deserialisation or prepare fails; otherwise returns
  /// the [PreparedSyncEvent] ready for apply.
  Future<_PreparedState> _prepareEntry(
    InboundQueueEntry entry,
    Room room,
  ) async {
    // Step 1 — materialise the Event. `Event.fromJson` requires a live
    // Room reference; we do not attempt to recover from a throw here
    // because the stored JSON is produced by `Event.toJson()` from a
    // fully-decrypted event (F3) so construction failures imply the
    // row is unrecoverable.
    final Event event;
    try {
      event = entry.toEvent(room);
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.deserialise',
      );
      return const _PreparedState.terminal(ApplyOutcome.permanentSkip);
    }

    // Step 2 — prepare outside the writer transaction. Downloads,
    // gzip-decompresses, decodes sync payload. Catch `IOException`
    // rather than only `FileSystemException` so network failures from
    // `event.downloadAndDecryptAttachment()` (`SocketException`,
    // `HttpException`, `TlsException`, …) are treated as retriable
    // alongside filesystem errors. `SyncEventProcessor` returns null
    // when the payload is undeserialisable (ArgumentError /
    // FormatException paths inside prepare).
    //
    // A specific sub-case of filesystem failure — the attachment
    // descriptor JSON has not landed on disk yet — classifies as
    // `pendingAttachment` instead. These events routinely race their
    // attachment download; the queue keeps the row in `abandoned`
    // after its retry cap, and `AttachmentIndex.pathRecorded`
    // resurrects it the instant the descriptor arrives. Treating
    // them as plain `retriable` would burn retries on a
    // sub-second curve that loses every event to the apply-cap
    // before the human-scale attachment delivery completes.
    final PreparedSyncEvent? prepared;
    try {
      prepared = await _processor.prepare(event: event);
    } on IOException catch (error, stackTrace) {
      if (_looksLikePendingAttachment(error)) {
        _logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: '$_logSub.prepare.pendingAttachment',
        );
        return const _PreparedState.terminal(ApplyOutcome.pendingAttachment);
      }
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.prepare.retriable',
      );
      return const _PreparedState.terminal(ApplyOutcome.retriable);
    } catch (error, stackTrace) {
      // Unknown error classes (TypeError, StateError, ArgumentError,
      // …) are not transient; retrying them just burns attempts and
      // keeps the entry in the queue until maxAttempts gives up. Treat
      // them as permanent so a logic bug does not stall the worker.
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.prepare.failed',
      );
      return const _PreparedState.terminal(ApplyOutcome.permanentSkip);
    }
    if (prepared == null) {
      _logging.log(
        LogDomain.sync,
        'queue.apply.undeserialisable eventId=${entry.eventId}',
        subDomain: _logSub,
      );
      return const _PreparedState.terminal(ApplyOutcome.permanentSkip);
    }

    return _PreparedState.ready(prepared);
  }

  Future<ApplyOutcome> _applyPrepared(
    InboundQueueEntry entry,
    PreparedSyncEvent prepared,
  ) async {
    // Step 3 — apply. Wrap in a JournalDb writer transaction ONLY for
    // payload families that actually write to JournalDb tables (entity
    // upserts, entry-link upserts, entity-definition upserts). Other
    // families (theming, ai-config, agent entity/link/bundle, outbox
    // bundle, backfill request/response) write to other databases
    // (settings_db, ai_config_db, agent_db, outbox via sync_db) and
    // gain nothing from holding the journal writer lock — but they
    // *cost* readers, who serialise behind the writer for the whole
    // apply duration. The super-slow log captured this as cluster-
    // shaped read waves all unblocking together when a non-journal
    // sync apply released the lock.
    //
    // Apply-time failures are treated as retriable because the event
    // has already survived deserialisation + prepare, so a throw here
    // is much more likely to be a transient writer failure (lock
    // timeout, disk full, temporary schema conflict) than a poison
    // event. `InboundWorker._maybeRetry` caps retries at
    // `_maxAttempts` and then records `maxAttempts(reason)` via
    // `markSkipped`, so we cannot loop forever on a logic bug — the
    // worker eventually gives up without data loss from a premature
    // permanentSkip that would advance the marker past the event.
    // `_writesJournalDb` introspects `prepared.syncMessage`; tests mock
    // `PreparedSyncEvent` without stubbing the field, so guard against
    // a throw by falling back to the safe (wrapped) path.
    var wrap = true;
    try {
      wrap = _writesJournalDb(prepared.syncMessage);
    } catch (_) {
      wrap = true;
    }
    try {
      if (wrap) {
        await _journalDb.transaction(() async {
          await _processor.apply(
            prepared: prepared,
            journalDb: _journalDb,
          );
        });
      } else {
        await _processor.apply(
          prepared: prepared,
          journalDb: _journalDb,
        );
      }
      return ApplyOutcome.applied;
    } on IOException catch (error, stackTrace) {
      if (_looksLikePendingAttachment(error)) {
        _logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: '$_logSub.apply.pendingAttachment',
        );
        return ApplyOutcome.pendingAttachment;
      }
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.apply.retriable',
      );
      return ApplyOutcome.retriable;
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.apply.retriable',
      );
      return ApplyOutcome.retriable;
    }
  }

  /// Returns true when [error] looks like "we are waiting for an
  /// attachment JSON to land on disk" rather than a generic
  /// filesystem / network failure. Two signatures match:
  ///
  /// - A `FileSystemException` we throw ourselves in
  ///   `SmartJournalEntityLoader.load` with the message "attachment
  ///   descriptor not yet available".
  /// - Any `FileSystemException` (including `PathNotFoundException`)
  ///   whose path points inside one of the attachment-carrying
  ///   directories (`/audio/`, `/images/`, `/attachments/`,
  ///   `/agent_entities/`, `/agent_links/`).
  ///
  /// Keeping the match textual rather than relying on a bespoke
  /// exception subtype means we do not have to plumb a new type
  /// through `SyncEventProcessor`; the tradeoff is that a rename of
  /// the error message on the SDK side (rare) falls back to the
  /// plain `retriable` path, which is still safe — the row stays in
  /// the queue, just on the sub-second ladder.
  static bool _looksLikePendingAttachment(IOException error) {
    if (error is FileSystemException) {
      final message = error.message;
      if (message.contains('attachment descriptor not yet available')) {
        return true;
      }
      final path = error.path ?? '';
      const attachmentPrefixes = <String>[
        '/audio/',
        '/images/',
        '/attachments/',
        '/agent_entities/',
        '/agent_links/',
        '/notifications/',
      ];
      for (final prefix in attachmentPrefixes) {
        if (path.contains(prefix)) return true;
      }
    }
    return false;
  }

  /// True for payload families whose `apply` path writes to JournalDb
  /// tables (`journal`, `linked_entries`, `*_definitions`). Other
  /// families resolve their writes against other databases and do not
  /// need the journal writer lock; wrapping them in a JournalDb
  /// transaction is pure overhead and serialises every concurrent
  /// reader. Errs conservatively: any new payload type defaults to
  /// `true` so we keep the old behaviour until explicitly opted out.
  @visibleForTesting
  static bool writesJournalDbForTesting(SyncMessage message) =>
      _writesJournalDb(message);

  static bool _writesJournalDb(SyncMessage message) {
    return message.map(
      // SyncJournalEntity owns its own narrow tx inside
      // `_persistJournalEntity`; the outer wrap used to also encompass
      // cross-DB awaits (sync-sequence log write, queued reads through
      // the entity-by-id coalescer), which held the journal writer
      // lock for hundreds of ms while readers piled up. Bypassing the
      // outer wrap lets those non-journal awaits run without blocking
      // readers; the narrow inner tx still keeps the journal upsert +
      // embedded entry-link writes in one atomic step.
      journalEntity: (_) => false,
      // linked_entries upsert — JournalDb.
      entryLink: (_) => true,
      // category/habit/dashboard/measurable/label _definitions —
      // JournalDb.
      entityDefinition: (_) => true,
      // ai_config_db.
      aiConfig: (_) => false,
      aiConfigDelete: (_) => false,
      // settings_db.
      themingSelection: (_) => false,
      // notifications_db.
      notification: (_) => false,
      notificationStateUpdate: (_) => false,
      // backfill handler does its own DB selection; conservatively
      // wrap so any journal-writing branch stays atomic.
      backfillRequest: (_) => true,
      backfillResponse: (_) => true,
      // agent_db.
      agentEntity: (_) => false,
      agentLink: (_) => false,
      agentBundle: (_) => false,
      // OutboxBundle unpacks into journal/linked_entries via
      // _outboxBundleUnpacker.apply — keep wrapped.
      outboxBundle: (_) => true,
      // settings_db (directory map keyed by hostId).
      syncNodeProfile: (_) => false,
    );
  }
}

/// Output of the adapter's prepare phase. Either the row has already
/// been classified (deserialise failed, prepare threw, or prepare
/// returned null) — in which case [terminalOutcome] is set — or the
/// row is ready for apply and [prepared] carries the resolved payload.
class _PreparedState {
  const _PreparedState.ready(PreparedSyncEvent this.prepared)
    : terminalOutcome = null;
  const _PreparedState.terminal(ApplyOutcome this.terminalOutcome)
    : prepared = null;

  final PreparedSyncEvent? prepared;
  final ApplyOutcome? terminalOutcome;
}
