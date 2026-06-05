import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

part 'database.g.dart';
part 'database_config_flags.dart';
part 'database_data_queries.dart';
part 'database_definitions.dart';
part 'database_entity_ops.dart';
part 'database_journal_queries.dart';
part 'database_links_ratings.dart';
part 'database_project_queries.dart';
part 'database_task_due_queries.dart';
part 'database_task_queries.dart';

const journalDbFileName = 'db.sqlite';

// Partial indexes declared as top-level constants so the `onUpgrade`
// migration, `beforeOpen` self-heal, and the migration tests all share one
// SQL definition. The strings start with `CREATE INDEX ` so both call sites
// can prefix `IF NOT EXISTS` via a single replaceFirst.
//
// `idx_journal_tasks_due_open` is keyed on the denormalized `due_at`
// column (added in v41), replacing the original v39 expression-keyed
// shape `json_extract(serialized,'$.data.due')`. The new column lets the
// planner stream `ORDER BY due_at ASC` directly from the index without
// per-row JSON parsing.
const String _createIdxJournalTasksDueOpenSql =
    'CREATE INDEX idx_journal_tasks_due_open '
    'ON journal(due_at ASC) '
    "WHERE type = 'Task' "
    'AND task = 1 '
    'AND deleted = FALSE '
    "AND task_status NOT IN ('DONE', 'REJECTED')";

const String _createIdxJournalTaskStatusPrivateSql =
    'CREATE INDEX idx_journal_task_status_private '
    'ON journal(task_status COLLATE BINARY ASC, '
    'private COLLATE BINARY ASC) '
    "WHERE type = 'Task' AND task = 1 AND deleted = FALSE";

const String _createIdxJournalQuantLatestSql =
    'CREATE INDEX IF NOT EXISTS idx_journal_quant_latest '
    'ON journal(subtype COLLATE BINARY ASC, date_from COLLATE BINARY DESC) '
    "WHERE type = 'QuantitativeEntry' AND deleted = FALSE";

/// SQL subquery that resolves the most-recent active ProjectLink for a task.
/// Used both during migration back-fill and in [JournalDb.upsertJournalDbEntity]
/// to keep the denormalized `project_id` column consistent.
const _projectIdSubquery =
    '  SELECT le.from_id FROM linked_entries le'
    '  WHERE le.to_id = journal.id'
    "  AND le.type = 'ProjectLink'"
    '  AND COALESCE(le.hidden, false) = false'
    '  ORDER BY COALESCE(le.updated_at, le.created_at) DESC, le.id DESC'
    '  LIMIT 1';

/// Conservative chunk size for `IN :ids` drift queries to stay under
/// SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` of 999 with headroom
/// for other variables in the same statement.
const int _sqliteInListChunk = 500;

