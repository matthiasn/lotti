import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

const _logSubResurrect = 'queue.resurrect';

/// Resurrection layer of `InboundQueue`: re-arming skipped entries by
/// path, reason, or wholesale. The queue keeps thin delegators so
/// `MockInboundQueue` keeps intercepting the public API.
class InboundQueueResurrection {
  InboundQueueResurrection({
    required this._db,
    required this._logging,
    required this._onDepthChanged,
  });

  final SyncDatabase _db;
  final DomainLogger _logging;

  /// Invoked after any pass that actually resurrected rows so the
  /// owning queue can emit a fresh depth signal.
  final void Function() _onDepthChanged;

  /// Maximum number of paths bound per `json_path IN (...)` chunk in
  /// [resurrectByPaths]. SQLite's default `SQLITE_MAX_VARIABLE_NUMBER`
  /// is 999; chunking at 900 leaves headroom for the implicit
  /// `resurrection_count` parameter and any future additions to
  /// [_resurrectWhere] without bumping into the cap.
  static const int _resurrectByPathsChunkSize = 900;

  /// Flips abandoned rows whose `json_path` matches [path] back to
  /// `enqueued` so the worker re-attempts them. Intended for the
  /// `AttachmentIndex.pathRecorded` signal — when an attachment JSON
  /// finally lands on disk, the sibling event whose apply failed
  /// with a descriptor-missing error is automatically un-parked.
  ///
  /// [hardCap] caps per-row resurrections so a truly poison event
  /// cannot thrash the worker forever. Rows with
  /// `resurrection_count >= hardCap` are skipped; the user can still
  /// discard them manually from the Skipped-events page.
  ///
  /// Returns the number of rows resurrected.
  Future<int> resurrectByPath(
    String path, {
    int hardCap = 50,
  }) async {
    return _resurrectWhere(
      (t) => t.jsonPath.equals(path),
      hardCap: hardCap,
      diagnostic: 'path=$path',
    );
  }

  /// Bulk variant of [resurrectByPath] — flips abandoned rows whose
  /// `json_path` is in [paths] back to `enqueued`. Issues one
  /// SELECT + transactional UPDATE round-trip per
  /// [_resurrectByPathsChunkSize] batch.
  ///
  /// Backs the coordinator's debounced `pathRecorded` subscriber: a
  /// burst of attachment downloads (matrix-sync catch-up) used to fan
  /// out N independent per-path SELECT/UPDATE pairs, each queuing
  /// behind the previous transaction's writer lock. The 2026-05-12
  /// desktop super_slow log captured this as 222 hits/day of
  /// `inbound_event_queue WHERE status='abandoned' AND
  /// resurrection_count<? AND json_path=?` at ~384 ms each, ten or
  /// more landing in the same millisecond span. Collapsing the burst
  /// into one `WHERE json_path IN (...)` query removes the wait
  /// chain entirely.
  ///
  /// Chunking guards against SQLite's host-variable limit (default
  /// 999) so a very large catch-up batch — e.g. an initial sync that
  /// downloads thousands of attachments while abandoned ledger rows
  /// were waiting — cannot trip the cap. Each chunk still resurrects
  /// in one DB round-trip; the cumulative wall cost grows linearly
  /// with chunk count, never exponentially.
  ///
  /// Empty input returns 0 without touching the database. Duplicate
  /// paths are deduplicated to keep each IN-list short.
  Future<int> resurrectByPaths(
    Iterable<String> paths, {
    int hardCap = 50,
  }) async {
    final uniquePaths = paths.toSet();
    if (uniquePaths.isEmpty) return 0;

    final pathList = uniquePaths.toList(growable: false);
    var totalResurrected = 0;
    for (
      var start = 0;
      start < pathList.length;
      start += _resurrectByPathsChunkSize
    ) {
      final end = start + _resurrectByPathsChunkSize > pathList.length
          ? pathList.length
          : start + _resurrectByPathsChunkSize;
      final chunk = pathList.sublist(start, end);
      totalResurrected += await _resurrectWhere(
        (t) => t.jsonPath.isIn(chunk),
        hardCap: hardCap,
        diagnostic: 'paths=${chunk.length}',
      );
    }
    return totalResurrected;
  }

  /// Resurrects every abandoned row for the current (and any other)
  /// room that is still below [hardCap]. Used by the Skipped-events
  /// page's "Retry all" action.
  Future<int> resurrectAll({int hardCap = 50}) async {
    return _resurrectWhere(
      null,
      hardCap: hardCap,
      diagnostic: 'scope=all',
    );
  }

