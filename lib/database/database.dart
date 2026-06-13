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
part 'database_insights_queries.dart';
part 'database_journal_queries.dart';
part 'database_links_ratings.dart';
part 'database_project_queries.dart';
part 'database_task_due_queries.dart';
part 'database_task_queries.dart';
part 'database_task_query_builders.dart';
part 'database_migration.dart';
part 'database_migration_recent.dart';

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
        _JournalDbMigrationRecent,
        _JournalDbMigration,
        _JournalDbConfigFlags,
        _JournalDbInsightsQueries,
        _JournalDbJournalQueries,
        _JournalDbTaskQueriesBuilders,
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

  @override
  bool inMemoryDatabase = false;
  final DomainLogger? _loggingService;
  final Directory? _documentsDirectory;

  @override
  int get schemaVersion => 43;

  // Check whether a column exists in a given table to make migrations safer
  @override
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

  @override
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

  @override
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

  @override
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
