part of 'database.dart';

/// Most-recent schema-upgrade steps (v41+) for [JournalDb], split from
/// [_JournalDbMigration] for file size and invoked from its onUpgrade.
mixin _JournalDbMigrationRecent on _$JournalDb {
  Future<bool> _columnExists(String table, String column);

  /// Adds a column to [table] unless an interrupted upgrade already did.
  ///
  /// Every step before v48 shipped without a transaction around the upgrade,
  /// so an install killed mid-step can hold the column while `user_version`
  /// still names the previous version. `ALTER TABLE … ADD COLUMN` refuses a
  /// duplicate, and inside the now-atomic upgrade that refusal would roll
  /// the whole upgrade back on every launch; the pre-v48 column-adding steps
  /// therefore skip a column that is already there. [add] issues the
  /// statement: Drift's `Migrator.addColumn` where it derives the definition,
  /// raw SQL where the declared type matters to the schema (`DATETIME`).
  /// Steps from v48 on run atomically and need no such check.
  Future<void> _addColumnUnlessPresent(
    String table,
    String column,
    Future<void> Function() add,
  ) async {
    if (await _columnExists(table, column)) {
      DevLogger.log(
        name: 'JournalDb',
        message:
            'Column $table.$column already present from an interrupted '
            'upgrade; skipping',
      );
      return;
    }
    await add();
  }

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
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Adding due_at column, backfilling from JSON, '
              'recreating tasks-due partial index',
        );

        // 1. Add the nullable column.
        await _addColumnUnlessPresent(
          'journal',
          'due_at',
          () =>
              customStatement('ALTER TABLE journal ADD COLUMN due_at DATETIME'),
        );

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
        // Covering variant of the existing (from_id, hidden) index
        // so `getBulkLinkedTimeSpans` resolves `to_id` from the
        // index and the planner stops reversing the join shape.
        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_linked_entries_from_id_hidden_to_id '
          'ON linked_entries('
          '  from_id COLLATE BINARY ASC, '
          '  hidden COLLATE BINARY ASC, '
          '  to_id COLLATE BINARY ASC)',
        );
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
      }();
    }
    if (from < 44) {
      await () async {
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Adding indexes for broad task-list, import-flag, and '
              'label-definition reads',
        );
        await customStatement(
          _createIdxJournalTasksPriorityDateSql.replaceFirst(
            'CREATE INDEX ',
            'CREATE INDEX IF NOT EXISTS ',
          ),
        );
        await customStatement(
          _createIdxJournalImportFlagDateSql.replaceFirst(
            'CREATE INDEX ',
            'CREATE INDEX IF NOT EXISTS ',
          ),
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_label_definitions_deleted_name_nocase '
          'ON label_definitions('
          '  deleted COLLATE BINARY ASC, '
          '  name COLLATE NOCASE ASC)',
        );
        await customStatement('ANALYZE');
      }();
    }
    if (from < 45) {
      await () async {
        DevLogger.log(
          name: 'JournalDb',
          message:
              'Adding indexed Daily OS day and recording-session lookup '
              'columns',
        );
        await _addColumnUnlessPresent(
          'journal',
          'day_id',
          () => customStatement('ALTER TABLE journal ADD COLUMN day_id TEXT'),
        );
        await _addColumnUnlessPresent(
          'journal',
          'recording_session_id',
          () => customStatement(
            'ALTER TABLE journal ADD COLUMN recording_session_id TEXT',
          ),
        );
        await customStatement(r'''
UPDATE journal
SET day_id = json_extract(serialized, '$.data.dayContext.dayId'),
    recording_session_id =
      json_extract(serialized, '$.data.dayContext.recordingSessionId')
WHERE type = 'JournalAudio' AND deleted = FALSE
''');
        // Preserve one canonical live owner if a pre-release build wrote the
        // same stable session id into more than one journal row. Clearing the
        // shadow column on later duplicates keeps every JSON payload intact
        // while allowing the uniqueness invariant to be installed safely.
        await customStatement('''
UPDATE journal SET recording_session_id = NULL
WHERE recording_session_id IS NOT NULL AND id NOT IN (
  SELECT MIN(id) FROM journal
  WHERE type = 'JournalAudio' AND deleted = FALSE
    AND recording_session_id IS NOT NULL
  GROUP BY recording_session_id
)
''');
        await customStatement('''
CREATE INDEX IF NOT EXISTS idx_journal_day_audio ON journal(
  day_id COLLATE BINARY ASC,
  date_from COLLATE BINARY ASC,
  id COLLATE BINARY ASC
)
WHERE type = 'JournalAudio' AND deleted = FALSE
  AND day_id IS NOT NULL
''');
        await customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_recording_session ON journal(
  recording_session_id COLLATE BINARY ASC
)
WHERE type = 'JournalAudio' AND deleted = FALSE
  AND recording_session_id IS NOT NULL
''');
        await customStatement('ANALYZE');
      }();
    }
    if (from < 46) {
      await () async {
        DevLogger.log(
          name: 'JournalDb',
          message: 'Dropping redundant journal, definition and link indexes',
        );
        // Each of these duplicated an index SQLite already had, so every
        // upsert paid to maintain it without any query being able to
        // prefer it. Fresh installs no longer create them; `IF EXISTS`
        // keeps the step safe on databases that never had them.
        for (final name in _redundantIndexesDroppedInV46) {
          await customStatement('DROP INDEX IF EXISTS $name');
        }
      }();
    }
    if (from < 47) {
      await () async {
        // v47 is the reconciliation release: the index reconcile that now
        // ends every upgrade (see `_reconcileIndexesWithSchema`) needs an
        // upgrade to run once on installs that predate v25. The only
        // version-specific work is the `category_id` column that v20
        // installs kept after v21 replaced it with `category`; its data was
        // never read again (`category` is backfilled from the JSON in v43).
        if (await _columnExists('journal', 'category_id')) {
          DevLogger.log(
            name: 'JournalDb',
            message: 'Dropping the v20 journal.category_id column',
          );
          await customStatement('DROP INDEX IF EXISTS idx_journal_category_id');
          await customStatement('ALTER TABLE journal DROP COLUMN category_id');
        }
      }();
    }
    if (from < 48) {
      await () async {
        // config_flags carried UNIQUE on `description` — a display string,
        // which made rewording a flag a constraint concern and forbade two
        // flags sharing one — and a UNIQUE on `name` that only duplicated
        // the primary key. SQLite cannot drop a table constraint in place,
        // so rebuild the table in the shape database.drift declares.
        DevLogger.log(
          name: 'JournalDb',
          message: 'Rebuilding config_flags without the UNIQUE(description)',
        );
        await customStatement('''
CREATE TABLE config_flags_v48 (
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  status BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (name)
)''');
        await customStatement(
          'INSERT INTO config_flags_v48 (name, description, status) '
          'SELECT name, description, status FROM config_flags',
        );
        await customStatement('DROP TABLE config_flags');
        await customStatement(
          'ALTER TABLE config_flags_v48 RENAME TO config_flags',
        );
      }();
    }
    if (from < 49) {
      await m.createTable(configFlagVersions);
    }
    if (from < 50) {
      await _keyConflictsByVersion();
    }
    // v51 declares idx_journal_checklist_item_home (ADR 0105); the index
    // reconcile that ends every upgrade creates it, so no step is needed.
    if (from < 52) {
      // The speech dictionary as an entity of its own; its index comes from
      // the reconcile. Filling it from the categories' lists is not a schema
      // step: SpeechDictionaryMigration does it, on every device, at start.
      await m.createTable(speechDictionaryEntries);
    }
  }

  /// v50: one conflict row per concurrent version of an entry (ADR 0092).
  /// The table was keyed by the entry id alone, so a second concurrent
  /// version replaced the first. SQLite cannot change a primary key in
  /// place, so the table is rebuilt in the shape database.drift declares,
  /// and each existing row's `version_key` is derived from the clock of the
  /// version it holds. A row whose payload cannot be read keeps `''`: one
  /// row per entry before this step, so the key stays unique.
  Future<void> _keyConflictsByVersion() async {
    DevLogger.log(
      name: 'JournalDb',
      message: 'Rebuilding conflicts with one row per version',
    );
    await customStatement('''
CREATE TABLE conflicts_v50 (
  id TEXT NOT NULL,
  version_key TEXT NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  serialized TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL,
  PRIMARY KEY (id, version_key)
)''');
    await customStatement(
      'INSERT INTO conflicts_v50 '
      '(id, version_key, created_at, updated_at, serialized, schema_version, '
      'status) '
      "SELECT id, '', created_at, updated_at, serialized, schema_version, "
      'status FROM conflicts',
    );
    await customStatement('DROP TABLE conflicts');
    await customStatement('ALTER TABLE conflicts_v50 RENAME TO conflicts');
    // Dropping the table dropped its index; recreate it with the table, so
    // the index reconcile that ends the upgrade finds nothing to add.
    await customStatement(_createIdxConflictsStatusCreatedSql);

    final rows = await customSelect(
      'SELECT id, serialized FROM conflicts',
    ).get();
    for (final row in rows) {
      final key = _versionKeyOf(row.read<String>('serialized'));
      if (key.isEmpty) continue;
      await customStatement(
        'UPDATE conflicts SET version_key = ? WHERE id = ?',
        [key, row.read<String>('id')],
      );
    }
  }

  /// The `version_key` of the version [serialized] holds, or `''` when it
  /// has no clock or cannot be read.
  static String _versionKeyOf(String serialized) {
    try {
      final json = jsonDecode(serialized) as Map<String, dynamic>;
      final meta = json['meta'] as Map<String, dynamic>?;
      final clock = meta?['vectorClock'] as Map<String, dynamic>?;
      return clock == null ? '' : VectorClock.fromJson(clock).canonicalKey;
    } catch (_) {
      return '';
    }
  }
}

/// Indexes dropped by the v46 step, with the index that already covers each:
///
/// * `idx_journal_date_from_desc`, `idx_journal_date_to_desc` — single-column
///   DESC twins of the ASC indexes; SQLite walks an index in either direction.
/// * the four `idx_*_definitions_id` indexes — the primary key on `id`
///   already carries an automatic unique index.
/// * `idx_linked_entries_from_id`, `idx_linked_entries_to_id` — leading
///   prefixes of `(from_id, hidden, …)` and `(to_id, hidden)` /
///   `(to_id, type)`.
/// * `idx_linked_entries_hidden` — a lone boolean column.
const List<String> _redundantIndexesDroppedInV46 = [
  'idx_journal_date_from_desc',
  'idx_journal_date_to_desc',
  'idx_habit_definitions_id',
  'idx_category_definitions_id',
  'idx_label_definitions_id',
  'idx_dashboard_definitions_id',
  'idx_linked_entries_from_id',
  'idx_linked_entries_to_id',
  'idx_linked_entries_hidden',
];
