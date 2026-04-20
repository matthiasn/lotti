import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

export 'package:lotti/database/sync_db.dart' show InboundEventProducer;

/// Public result of a queue-side enqueue call. `accepted + dupes +
/// filteredOutByType + deferredPendingDecryption` always equals the
/// number of events passed in.
class EnqueueResult {
  const EnqueueResult({
    required this.accepted,
    required this.duplicatesDropped,
    required this.filteredOutByType,
    required this.deferredPendingDecryption,
    required this.oldestTsAccepted,
    required this.newestTsAccepted,
  });

  final int accepted;
  final int duplicatesDropped;

  /// Rejected because [MatrixEventClassifier.isSyncPayloadEvent] was
  /// false — state events, redactions, etc. (F4).
  final int filteredOutByType;

  /// Rejected because the Matrix event was still encrypted at enqueue
  /// time. The caller (usually `PendingDecryptionPen`) is expected to
  /// retain the event and re-submit once decryption completes (F3).
  final int deferredPendingDecryption;

  final int oldestTsAccepted;
  final int newestTsAccepted;

  static const empty = EnqueueResult(
    accepted: 0,
    duplicatesDropped: 0,
    filteredOutByType: 0,
    deferredPendingDecryption: 0,
    oldestTsAccepted: 0,
    newestTsAccepted: 0,
  );
}

/// Retry classification the worker hands back to the queue.
enum RetryReason { missingBase, retriable, decryptionPending }

/// A queue row materialised for the worker. [rawJson] is the bytes the
/// worker passes to `Event.fromJson(room, ...)` at apply time; the
/// queue itself does not keep SDK objects alive.
class InboundQueueEntry {
  const InboundQueueEntry({
    required this.queueId,
    required this.eventId,
    required this.roomId,
    required this.originTs,
    required this.producer,
    required this.attempts,
    required this.leaseUntil,
    required this.rawJson,
  });

  final int queueId;
  final String eventId;
  final String roomId;
  final int originTs;
  final InboundEventProducer producer;
  final int attempts;
  final int leaseUntil;
  final String rawJson;

  /// Materialises the stored event against the given [room]. The room
  /// must belong to the same client the event was enqueued from.
  Event toEvent(Room room) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return Event.fromJson(decoded, room);
  }
}

class QueueDepthSignal {
  const QueueDepthSignal({
    required this.total,
    required this.byProducer,
    required this.oldestEnqueuedAt,
  });

  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int? oldestEnqueuedAt;
}

class QueueStats {
  const QueueStats({
    required this.total,
    required this.byProducer,
    required this.readyNow,
    required this.oldestEnqueuedAt,
  });

  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int readyNow;
  final int? oldestEnqueuedAt;
}

const _logDomain = 'sync';
const _logSubEnqueue = 'queue.enqueue';
const _logSubCommit = 'queue.commit';
const _logSubRetry = 'queue.retry';
const _logSubSkip = 'queue.skip';
const _logSubPrune = 'queue.prune';

/// Durable inbound queue for Matrix sync events. See §3 of
/// `docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md`.
class InboundQueue {
  InboundQueue({
    required SyncDatabase db,
    required LoggingService logging,
    Duration? leaseDuration,
  }) : _db = db,
       _logging = logging,
       _leaseDuration = leaseDuration ?? SyncTuning.inboundWorkerLeaseDuration;

  final SyncDatabase _db;
  final LoggingService _logging;
  final Duration _leaseDuration;

  final StreamController<QueueDepthSignal> _depthCtl =
      StreamController<QueueDepthSignal>.broadcast();

  Stream<QueueDepthSignal> get depthChanges => _depthCtl.stream;

  Future<void> dispose() async {
    await _depthCtl.close();
  }

  // ---------------------------------------------------------------- enqueue

  Future<EnqueueResult> enqueueLive(Event event) =>
      enqueueBatch([event], producer: InboundEventProducer.live);