  /// Flips abandoned rows whose most recent retry reason matches
  /// [reasonName] back to `enqueued`. Used by the coordinator's
  /// `UpdateNotifications.updateStream` subscriber: every
  /// journal-db update fans out a targeted-enough resurrection for
  /// `missingBase` rows without building a per-entity tracker.
  ///
  /// Broader-than-ideal: any journal update triggers a resurrection
  /// pass across all rooms' missingBase rows. The [hardCap] still
  /// prevents thrash on a genuinely poisoned event; a finer-grained
  /// mapping (e.g. blocking-entry-id column) can ship in a follow-up
  /// if the broad pass proves too chatty.
  Future<int> resurrectByReason(
    String reasonName, {
    int hardCap = 50,
  }) async {
    return _resurrectWhere(
      (t) => t.lastErrorReason.equals(reasonName),
      hardCap: hardCap,
      diagnostic: 'reason=$reasonName',
    );
  }

  Future<int> _resurrectWhere(
    Expression<bool> Function(InboundEventQueue t)? extraWhere, {
    required int hardCap,
    required String diagnostic,
  }) async {
    final table = _db.inboundEventQueue;
    final nowMs = clock.now().millisecondsSinceEpoch;

    // Collect the target rows first so the bump of `resurrection_count`
    // and the log line reflect the rows that actually changed.
    //
    // `status = 'abandoned'` is inlined as a literal SQL fragment via
    // `CustomExpression` so the SQLite planner can prove this query's
    // WHERE implies the partial indices'
    // (`idx_inbound_event_queue_abandoned_path`,
    // `idx_inbound_event_queue_abandoned_reason`,
    // `idx_inbound_event_queue_abandoned_reason_resurrection`),
    // each declared with the literal `WHERE status = 'abandoned'`.
    // Drift's `t.status.equals(...)` binds the value as a
    // parameter; the planner can't see it at plan time, the
    // partial-index match fails, and resurrectByReason / resurrectByPath
    // fall back to scanning the full append-only ledger. The
    // 2026-05-09 desktop slow_queries log captured this shape at
    // 107 hits/day in the 200–877 ms band even with the v17 partial
    // index in place.
    final selectQuery = _db.select(table)
      ..where(
        (t) =>
            const CustomExpression<bool>("status = 'abandoned'") &
            t.resurrectionCount.isSmallerThanValue(hardCap),
      );
    if (extraWhere != null) {
      selectQuery.where(extraWhere);
    }
    final rows = await selectQuery.get();
    if (rows.isEmpty) {
      return 0;
    }

    final ids = rows.map((r) => r.queueId).toList();
    final updated = await _db.transaction(() async {
      // A single UPDATE flips every eligible row; looping per-row
      // would pay the round-trip cost N times.
      // Reset `enqueued_at` so any pendingAttachment retries triggered
      // by the resurrected row get a fresh wall-clock deadline. Without
      // this, a row abandoned by `pendingAttachmentTimeout` would be
      // re-abandoned on its next worker pass because the elapsed
      // calculation in `InboundWorker._maybeRetry` is anchored to the
      // original enqueue time.
      final custom = await _db.customUpdate(
        'UPDATE inbound_event_queue '
        'SET status = ?, '
        '    resurrection_count = resurrection_count + 1, '
        '    attempts = 0, '
        '    next_due_at = 0, '
        '    lease_until = 0, '
        '    enqueued_at = ?, '
        '    last_error_reason = NULL, '
        '    abandoned_at = NULL '
        'WHERE queue_id IN (${List.filled(ids.length, '?').join(', ')})',
        variables: [
          Variable.withString(InboundQueueStatuses.enqueued),
          Variable.withInt(nowMs),
          ...ids.map(Variable.withInt),
        ],
        updates: {table},
      );
      return custom;
    });

    _logging.log(
      LogDomain.sync,
      'queue.resurrect $diagnostic '
      'count=$updated hardCap=$hardCap '
      'nowMs=$nowMs',
      subDomain: _logSubResurrect,
    );
    if (updated > 0) {
      _onDepthChanged();
    }
    return updated;
  }
}

/// Best-effort helper to extract `jsonPath` from the Lotti sync
/// message content. Returns null when the event is not a sync
/// payload or the content shape does not match (defensive against
/// SDK event shape drift). A null result means the row cannot be
/// resurrected by path — manual "Retry all" still works.
String? extractJsonPath(Event event) {
  try {
    final content = event.content;
    final raw = content['jsonPath'] ?? content['json_path'];
    if (raw is String && raw.isNotEmpty) {
      return raw.startsWith('/') ? raw : '/$raw';
    }
  } catch (_) {
    // Intentionally empty: diagnostic-only; adapter will still
    // record the path on apply failure if we miss it here.
  }
  return null;
}
