part of 'database.dart';

/// Most-recent schema-upgrade steps (v41+) for [JournalDb], split from
/// [_JournalDbMigration] for file size and invoked from its onUpgrade.
mixin _JournalDbMigrationRecent on _$JournalDb {
  Future<bool> _tableExists(String tableName);
  Future<bool> _columnExists(String table, String column);

  Future<void> _onUpgradeRecent(Migrator m, int from) async {
    // v41: Replace the `json_extract(serialized,'$.data.due')`
    // expression-keyed `idx_journal_tasks_due_open` with a partial
    // index over a real `due_at` column. The denormalized column
    // lets the planner stream `ORDER BY due_at ASC` directly from
    // the index without touching `serialized`, eliminates per-row
    // JSON parsing on the DailyOS hot path, and removes the
    // planner-fragility that required the `INDEXED BY` pin plus a
    // JSON-fallback safety net.
    //
    // The non-partial composite `idx_journal_tasks_due_active` is
    // dropped because its only consumer (`getTasksSortedByDueDate`)
    // is rewritten in this release to read `due_at` and let the
    // planner choose its own access path.
    if (from < 41) {
      await () async {
        if (!await _tableExists('journal')) return;
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Adding due_at column, backfilling from JSON, '
              'recreating tasks-due partial index',
        );

        // 1. Add the nullable column. Idempotent via column-existence
        //    check (mirrors the project_id / task_priority_rank
        //    migration shape).
        if (!await _columnExists('journal', 'due_at')) {
          await customStatement(
            'ALTER TABLE journal ADD COLUMN due_at DATETIME',
          );
        }

        // 2. Backfill from JSON for every task with a non-null
        //    `data.due`, regardless of status. `getTasksSortedByDueDate`
        //    reads across all statuses and range queries like "tasks
        //    due yesterday" must light up completed/rejected tasks too,
        //    so leaving closed tasks NULL would silently drop them
        //    from range scans and corrupt sort order.
        //
        //    Encoding: `strftime('%s', ...)` returns Unix seconds as
        //    TEXT; `CAST(... AS INTEGER)` matches Drift's default
        //    DateTime mapping (`millisecondsSinceEpoch ~/ 1000`). Do
        //    NOT use `datetime(...)` — that returns canonical TEXT
        //    and would corrupt the integer column.
        await customStatement(
          'UPDATE journal '
          "SET due_at = CAST(strftime('%s', "
          r"  json_extract(serialized, '$.data.due')) AS INTEGER) "
          "WHERE type = 'Task' AND task = 1 AND deleted = FALSE "
          r"  AND json_extract(serialized, '$.data.due') IS NOT NULL",
        );

        // 3. Drop the old expression-keyed partial and re-create on
        //    the column. `_createIdxJournalTasksDueOpenSql` is the
        //    canonical column-keyed form shared with `beforeOpen`.
        await customStatement(
          'DROP INDEX IF EXISTS idx_journal_tasks_due_open',
        );
        await customStatement(_createIdxJournalTasksDueOpenSql);

        // 4. Drop the unused non-partial composite. Its only
        //    consumer was `getTasksSortedByDueDate` via INDEXED BY,
        //    rewritten this release to use `due_at` and let the
        //    planner choose its own access path.
        await customStatement(
          'DROP INDEX IF EXISTS idx_journal_tasks_due_active',
        );
      }();
    }

    if (from < 42) {
      await () async {
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Adding task-status/priority/date partial index and '
              'covering linked_entries(from_id, hidden, to_id) '
              'index; refreshing planner stats',
        );
        // Partial covering ORDER BY (task_priority_rank, date_from
        // DESC) within a `task_status IN (?)` partition. Lets the
        // planner stream the tasks list even when the user has
        // selected many categories, instead of falling back to
        // `idx_journal_browse + USE TEMP B-TREE FOR ORDER BY`.
        // Guarded on `journal` because minimal migration-test
        // schemas omit it.
        if (await _tableExists('journal')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_journal_tasks_status_priority_date ON journal('
            '  task_status COLLATE BINARY ASC, '
            '  task_priority_rank COLLATE BINARY ASC, '
            '  date_from COLLATE BINARY DESC) '
            "WHERE type = 'Task' "
            'AND task = 1 '
            'AND deleted = FALSE',
          );
        }
        // Covering variant of the existing (from_id, hidden) index
        // so `getBulkLinkedTimeSpans` resolves `to_id` from the
        // index and the planner stops reversing the join shape.
        // Same table-existence guard as above.
        if (await _tableExists('linked_entries')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_linked_entries_from_id_hidden_to_id '
            'ON linked_entries('
            '  from_id COLLATE BINARY ASC, '
            '  hidden COLLATE BINARY ASC, '
            '  to_id COLLATE BINARY ASC)',
          );
        }
        // One-shot ANALYZE so the planner picks up the new
        // indexes immediately. This runs ONCE per device on the
        // upgrade boot — same trade as any heavy migration step:
        // a single longer-than-usual launch when the user pulls
        // the update, then steady-state from then on.
        await customStatement('ANALYZE');
      }();
    }
    if (from < 43) {
      await () async {
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Backfilling journal.category from serialized JSON for '
              'rows predating the v21 column add',
        );
        // The v21 migration added the denormalized `category` column
        // with DEFAULT '' but never backfilled it, so entries created
        // before 2024-07 (and never re-saved) carry '' in the column
        // while their JSON meta.categoryId holds the real id. Column
        // readers (Insights time analysis, time-history header) would
        // silently attribute that history to "Uncategorized".
        //
        // Encoding note: plain json_extract, NOT datetime functions —
        // the column is TEXT and the JSON value is the raw UUID.
        // Guarded on `journal` because minimal migration-test schemas
        // omit it.
        if (await _tableExists('journal')) {
          await customStatement(
            'UPDATE journal '
            r"SET category = json_extract(serialized, '$.meta.categoryId') "
            "WHERE category = '' "
            r"AND json_extract(serialized, '$.meta.categoryId') IS NOT NULL",
          );
          // Partial covering index for the Insights time-analysis
          // query: only `date_from < :end` can be a seek bound (the
          // `date_to > :start` overlap check is inherently residual),
          // so the scan walks every JournalEntry before :end. Covering
          // (date_from, date_to, category, private, id) turns that
          // walk into an index-only scan — no row fetches — keeping
          // cold-fetch cost flat as lifetime history grows.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_journal_insights_time '
            'ON journal('
            '  date_from COLLATE BINARY ASC, '
            '  date_to COLLATE BINARY ASC, '
            '  category COLLATE BINARY ASC, '
            '  private COLLATE BINARY ASC, '
            '  id COLLATE BINARY ASC) '
            "WHERE type = 'JournalEntry' AND deleted = FALSE",
          );
          await customStatement('ANALYZE');
        }
      }();
    }
  }
}