  Future<EnqueueResult> enqueueBatch(
    List<Event> events, {
    required InboundEventProducer producer,
  }) async {
    if (events.isEmpty) return EnqueueResult.empty;

    var accepted = 0;
    var duplicates = 0;
    var filteredOut = 0;
    var deferred = 0;
    var oldest = 0;
    var newest = 0;
    final nowMs = clock.now().millisecondsSinceEpoch;

    final toInsert = <InboundEventQueueCompanion>[];
    for (final event in events) {
      // F4: drop non-payload events at the boundary.
      if (!MatrixEventClassifier.isSyncPayloadEvent(event)) {
        filteredOut++;
        continue;
      }
      // F3: encrypted events must be held off-queue until decryption.
      if (event.type == EventTypes.Encrypted) {
        deferred++;
        continue;
      }

      final ts = event.originServerTs.millisecondsSinceEpoch;
      toInsert.add(
        InboundEventQueueCompanion.insert(
          eventId: event.eventId,
          roomId: event.roomId ?? '',
          originTs: ts,
          producer: producer.name,
          rawJson: jsonEncode(event.toJson()),
          enqueuedAt: nowMs,
        ),
      );
      if (oldest == 0 || ts < oldest) oldest = ts;
      if (ts > newest) newest = ts;
    }

    if (toInsert.isNotEmpty) {
      await _db.transaction(() async {
        for (final row in toInsert) {
          final inserted = await _db
              .into(_db.inboundEventQueue)
              .insertReturningOrNull(row, mode: InsertMode.insertOrIgnore);
          if (inserted == null) {
            duplicates++;
          } else {
            accepted++;
          }
        }
      });
    }

    _logging.captureEvent(
      'queue.enqueue producer=${producer.name} '
      'accepted=$accepted dupes=$duplicates '
      'filteredOutByType=$filteredOut '
      'deferredPendingDecryption=$deferred',
      domain: _logDomain,
      subDomain: _logSubEnqueue,
    );

    if (accepted > 0) {
      unawaited(_emitDepth());
    }

    return EnqueueResult(
      accepted: accepted,
      duplicatesDropped: duplicates,
      filteredOutByType: filteredOut,
      deferredPendingDecryption: deferred,
      oldestTsAccepted: oldest,
      newestTsAccepted: newest,
    );
  }

  /// Bootstrap producers write one page at a time through this entry
  /// point so the caller's back-pressure loop can await
  /// [waitForDrainAtMostTo] between pages.
  Future<EnqueueResult> appendBootstrapPage(List<Event> events) =>
      enqueueBatch(events, producer: InboundEventProducer.bootstrap);

  /// Completes when the queue depth drops to [depth] or below. Checked
  /// against the live [depthChanges] stream; completes immediately if
  /// the current depth already satisfies the condition.
  Future<void> waitForDrainAtMostTo(int depth, {Duration? timeout}) async {
    final current = await _countTotal();
    if (current <= depth) return;
    final completer = Completer<void>();
    late final StreamSubscription<QueueDepthSignal> sub;
    sub = depthChanges.listen((signal) {
      if (signal.total <= depth && !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      if (timeout != null) {
        await completer.future.timeout(timeout);
      } else {
        await completer.future;
      }
    } finally {
      await sub.cancel();
    }
  }

  // ------------------------------------------------------------------ peek

  /// Returns up to [maxBatch] entries ready now (origin_ts ascending,
  /// queue_id ascending on tie), stamping a durable lease so concurrent
  /// drainers cannot double-apply.
  Future<List<InboundQueueEntry>> peekBatchReady({
    int maxBatch = SyncTuning.inboundWorkerBatchSize,
  }) async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final leaseUntilMs = nowMs + _leaseDuration.inMilliseconds;

    return _db.transaction(() async {
      final query = _db.select(_db.inboundEventQueue)
        ..where(
          (t) =>
              t.nextDueAt.isSmallerOrEqualValue(nowMs) &
              t.leaseUntil.isSmallerOrEqualValue(nowMs),
        )
        ..orderBy([
          (t) => OrderingTerm.asc(t.originTs),
          (t) => OrderingTerm.asc(t.queueId),
        ])
        ..limit(maxBatch);
      final rows = await query.get();
      if (rows.isEmpty) return const <InboundQueueEntry>[];
      final ids = rows.map((r) => r.queueId).toList();
      await (_db.update(_db.inboundEventQueue)
            ..where((t) => t.queueId.isIn(ids)))
          .write(InboundEventQueueCompanion(leaseUntil: Value(leaseUntilMs)));
      return [for (final r in rows) _entryFromRow(r, leaseUntilMs)];
    });
  }

  InboundQueueEntry _entryFromRow(
    InboundEventQueueItem row,
    int leaseUntil,
  ) => InboundQueueEntry(
    queueId: row.queueId,
    eventId: row.eventId,
    roomId: row.roomId,
    originTs: row.originTs,
    producer: _producerFromName(row.producer),
    attempts: row.attempts,
    leaseUntil: leaseUntil,
    rawJson: row.rawJson,
  );

  InboundEventProducer _producerFromName(String name) {
    for (final p in InboundEventProducer.values) {
      if (p.name == name) return p;
    }
    return InboundEventProducer.live;
  }

  // ---------------------------------------------------------------- commit

  /// Atomically deletes [entry] from the queue and, if the entry's
  /// timestamp advances the stored marker under
  /// [TimelineEventOrdering.isNewer], updates `queue_markers` for the
  /// room. Both operations land in one `sync_db` transaction so a
  /// crash between them cannot leave the marker pointing past a row
  /// still in the queue (F2 + F5).
  Future<void> commitApplied(InboundQueueEntry entry) async {
    var markerAdvanced = false;
    await _db.transaction(() async {
      final marker = await (_db.select(
        _db.queueMarkers,
      )..where((t) => t.roomId.equals(entry.roomId))).getSingleOrNull();

      final shouldAdvance = TimelineEventOrdering.isNewer(
        candidateTimestamp: entry.originTs,
        candidateEventId: entry.eventId,
        latestTimestamp: marker?.lastAppliedTs == 0
            ? null
            : marker?.lastAppliedTs,
        latestEventId: marker?.lastAppliedEventId,
      );

      await (_db.delete(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.equals(entry.queueId))).go();

      if (shouldAdvance) {
        markerAdvanced = true;
        final isDurable = entry.eventId.startsWith(r'$');
        final nextSeq = (marker?.lastAppliedCommitSeq ?? 0) + 1;
        await _db
            .into(_db.queueMarkers)
            .insertOnConflictUpdate(
              QueueMarkersCompanion.insert(
                roomId: entry.roomId,
                lastAppliedEventId: Value(
                  isDurable ? entry.eventId : marker?.lastAppliedEventId,
                ),
                lastAppliedTs: Value(entry.originTs),
                lastAppliedCommitSeq: Value(nextSeq),
              ),
            );
      }
    });

    _logging.captureEvent(
      'queue.commit eventId=${entry.eventId} '
      'originTs=${entry.originTs} '
      'markerAdvanced=$markerAdvanced',
      domain: _logDomain,
      subDomain: _logSubCommit,
    );
    unawaited(_emitDepth());
  }

  // ----------------------------------------------------------------- retry

  Future<void> scheduleRetry(
    InboundQueueEntry entry,
    Duration backoff, {
    required RetryReason reason,
  }) async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final nextDueAt = nowMs + backoff.inMilliseconds;
    await (_db.update(
      _db.inboundEventQueue,
    )..where((t) => t.queueId.equals(entry.queueId))).write(
      InboundEventQueueCompanion(
        attempts: Value(entry.attempts + 1),
        nextDueAt: Value(nextDueAt),
        // Drop the lease so another drain iteration can pick up the
        // entry once the backoff elapses.
        leaseUntil: const Value(0),
      ),
    );
    _logging.captureEvent(
      'queue.retry eventId=${entry.eventId} '
      'reason=${reason.name} '
      'attempts=${entry.attempts + 1} '
      'nextDueAtMs=$nextDueAt',
      domain: _logDomain,
      subDomain: _logSubRetry,
    );
  }