@DriftDatabase(
  include: {'database.drift'},
)
class JournalDb extends _$JournalDb
    with
        _JournalDbConfigFlags,
        _JournalDbJournalQueries,
        _JournalDbTaskQueries,
        _JournalDbTaskDueQueries,
        _JournalDbProjectQueries,
        _JournalDbLinksRatings,
        _JournalDbDataQueries,
        _JournalDbDefinitions,
        _JournalDbEntityOps {
  JournalDb({
    this.inMemoryDatabase = false,
    String? overriddenFilename,
    int readPool = 4,
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    this._loggingService,
    this._documentsDirectory,
  }) : super(
         openDbConnection(
           overriddenFilename ?? journalDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           readPool: readPool,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  bool inMemoryDatabase = false;
  final DomainLogger? _loggingService;
  final Directory? _documentsDirectory;

  @override
  int get schemaVersion => 42;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // PRAGMA is connection-local — must run on every connection.
        await customStatement('PRAGMA foreign_keys = ON');
        if (await _tableExists('journal')) {
          await customStatement(_createIdxJournalQuantLatestSql);
        }
      },
      onCreate: (Migrator m) async {
        return m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        DevLogger.log(
          name: 'JournalDb',
          message: 'Migration from v$from to v$to',
        );

        if (!inMemoryDatabase) {
          try {
            await createDbBackup(journalDbFileName);
            DevLogger.log(
              name: 'JournalDb',
              message: 'Database backup created before migration',
            );
          } catch (e, s) {
            DevLogger.error(
              name: 'JournalDb',
              message: 'Failed to create backup before migration',
              error: e,
              stackTrace: s,
            );
          }
        }

        if (from < 19) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Creating category_definitions table and indices',
            );
            await m.createTable(categoryDefinitions);
            await m.createIndex(idxCategoryDefinitionsName);
            await m.createIndex(idxCategoryDefinitionsId);
            await m.createIndex(idxCategoryDefinitionsPrivate);
          }();
        }

        if (from < 21) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Add category_id in journal table, with index',
            );
            await m.addColumn(journal, journal.category);
          }();
        }

        if (from < 22) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Add hidden in linked_entries table, with index',
            );
            await m.addColumn(linkedEntries, linkedEntries.hidden);
            await m.createIndex(idxLinkedEntriesHidden);
          }();
        }

        if (from < 23) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Add timestamps in linked_entries table, with index',
            );
            await m.addColumn(linkedEntries, linkedEntries.createdAt);
            await m.addColumn(linkedEntries, linkedEntries.updatedAt);
          }();
        }

        if (from < 24) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding composite indices',
            );
            await m.createIndex(idxLinkedEntriesFromIdHidden);
            await m.createIndex(idxLinkedEntriesToIdHidden);
          }();
        }

        if (from < 25) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding composite indices',
            );
            await m.createIndex(idxJournalTab);
            await m.createIndex(idxJournalTasks);
            await m.createIndex(idxJournalTypeSubtype);
          }();
        }

        if (from < 26) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Creating label_definitions and labeled tables',
            );
            await m.createTable(labelDefinitions);
            await m.createIndex(idxLabelDefinitionsId);
            await m.createIndex(idxLabelDefinitionsName);
            await m.createIndex(idxLabelDefinitionsPrivate);

            await m.createTable(labeled);
            await m.createIndex(idxLabeledJournalId);
            await m.createIndex(idxLabeledLabelId);
          }();
        }

        if (from < 27) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Ensuring label tables exist for legacy v26 installs',
            );
            await _ensureLabelTables(m);
          }();
        }

        // v28: Rebuild `labeled` with FK on label_id -> label_definitions(id) ON DELETE CASCADE
        if (from < 28) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message:
                  'Rebuilding labeled table to add FK with ON DELETE CASCADE',
            );
            await _rebuildLabeledWithFkCascade();
          }();
        }

        // v29: Add task priority columns and update tasks index
        if (from < 29) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding task priority columns and updating index',
            );

            // Add columns only if missing to avoid masking other errors
            final hasTaskPriority = await _columnExists(
              'journal',
              'task_priority',
            );
            if (!hasTaskPriority) {
              await m.addColumn(journal, journal.taskPriority);
            }

            final hasTaskPriorityRank = await _columnExists(
              'journal',
              'task_priority_rank',
            );
            if (!hasTaskPriorityRank) {
              await m.addColumn(journal, journal.taskPriorityRank);
            }

            // Backfill existing task rows to P2/2
            await customStatement(
              "UPDATE journal SET task_priority = 'P2', task_priority_rank = 2 WHERE task = 1 AND (task_priority IS NULL OR task_priority = '')",
            );

            // Rebuild index to include priority rank
            await customStatement('DROP INDEX IF EXISTS idx_journal_tasks');
            await m.createIndex(idxJournalTasks);
          }();
        }

        // v30: Fix copy-paste bug in idx_linked_entries_to_id_hidden
        // which was indexing from_id instead of to_id
        if (from < 30) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Fixing idx_linked_entries_to_id_hidden to index to_id',
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_linked_entries_to_id_hidden',
            );
            await m.createIndex(idxLinkedEntriesToIdHidden);
          }();
        }

        // v33: Originally rebuilt the active task due-date index as a
        // non-partial composite so it could be forced with INDEXED BY.
        // The index itself is dropped in v41 (consumer rewritten to read
        // the denormalized `due_at` column), so the v33 step is now just a
        // no-op DROP — both for fresh installs that skip straight to v41
        // and for legacy databases that already created the old index.
        if (from < 33) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Dropping legacy active task due-date index',
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_journal_tasks_due_active',
            );
          }();
        }

        // v34: Add composite indexes for definition list screens and the
        // recency-ordered linksFromId() query.
        if (from < 34) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding definition list and link recency indexes',
            );
            if (await _tableExists('habit_definitions')) {
              await customStatement(
                'DROP INDEX IF EXISTS idx_habit_definitions_deleted_private',
              );
              await m.createIndex(idxHabitDefinitionsDeletedPrivate);
            }
            if (await _tableExists('label_definitions')) {
              await customStatement(
                'DROP INDEX IF EXISTS idx_label_definitions_deleted_private_name',
              );
              await m.createIndex(idxLabelDefinitionsDeletedPrivateName);
            }
            if (await _tableExists('dashboard_definitions')) {
              await customStatement(
                'DROP INDEX IF EXISTS idx_dashboard_definitions_deleted_private_name',
              );
              await m.createIndex(idxDashboardDefinitionsDeletedPrivateName);
            }
            // tag_entities index migration removed — table is no longer
            // managed by drift but left intact in existing databases.
            if (await _tableExists('linked_entries')) {
              await customStatement(
                'DROP INDEX IF EXISTS idx_linked_entries_from_id_hidden_created_at_desc',
              );
              await m.createIndex(idxLinkedEntriesFromIdHiddenCreatedAtDesc);
            }
          }();
        }

        // v35: Add a date-oriented task index for date-sorted task queries.
        if (from < 35) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding date-oriented task index',
            );
            if (await _tableExists('journal')) {
              await customStatement(
                'DROP INDEX IF EXISTS idx_journal_tasks_date',
              );
              await m.createIndex(idxJournalTasksDate);
            }
          }();
        }

        // v36: Add a browse-oriented journal index for common journal lists.
        if (from < 36) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding browse-oriented journal index',
            );
            if (await _tableExists('journal')) {
              await customStatement('DROP INDEX IF EXISTS idx_journal_browse');
              await m.createIndex(idxJournalBrowse);
            }
          }();
        }

        // v37: Rebuild task indexes as partial active-task indexes, add a
        // priority-aware date index, and add a composite labeled lookup index.
        if (from < 37) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message:
                  'Rebuilding task indexes and adding labeled lookup index',
            );
            if (await _tableExists('journal')) {
              await customStatement('DROP INDEX IF EXISTS idx_journal_tasks');
              await customStatement(
                'DROP INDEX IF EXISTS idx_journal_tasks_date',
              );
              await customStatement(
                'DROP INDEX IF EXISTS idx_journal_tasks_date_priority',
              );
              await m.createIndex(idxJournalTasks);
              await m.createIndex(idxJournalTasksDate);
              await m.createIndex(idxJournalTasksDatePriority);
            }
            if (await _tableExists('labeled')) {
              // Remove redundant index — the UNIQUE(journal_id, label_id)
              // constraint already creates an equivalent implicit index.
              await customStatement(
                'DROP INDEX IF EXISTS idx_labeled_journal_id_label_id',
              );
            }
          }();
        }

        // v38: Add denormalized project_id column to journal for efficient
        // task-by-project filtering without a JOIN on linked_entries.
        if (from < 38) {
          await () async {
            if (!await _tableExists('journal')) return;
            DevLogger.log(
              name: 'JournalDb',
              message: 'Adding project_id column to journal table',
            );
            final hasProjectId = await _columnExists('journal', 'project_id');
            if (!hasProjectId) {
              await m.addColumn(journal, journal.projectId);
            }
            // Backfill project_id from the most-recent active ProjectLink.
            // Guarded by try-catch because minimal migration-test schemas may
            // not include the linked_entries table.
            try {
              await customStatement(
                "UPDATE journal SET project_id = ($_projectIdSubquery) WHERE type = 'Task'",
              );
            } catch (_) {
              // linked_entries does not exist in this DB — backfill skipped.
            }
            await customStatement(
              'DROP INDEX IF EXISTS idx_journal_project_id',
            );
            await m.createIndex(idxJournalProjectId);
          }();
        }

        // v39: Add a partial expression index for the open-task due-date
        // query (`_selectTasksDue`) so the ORDER BY streams from the index,
        // and add idx_journal_task_status_private so `countInProgressTasks`
        // and similar global task-status counts can use a narrow partial
        // index instead of scanning the full task set.
        //
        // The due-open partial is created here in its original
        // expression-keyed shape (`json_extract(serialized,'$.data.due')`)
        // because the `due_at` column it would otherwise reference is not
        // added until v41. The v41 step below drops this expression-keyed
        // form and recreates the partial on the column.
        if (from < 39) {
          await () async {
            if (!await _tableExists('journal')) return;
            DevLogger.log(
              name: 'JournalDb',
              message:
                  'Adding open-task due-date partial index and '
                  'task_status/private count index',
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_journal_tasks_due_open',
            );
            await customStatement(
              'CREATE INDEX idx_journal_tasks_due_open '
              r"ON journal(json_extract(serialized, '$.data.due') ASC) "
              "WHERE type = 'Task' "
              'AND task = 1 '
              'AND deleted = FALSE '
              "AND task_status NOT IN ('DONE', 'REJECTED')",
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_journal_task_status_private',
            );
            await customStatement(_createIdxJournalTaskStatusPrivateSql);
          }();
        }

        // v40: Slow-query log surfaced four hotspots that all fall
        // within the journal/linked_entries indexing surface. See
        // `logs/slow_queries-2026-04-28.log` for the production
        // traces this batch addresses.
        if (from < 40) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message:
                  'Adding linked_entries (to_id, type) composite + '
                  'rating partial; journal (project_id, task_status) '
                  'partial; backfilling task_priority_rank',
            );

            if (await _tableExists('linked_entries')) {
              // Reverse-link `(to_id, type)` lookups (project rollups,
              // link expansion). The single-column `(to_id)` index
              // forced a per-row heap probe to evaluate `type`.
              await customStatement(
                'DROP INDEX IF EXISTS idx_linked_entries_to_id_type',
              );
              await m.createIndex(idxLinkedEntriesToIdType);
              // Hot partial for rating reverse-links (~867 hits/day,
              // ~375 s of cumulative DB time on a desktop trace).
              await customStatement(
                'DROP INDEX IF EXISTS idx_linked_entries_rating_to_id',
              );
              await m.createIndex(idxLinkedEntriesRatingToId);
            }

            if (await _tableExists('journal')) {
              // Backfill any task rows that escaped the v29 fill so
              // the new ORDER BY clauses (which dropped the
              // `COALESCE(task_priority_rank, 2)` wrapper) match the
              // index sort exactly. The application layer already
              // defaults `TaskPriority.p2Medium` (rank=2) on every
              // task write, so this only affects rare legacy rows.
              await customStatement(
                'UPDATE journal '
                'SET task_priority_rank = 2 '
                "WHERE type = 'Task' "
                'AND task = 1 '
                'AND task_priority_rank IS NULL',
              );

              // Covering partial for `getProjectTaskRollups` so the
              // SUM(CASE WHEN task_status = …) counts do not pull
              // every task row from the heap.
              await customStatement(
                'DROP INDEX IF EXISTS idx_journal_project_task_status',
              );
              await m.createIndex(idxJournalProjectTaskStatus);
            }
          }();
        }

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
      },
    );
  }

  // Check whether a column exists in a given table to make migrations safer
  Future<bool> _columnExists(String table, String column) async {
    try {
      final rows = await customSelect('PRAGMA table_info($table)').get();
      for (final row in rows) {
        final name = row.read<String>('name');
        if (name == column) return true;
      }
      return false;
    } catch (_) {
      // If PRAGMA fails for any reason, fall back to false so migration attempts add the column
      return false;
    }
  }

  @visibleForTesting
  Future<bool> columnExistsForTesting(String table, String column) =>
      _columnExists(table, column);

  @override
  Future<void> close() async {
    await _configFlagsController.close();
    await super.close();
  }

  Future<void> _ensureLabelTables(Migrator migrator) async {
    final hasLabelDefinitions = await _tableExists('label_definitions');
    if (!hasLabelDefinitions) {
      await migrator.createTable(labelDefinitions);
      await migrator.createIndex(idxLabelDefinitionsId);
      await migrator.createIndex(idxLabelDefinitionsName);
      await migrator.createIndex(idxLabelDefinitionsPrivate);
    }

    final hasLabeledTable = await _tableExists('labeled');
    if (!hasLabeledTable) {
      await migrator.createTable(labeled);
      await migrator.createIndex(idxLabeledJournalId);
      await migrator.createIndex(idxLabeledLabelId);
    }
  }

  Future<void> _rebuildLabeledWithFkCascade() async {
    // Create a replacement table with the desired foreign key constraint.
    // Defensive drop to ensure idempotency if this step reruns.
    await customStatement('DROP TABLE IF EXISTS labeled_new');
    await customStatement('''
CREATE TABLE IF NOT EXISTS labeled_new (
  id TEXT NOT NULL UNIQUE,
  journal_id TEXT NOT NULL,
  label_id TEXT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
  FOREIGN KEY(label_id) REFERENCES label_definitions(id) ON DELETE CASCADE,
  UNIQUE(journal_id, label_id)
)''');

    // Copy only valid rows to avoid FK violations (skip orphaned label refs).
    await customStatement('''
INSERT INTO labeled_new (id, journal_id, label_id)
SELECT l.id, l.journal_id, l.label_id
FROM labeled l
WHERE EXISTS (
  SELECT 1 FROM label_definitions d WHERE d.id = l.label_id
)
''');

    // Replace old table with the new one and recreate indexes.
    await customStatement('DROP TABLE IF EXISTS labeled');
    await customStatement('ALTER TABLE labeled_new RENAME TO labeled');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_labeled_journal_id ON labeled (journal_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_labeled_label_id ON labeled (label_id)',
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [
        Variable.withString('table'),
        Variable.withString(tableName),
      ],
    ).get();
    return result.isNotEmpty;
  }

  @override
  Future<void> _persistEntityJson(JournalEntity updated) =>
      saveJournalEntityJson(
        updated,
        documentsDirectory: _documentsDirectory,
      );

  @override
  void _captureException(
    Object error, {
    required String subDomain,
    required StackTrace? stackTrace,
  }) {
    final logger = _logger;
    if (logger == null) {
      return;
    }

    logger.error(
      LogDomain.database,
      error,
      stackTrace: stackTrace,
      subDomain: subDomain,
    );
  }

  @override
  void _captureEvent(
    String message, {
    required String subDomain,
  }) {
    final logger = _logger;
    if (logger == null) {
      return;
    }

    logger.log(
      LogDomain.database,
      message,
      subDomain: subDomain,
    );
  }

  DomainLogger? get _logger {
    if (_loggingService != null) {
      return _loggingService;
    }

    if (getIt.isRegistered<DomainLogger>()) {
      return getIt<DomainLogger>();
    }

    return null;
  }
}
