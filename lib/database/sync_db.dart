import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';

part 'sync_db.g.dart';
part 'sync_db_backfill.dart';
part 'sync_db_lifecycle.dart';
part 'sync_db_outbox.dart';
part 'sync_db_outbox_dedup.dart';
part 'sync_db_outbox_prune.dart';
part 'sync_db_sequence.dart';
part 'sync_db_tables.dart';
part 'sync_db_watermarks.dart';
part 'sync_sequence_status.dart';

const syncDbFileName = 'sync.sqlite';

const _dropIdxOutboxSendingExpiry =
    'DROP INDEX IF EXISTS idx_outbox_sending_expiry';

const _createSyncSequenceWatermarks = '''
CREATE TABLE IF NOT EXISTS sync_sequence_watermarks (
  host_id TEXT PRIMARY KEY NOT NULL,
  last_counter INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
)
''';

const _idxInboundEventQueueActiveStatusRoom =
    'CREATE INDEX IF NOT EXISTS idx_inbound_event_queue_active_status_room '
    'ON inbound_event_queue (status, room_id) '
    "WHERE status IN ('enqueued', 'leased', 'retrying')";

@DriftDatabase(
  tables: [
    Outbox,
    SyncSequenceLog,
    HostActivity,
    InboundEventQueue,
    QueueMarkers,
  ],
)
class SyncDatabase extends _$SyncDatabase
    with
        _SyncDbOutbox,
        _SyncDbOutboxPrune,
        _SyncDbOutboxDedup,
        _SyncDbSequenceWatermarks,
        _SyncDbSequenceLog,
        _SyncDbBackfill,
        _SyncDbSequenceLifecycle {
  SyncDatabase({
    this.inMemoryDatabase = false,
    String? overriddenFilename,
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           overriddenFilename ?? syncDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  SyncDatabase.connect(super.c) : super.connect();

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await customStatement(_dropIdxOutboxSendingExpiry);
        await customStatement(_createSyncSequenceWatermarks);
        await customStatement(_idxInboundEventQueueActiveStatusRoom);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Creates tables with all current columns (including payload_type)
          await m.createTable(syncSequenceLog);
          await m.createTable(hostActivity);
        } else if (from < 3) {
          // Only add payload_type if table existed from v2 (without this column)
          await m.addColumn(syncSequenceLog, syncSequenceLog.payloadType);
        }
        if (from < 4) {
          // Add outboxEntryId column for outbox deduplication
          await m.addColumn(outbox, outbox.outboxEntryId);
        }
        if (from < 5) {
          // Add payloadSize column for volume tracking
          await m.addColumn(outbox, outbox.payloadSize);
        }
        if (from < 6) {
          // Add priority column for outbox priority queue
          await m.addColumn(outbox, outbox.priority);
        }
        if (from >= 2 && from < 7) {
          // Add jsonPath column for zombie file sweep on re-request.
          // Guard with from >= 2 because createTable (from < 2) already
          // includes jsonPath in the current schema definition.
          await m.addColumn(syncSequenceLog, syncSequenceLog.jsonPath);

          // Backfill jsonPath for existing agent entity/link entries whose
          // paths are derivable from entry_id. This ensures the zombie-file
          // sweep works for items stuck in 'requested' state before this
          // migration.
          await customStatement(
            'UPDATE sync_sequence_log '
            'SET json_path = CASE '
            "  WHEN payload_type = ${SyncSequencePayloadType.agentEntity.index} THEN '/agent_entities/' || entry_id || '.json' "
            "  WHEN payload_type = ${SyncSequencePayloadType.agentLink.index} THEN '/agent_links/' || entry_id || '.json' "
            'END '
            'WHERE entry_id IS NOT NULL AND payload_type IN ('
            '  ${SyncSequencePayloadType.agentEntity.index}, '
            '  ${SyncSequencePayloadType.agentLink.index}'
            ')',
          );
        }
        if (from < 8) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_created_at '
            'ON sync_sequence_log (status, created_at) '
            'WHERE status IN (1, 2)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_payload_resolution '
            'ON sync_sequence_log (entry_id, payload_type, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 9) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_status_priority_created_at '
            'ON outbox (status, priority, created_at)',
          );
        }
        if (from < 10) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_entry_status '
            'ON sync_sequence_log (host_id, entry_id, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 11) {
          // Replace the v10 prefix index with a covering one that includes
          // `counter` (and orders it descending ahead of `status`). Without
          // this, `getLastSentCounterForEntry` pulled every matching row
          // from the heap to compute MAX(counter), blocking the UI isolate
          // for 40–600 ms per outbox enqueue on hot entry_ids. The column
          // order lets `ORDER BY counter DESC LIMIT 1` terminate early in
          // the index itself instead of building a temp B-tree to merge
          // the two `status IN (?, ?)` partitions.
          await customStatement(
            'DROP INDEX IF EXISTS idx_sync_sequence_log_host_entry_status',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_entry_status_counter '
            'ON sync_sequence_log (host_id, entry_id, counter DESC, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 12) {
          // Phase 1 of the InboundEventQueue refactor — adds a durable
          // queue plus a per-room marker table so commitApplied can
          // delete the queue row and advance the marker atomically.
          // See docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md.
          await m.createTable(inboundEventQueue);
          await m.createTable(queueMarkers);
          // Back-compat: when the queue is first enabled, Phase 2's
          // wiring reads the legacy markers from settings_db and seeds
          // `queue_markers` at that time. The migration itself leaves
          // the table empty so upgrading users without the flag on see
          // no behaviour change.
        }
        if (from >= 12 && from < 13) {
          // Phase-3 ledger refactor: rows are no longer deleted on
          // commit/skip. A `status` column carries the lifecycle,
          // `commitApplied` → 'applied' (kept for traceability),
          // `markSkipped` → 'abandoned' (resurrectable). The marker
          // clamp scans only active statuses so an abandoned poison
          // row cannot stall forward progress.
          //
          // Columns are additive with defaults, so any v12 rows in
          // flight at upgrade time are treated as `enqueued` and the
          // worker resumes their drain. Indexes are replaced with
          // partials that cover the new status-filtered access paths.
          //
          // Guarded on `from >= 12` because upgrades that cross v12
          // (e.g. v1 → v13) hit the `from < 12` branch above, which
          // calls `m.createTable(inboundEventQueue)`. That helper
          // uses the CURRENT (v13) schema, so the `status` column
          // et al. are already present; re-running the ALTERs here
          // would `duplicate column` out. Upgrades landing precisely
          // on v12 → v13 still need this step because the v12
          // createTable only ran in a previous migration invocation
          // against the older table definition.
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            '''ADD COLUMN status TEXT NOT NULL DEFAULT 'enqueued' ''',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN committed_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN abandoned_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN last_error_reason TEXT',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN resurrection_count INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN json_path TEXT',
          );
          // Replace the drain index with a partial one so the applied
          // ledger (unbounded over time) never touches the peek path.
          await customStatement(
            'DROP INDEX IF EXISTS idx_inbound_event_queue_ready',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_inbound_event_queue_ready '
            'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
            '''WHERE status IN ('enqueued', 'retrying')''',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_active_room_ts '
            'ON inbound_event_queue (room_id, origin_ts) '
            '''WHERE status IN ('enqueued', 'leased', 'retrying')''',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_path '
            'ON inbound_event_queue (json_path) '
            '''WHERE status = 'abandoned' ''',
          );
        }
        if (from < 14) {
          // `earliestReadyAt` full-scanned `inbound_event_queue` on
          // every worker idle tick — 3500 scans per hour, 73 seconds
          // of DB time, p95=46 ms and max=2.3 s on a real desktop
          // mid-drain. This partial index turns the MIN(CASE …)
          // probe into an active-rows-only scan.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_active_ready_at '
            'ON inbound_event_queue (next_due_at, lease_until) '
            '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
          );
        }
        if (from < 15) {
          // 1. `resurrectByReason` was the #2 desktop slow query
          //    (298 s total, 5.9 s max). It filters
          //    `status='abandoned' AND last_error_reason=?` but no
          //    matching index existed, so it scanned 23 k+ rows of
          //    the applied ledger on every fire. Mirrors the existing
          //    `idx_inbound_event_queue_abandoned_path` shape.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_reason '
            'ON inbound_event_queue (last_error_reason) '
            '''WHERE status = 'abandoned' ''',
          );
          // 2. `retireAgedOutRequestedEntries` filters on `updated_at`
          //    but the existing actionable partial index is keyed on
          //    `created_at`, so the WHERE picked the autoindex on
          //    (host_id, counter) and effectively scanned every row
          //    that ever held status IN (1,2). Add a partial keyed on
          //    the column the WHERE actually needs.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_updated_at '
            'ON sync_sequence_log (status, updated_at) '
            'WHERE status IN (1, 2)',
          );
          // 3. `getBackfillStats`' `SUM(CASE WHEN status=…)` GROUP BY
          //    host_id was a full table scan of 700 k+ rows
          //    (858 s total on desktop). With this covering index the
          //    plan becomes an index-only scan, GROUP BY (host_id,
          //    status) collapses to ~80 rows total, and the per-host
          //    aggregation in Dart is trivially fast.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_status '
            'ON sync_sequence_log (host_id, status)',
          );
          // 4. `oldestOutboxItems` and `claimNextOutboxItem` both
          //    scan via `idx_outbox_status_priority_created_at`, but
          //    with 32 k+ `sent` rows accumulated on desktop the
          //    index pages are dominated by terminal rows. A partial
          //    index limited to actionable statuses keeps the hot
          //    `sendNext` lookup focused on the ~6 rows that matter.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_actionable_priority_created_at '
            'ON outbox (priority, created_at) '
            'WHERE status IN '
            // pending=0, sending=3 — values must match OutboxStatus.
            '(${OutboxStatus.pending.index}, $_outboxSendingStatus)',
          );
        }
        if (from < 16) {
          // 1. `peekBatchReady` filters
          //    `status IN ('enqueued','retrying','leased')` so the
          //    crash-recovered peek can re-claim rows whose lease
          //    expired. The drain partial originally limited the
          //    WHERE to `('enqueued','retrying')`, so SQLite could
          //    not use it for ORDER BY origin_ts, queue_id and fell
          //    back to `idx_inbound_event_queue_active_ready_at`
          //    (keyed on (next_due_at, lease_until)) plus an
          //    external sort. Rebuild the partial with the matching
          //    status set so the worker's hot drain query becomes
          //    index-only on the sort columns.
          await customStatement(
            'DROP INDEX IF EXISTS idx_inbound_event_queue_ready',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_inbound_event_queue_ready '
            'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
            '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
          );
          // 2. `retireExhaustedRequestedEntries` filters on
          //    `(status IN (1,2)) AND request_count >= ? AND
          //    last_requested_at IS NOT NULL AND last_requested_at < ?`.
          //    Neither existing actionable partial (created_at /
          //    updated_at) covers `last_requested_at`, so the planner
          //    fell back to the autoindex on (host_id, counter) and
          //    effectively scanned every actionable row. The new
          //    partial is keyed on the bound column so the predicate
          //    becomes a tight range scan.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_last_requested_at '
            'ON sync_sequence_log (status, last_requested_at) '
            'WHERE status IN (1, 2) AND last_requested_at IS NOT NULL',
          );
        }
        if (from < 17) {
          // 1. Outbox merge dedup (`findPendingByEntryId`) was the #3
          //    iOS slow query (2,394 occurrences, p50=197 ms): scanning
          //    every pending row to find the entry_id match. Partial
          //    on (outbox_entry_id, created_at) keyed only on pending
          //    rows turns it into a tight index seek + DESC walk that
          //    terminates on the first row.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_pending_entry_id_created_at '
            'ON outbox (outbox_entry_id, created_at) '
            'WHERE status = ${OutboxStatus.pending.index} '
            'AND outbox_entry_id IS NOT NULL',
          );
          // 2. `resurrectByReason` was #2 with p50=101 ms / 6,331
          //    occurrences. The v15 partial index covers
          //    `(last_error_reason)` only; the actual predicate also
          //    constrains `resurrection_count < ?`, forcing per-row
          //    heap fetches to evaluate the count comparison. Stacking
          //    `resurrection_count` behind the reason equality keeps
          //    the walk inside the index.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_reason_resurrection '
            'ON inbound_event_queue (last_error_reason, resurrection_count) '
            '''WHERE status = 'abandoned' ''',
          );
        }
        if (from < 18) {
          // Backstop the `QueueStats.stats()` and `readyNow` probes.
          // Their `status IN (?, ?, ?)` predicate could not be matched
          // to the existing partial index, so the planner full-scanned
          // the queue ledger (332 ms in the super-slow log). Non-partial
          // composite leading on `status` makes the predicate seekable.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_due_lease '
            'ON inbound_event_queue (status, next_due_at, lease_until)',
          );
          // Refresh stats for the new partition shape so the planner
          // picks the new index immediately on first launch instead of
          // waiting for the next ANALYZE cycle.
          await customStatement('ANALYZE');
        }
        if (from < 19) {
          // The v18 index seeked on status but couldn't satisfy
          // `MIN(enqueued_at)` without falling back to the heap, so the
          // stats query still showed up as a SCAN in the super-slow log
          // (240–550 ms per poll). Pairing `(status, enqueued_at)`
          // turns MIN into an O(1) seek per matched status partition.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_enqueued '
            'ON inbound_event_queue (status, enqueued_at)',
          );
          await customStatement('ANALYZE');
        }
        if (from < 20) {
          // `QueueStats.stats()` was rewritten as a single
          // `GROUP BY status, producer` aggregate. The v19 index keys
          // on `(status, enqueued_at)` but does not include
          // `producer`, so the planner had to read every matching row
          // from the heap to bucket by producer — 1014–2244 ms SCAN
          // hits on the 2026-05-10 super-slow log. Stacking
          // `(status, producer, enqueued_at)` makes the pivot
          // index-only over a tight key range and removes the TEMP
          // B-TREE for GROUP BY.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_producer_enqueued '
            'ON inbound_event_queue (status, producer, enqueued_at)',
          );
          await customStatement('ANALYZE');
        }
        if (from < 21) {
          // `oldestOutboxItems` / `claimNextOutboxBatch` used to fire
          //   `WHERE status = 0 ORDER BY created_at ASC, id ASC LIMIT N`
          // and the expired-sending companion used to fire
          //   `WHERE status = 3 AND updated_at < cutoff ORDER BY
          //   created_at ASC, id ASC LIMIT N`.
          // The general `(status, priority, created_at)` index sorts
          // within status by (priority, created_at) — not what the
          // ORDER BY needs — so the planner reverted to a temp
          // B-tree sort. The 2026-05-12 desktop super-slow log
          // captured 56 hits/day for the pending LIMIT 1 shape and 16
          // hits/day for the LIMIT 50 + updated_at companion, with
          // tails reaching 6.0 s. Two literal-status partial indices
          // sized to the actionable rows let the planner walk in
          // (created_at, id) order and stop at LIMIT — no temp
          // B-tree for the pending path, no scanning of `sent`
          // tombstones. The v22 migration below retunes the
          // expired-sending index column order after red-team plan
          // review found that leading on `updated_at` still forced a
          // temp sort for `ORDER BY created_at, id`.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_pending_created_id '
            'ON outbox (created_at, id) '
            'WHERE status = 0',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_sending_expiry '
            'ON outbox (updated_at, created_at, id) '
            'WHERE status = 3',
          );
          await customStatement('ANALYZE');
        }
        if (from < 22) {
          // Drop v21's updated_at-leading expired-sending index. It is good
          // for the lease-expiry range predicate but cannot satisfy the
          // priority-first dequeue order, so SQLite picked it and paid a temp
          // sort on the hot reclaim path. The existing
          // `idx_outbox_status_priority_created_at` index matches the current
          // `status = 3 ORDER BY priority, created_at, id` shape.
          await customStatement(_dropIdxOutboxSendingExpiry);
          await customStatement('ANALYZE');
        }
        if (from < 23) {
          // `getLastCounterForHost` only needs terminal/resolved statuses
          // (`received`, `backfilled`, `deleted`, `unresolvable`) for one host
          // in counter order while lazily warming the persisted watermark.
          // Keep the status literals aligned with [SyncSequenceStatus] via the
          // guard test.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_resolved_host_counter '
            'ON sync_sequence_log (host_id, counter) '
            'WHERE status IN (0, 3, 4, 5)',
          );
          // Persist the contiguous per-host sequence watermark outside the
          // append-only sequence log. The table is intentionally not eagerly
          // backfilled during migration: existing hosts warm lazily on first
          // query so launch does not pay the historic ROW_NUMBER CTE for every
          // host at once.
          await customStatement(_createSyncSequenceWatermarks);
          // `pruneStrandedEntries` updates every active row outside the
          // current Matrix room. A partial `(status, room_id)` index keeps
          // that maintenance pass off the applied/abandoned ledger.
          final inboundQueueExists = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'inbound_event_queue'",
          ).getSingleOrNull();
          if (inboundQueueExists != null) {
            await customStatement(_idxInboundEventQueueActiveStatusRoom);
          }
          await customStatement('ANALYZE');
        }
        if (from < 24) {
          // burned(8) is a new terminal/resolved status (split out of
          // unresolvable). Rebuild the resolved partial index so the watermark
          // CTE can use it for burned rows, which become the largest resolved
          // bucket. Drop + recreate because the partial WHERE changed
          // (IN (0, 3, 4, 5) -> IN (0, 3, 4, 5, 8)); keep it aligned with
          // [SyncSequenceStatusX.isResolved].
          await customStatement(
            'DROP INDEX IF EXISTS idx_sync_sequence_log_resolved_host_counter',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_resolved_host_counter '
            'ON sync_sequence_log (host_id, counter) '
            'WHERE status IN (0, 3, 4, 5, 8)',
          );
          await customStatement('ANALYZE');
        }
      },
    );
  }
}