  /// Permanently drops an entry the worker classifies as unrecoverable.
  Future<void> markSkipped(
    InboundQueueEntry entry, {
    String? reason,
  }) async {
    await (_db.delete(
      _db.inboundEventQueue,
    )..where((t) => t.queueId.equals(entry.queueId))).go();
    _logging.captureEvent(
      'queue.skip eventId=${entry.eventId} reason=${reason ?? 'unspecified'}',
      domain: _logDomain,
      subDomain: _logSubSkip,
    );
    unawaited(_emitDepth());
  }

  // ---------------------------------------------------------------- prune

  /// Deletes every entry whose `roomId` does not match [currentRoomId].
  /// Call on session bootstrap and whenever the active sync room
  /// changes. Returns the number of rows removed (F6).
  Future<int> pruneStrandedEntries(String currentRoomId) async {
    final deleted = await (_db.delete(
      _db.inboundEventQueue,
    )..where((t) => t.roomId.equals(currentRoomId).not())).go();
    if (deleted > 0) {
      _logging.captureEvent(
        'queue.prune currentRoom=$currentRoomId deleted=$deleted',
        domain: _logDomain,
        subDomain: _logSubPrune,
      );
      unawaited(_emitDepth());
    }
    return deleted;
  }

  // ---------------------------------------------------------------- stats

  Future<QueueStats> stats() async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final rows = await _db.select(_db.inboundEventQueue).get();
    final byProducer = <InboundEventProducer, int>{};
    var readyNow = 0;
    int? oldest;
    for (final row in rows) {
      final p = _producerFromName(row.producer);
      byProducer.update(p, (v) => v + 1, ifAbsent: () => 1);
      if (row.nextDueAt <= nowMs && row.leaseUntil <= nowMs) {
        readyNow++;
      }
      if (oldest == null || row.enqueuedAt < oldest) {
        oldest = row.enqueuedAt;
      }
    }
    return QueueStats(
      total: rows.length,
      byProducer: byProducer,
      readyNow: readyNow,
      oldestEnqueuedAt: oldest,
    );
  }

  Future<int> _countTotal() async {
    final count = _db.inboundEventQueue.queueId.count();
    final row = await (_db.selectOnly(
      _db.inboundEventQueue,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _emitDepth() async {
    if (_depthCtl.isClosed) return;
    final snapshot = await stats();
    // Re-check after the async gap — dispose() may have closed the
    // controller while we were computing stats (common in test
    // teardown, where the assertion completes before the fire-and-
    // forget `_emitDepth` that was kicked off from enqueue/commit).
    if (_depthCtl.isClosed) return;
    _depthCtl.add(
      QueueDepthSignal(
        total: snapshot.total,
        byProducer: snapshot.byProducer,
        oldestEnqueuedAt: snapshot.oldestEnqueuedAt,
      ),
    );
  }
}
