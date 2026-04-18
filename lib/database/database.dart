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
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';

part 'database.g.dart';

const journalDbFileName = 'db.sqlite';

enum ConflictStatus {
  unresolved,
  resolved,
}

typedef LinkedEntityTimeSpan = ({
  String id,
  DateTime dateFrom,
  DateTime dateTo,
});

typedef ProjectTaskRollupCounts = ({
  int totalTaskCount,
  int completedTaskCount,
  int blockedTaskCount,
});

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

@DriftDatabase(
  include: {'database.drift'},
)
class JournalDb extends _$JournalDb {
  JournalDb({
    this.inMemoryDatabase = false,
    String? overriddenFilename,
    int readPool = 4,
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    LoggingService? loggingService,
    Directory? documentsDirectory,
  }) : _loggingService = loggingService,
       _documentsDirectory = documentsDirectory,
       super(
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
  final LoggingService? _loggingService;
  final Directory? _documentsDirectory;
  final Map<String, ConfigFlag> _configFlagsByName = <String, ConfigFlag>{};
  final StreamController<Set<ConfigFlag>> _configFlagsController =
      StreamController<Set<ConfigFlag>>.broadcast(sync: true);
  Future<void>? _configFlagsBootstrap;
  bool _configFlagsLoaded = false;

  @override
  int get schemaVersion => 39;

  /// Conservative chunk size for `IN :ids` drift queries to stay under
  /// SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` of 999 with headroom
  /// for other variables in the same statement.
  static const int _sqliteInListChunk = 500;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
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

        // v33: Rebuild the active task due-date index as a non-partial
        // composite index so it can be safely forced with INDEXED BY.
        if (from < 33) {
          await () async {
            DevLogger.log(
              name: 'JournalDb',
              message: 'Rebuilding active task due-date index',
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_journal_tasks_due_active',
            );
            await m.createIndex(idxJournalTasksDueActive);
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
        // index instead of scanning the full task set. The existing
        // non-partial `idx_journal_tasks_due_active` is intentionally left
        // in place — other callers (e.g. `getTasksSortedByDueDate`) pin it
        // via INDEXED BY with IN-list task_status predicates that can't
        // prove the partial's WHERE.
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
            await customStatement(
              'CREATE INDEX idx_journal_task_status_private '
              'ON journal(task_status COLLATE BINARY ASC, '
              'private COLLATE BINARY ASC) '
              "WHERE type = 'Task' AND task = 1 AND deleted = FALSE",
            );
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

  Future<int> upsertJournalDbEntity(JournalDbEntity entry) async {
    final res = await into(journal).insertOnConflictUpdate(entry);
    // insertOnConflictUpdate overwrites every column including project_id
    // (which is not in the serialized payload). Restore it from linked_entries
    // so the denormalized column stays consistent after any upsert.
    await customStatement(
      'UPDATE journal SET project_id = ($_projectIdSubquery) WHERE id = ?',
      [entry.id],
    );
    return res;
  }

  Future<void> updateTaskPriorityColumn({
    required String id,
    required String priority,
    required int rank,
  }) async {
    try {
      await customStatement(
        'UPDATE journal SET task_priority = ?, task_priority_rank = ? WHERE id = ?',
        [priority, rank, id],
      );
    } catch (e) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'updateTaskPriorityColumn error',
        error: e,
      );
    }
  }

  /// Updates the denormalized `project_id` column for a task row.
  ///
  /// Pass [projectId] = null to clear the project association.
  Future<void> updateProjectIdColumn(String taskId, String? projectId) async {
    try {
      await customStatement(
        'UPDATE journal SET project_id = ? WHERE id = ?',
        [projectId, taskId],
      );
    } catch (e) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'updateProjectIdColumn error',
        error: e,
      );
    }
  }

  /// Returns the IDs of all non-deleted tasks whose `project_id` is in
  /// [projectIds]. Uses the `idx_journal_project_id` partial index.
  Future<Set<String>> getTaskIdsForProjects(Set<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final rows =
        await (select(journal)..where(
              (t) =>
                  t.projectId.isIn(projectIds.toList()) &
                  t.type.equals('Task') &
                  t.deleted.equals(false),
            ))
            .get();
    return rows.map((r) => r.id).toSet();
  }

  /// Returns the subset of [projectIds] that still resolve to live projects.
  Future<Set<String>> getExistingProjectIds(Set<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final rows =
        await (selectOnly(journal)
              ..addColumns([journal.id])
              ..where(
                journal.id.isIn(projectIds.toList()) &
                    journal.type.equals('Project') &
                    journal.deleted.equals(false),
              ))
            .get();
    return rows.map((row) => row.read(journal.id)).whereType<String>().toSet();
  }

  /// Returns project IDs for any live task in [taskIds] that is linked to a
  /// project via the denormalized `project_id` column.
  Future<Set<String>> getProjectIdsForTaskIds(Set<String> taskIds) async {
    if (taskIds.isEmpty) return {};
    final rows =
        await (selectOnly(journal)
              ..addColumns([journal.projectId])
              ..where(
                journal.id.isIn(taskIds.toList()) &
                    journal.type.equals('Task') &
                    journal.deleted.equals(false) &
                    journal.projectId.isNotNull(),
              ))
            .get();
    return rows
        .map((row) => row.read(journal.projectId))
        .whereType<String>()
        .toSet();
  }

  /// Returns all visible, non-deleted projects across categories.
  Future<List<ProjectEntry>> getVisibleProjects() async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);

    var predicate =
        journal.type.equals('Project') & journal.deleted.equals(false);
    if (!matchesAllPrivateStates) {
      predicate = predicate & journal.private.isIn(privateStatuses);
    }

    final rows =
        await (select(journal)
              ..where((_) => predicate)
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.dateFrom,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return rows.map(fromDbEntity).whereType<ProjectEntry>().toList();
  }

  /// Returns aggregate task counts for all [projectIds] in one query.
  Future<Map<String, ProjectTaskRollupCounts>> getProjectTaskRollups(
    Set<String> projectIds,
  ) async {
    if (projectIds.isEmpty) {
      return const <String, ProjectTaskRollupCounts>{};
    }

    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);
    final projectPlaceholders = List.filled(projectIds.length, '?').join(', ');
    final privateClause = matchesAllPrivateStates
        ? ''
        : ' AND private IN (${List.filled(privateStatuses.length, '?').join(', ')})';

    final rows = await customSelect(
      '''
        SELECT
          project_id,
          COUNT(*) AS total_count,
          SUM(CASE WHEN task_status = 'DONE' THEN 1 ELSE 0 END) AS completed_count,
          SUM(CASE WHEN task_status = 'BLOCKED' THEN 1 ELSE 0 END) AS blocked_count
        FROM journal
        WHERE project_id IN ($projectPlaceholders)
          AND deleted = FALSE
          AND type = 'Task'
          $privateClause
        GROUP BY project_id
      ''',
      variables: [
        ...projectIds.map(Variable.withString),
        if (!matchesAllPrivateStates) ...privateStatuses.map(Variable.withBool),
      ],
      readsFrom: {journal},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('project_id'): (
          totalTaskCount: row.read<int>('total_count'),
          completedTaskCount: row.read<int>('completed_count'),
          blockedTaskCount: row.read<int>('blocked_count'),
        ),
    };
  }

  Future<int> addConflict(Conflict conflict) async {
    return into(conflicts).insertOnConflictUpdate(conflict);
  }

  Future<VclockStatus> detectConflict(
    JournalEntity existing,
    JournalEntity updated,
  ) async {
    final vcA = existing.meta.vectorClock;
    final vcB = updated.meta.vectorClock;

    if (vcA != null && vcB != null) {
      final status = VectorClock.compare(vcA, vcB);

      if (status == VclockStatus.concurrent) {
        DevLogger.warning(
          name: 'JournalDb',
          message: 'Conflicting vector clocks: $status',
        );
        final now = DateTime.now();
        await addConflict(
          Conflict(
            id: updated.meta.id,
            createdAt: now,
            updatedAt: now,
            serialized: jsonEncode(updated),
            schemaVersion: schemaVersion,
            status: ConflictStatus.unresolved.index,
          ),
        );
      }

      return status;
    }
    return VclockStatus.b_gt_a;
  }

  Future<void> insertLabel(String journalId, String labelId) async {
    try {
      await into(labeled).insert(
        LabeledWith(
          id: uuid.v1(),
          journalId: journalId,
          labelId: labelId,
        ),
      );
    } catch (ex) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'insertLabel failed',
        error: ex,
      );
    }
  }

  Future<Set<String>> _labelIdsForJournalId(String journalId) async {
    final existing = await labeledForJournal(journalId).get();
    return existing.toSet();
  }

  Future<void> addLabeled(JournalEntity journalEntity) async {
    final journalId = journalEntity.meta.id;
    final targetLabelIds = journalEntity.meta.labelIds?.toSet() ?? {};
    final currentLabelIds = await _labelIdsForJournalId(journalId);

    final labelsToAdd = targetLabelIds.difference(currentLabelIds);
    final labelsToRemove = currentLabelIds.difference(targetLabelIds);
    await transaction(() async {
      for (final labelId in labelsToAdd) {
        await insertLabel(journalId, labelId);
      }

      for (final labelId in labelsToRemove) {
        await deleteLabeledRow(journalId, labelId);
      }
    });
  }

  Future<JournalUpdateResult> updateJournalEntity(
    JournalEntity updated, {
    bool overrideComparison = false,
    bool overwrite = true,
  }) async {
    var applied = false;
    JournalUpdateSkipReason? skipReason;
    var rowsWritten = 0;
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    final existingDbEntity = await entityById(dbEntity.id);

    if (existingDbEntity != null && !overwrite) {
      skipReason = JournalUpdateSkipReason.overwritePrevented;
    } else if (existingDbEntity != null) {
      final existing = fromDbEntity(existingDbEntity);
      VclockStatus? status;
      try {
        status = await detectConflict(existing, updated);
      } catch (error, stackTrace) {
        _captureException(
          error,
          domain: 'JOURNAL_DB',
          subDomain: 'detectConflict',
          stackTrace: stackTrace,
        );
        skipReason = JournalUpdateSkipReason.conflict;
      }

      final canApply =
          status == VclockStatus.b_gt_a ||
          (overrideComparison && status != null);

      if (canApply) {
        rowsWritten = await upsertJournalDbEntity(dbEntity);
        applied = true;
        final existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else if (status != null) {
        _captureEvent(
          EnumToString.convertToString(status),
          domain: 'JOURNAL_DB',
          subDomain: 'Conflict status',
        );
        skipReason = status == VclockStatus.concurrent
            ? JournalUpdateSkipReason.conflict
            : JournalUpdateSkipReason.olderOrEqual;
      } else {
        skipReason ??= JournalUpdateSkipReason.conflict;
      }
    } else {
      rowsWritten = await upsertJournalDbEntity(dbEntity);
      applied = true;
    }

    if (applied) {
      await saveJournalEntityJson(
        updated,
        documentsDirectory: _documentsDirectory,
      );
      await addLabeled(updated);
      return JournalUpdateResult.applied(rowsWritten: rowsWritten);
    }

    return JournalUpdateResult.skipped(
      reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
    );
  }

  Future<JournalDbEntity?> entityById(String id) async {
    final res =
        await (select(journal)
              ..where((t) => t.id.equals(id))
              ..where((t) => t.deleted.equals(false)))
            .get();

    return res.firstOrNull;
  }

  Future<Conflict?> conflictById(String id) async {
    final res = await (select(conflicts)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<JournalEntity?> journalEntityById(String id) async {
    final dbEntity = await entityById(id);
    if (dbEntity != null) {
      return fromDbEntity(dbEntity);
    }
    return null;
  }

  Future<List<JournalEntity>> getJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    Set<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  }) async {
    final res = await _selectJournalEntities(
      types: types,
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      flaggedStatuses: flaggedStatuses,
      categoryIds: categoryIds?.toList(),
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesForIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <JournalEntity>[];
    }
    final idList = ids.toList(growable: false);
    final dbEntities =
        await _queryWithPrivateFilter(
            allPrivate: () =>
                journalEntitiesByIdsUnorderedAllPrivate(idList).get(),
            filtered: (s) => journalEntitiesByIdsUnordered(idList, s).get(),
          )
          ..sort((a, b) {
            final dateCompare = b.dateFrom.compareTo(a.dateFrom);
            if (dateCompare != 0) return dateCompare;
            return a.id.compareTo(b.id);
          });
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesForIdsUnordered(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <JournalEntity>[];
    }
    final idList = ids.toList(growable: false);
    final dbEntities = await _queryWithPrivateFilter(
      allPrivate: () => journalEntitiesByIdsUnorderedAllPrivate(idList).get(),
      filtered: (s) => journalEntitiesByIdsUnordered(idList, s).get(),
    );
    return dbEntities.map(fromDbEntity).toList();
  }

  /// Lean metadata-only fetch: returns the denormalized `category` column for
  /// each id, without loading or deserializing the fat `serialized` JSON
  /// payload. Intended for callers that only need the category-id lookup
  /// (e.g. time-history header aggregation) — any caller that also needs
  /// `meta.categoryId` as the source of truth can use this without losing
  /// information because `conversions.toDbEntity` keeps the column in lock-
  /// step with the JSON on every upsert.
  ///
  /// Entries filtered out by the private-status gate are simply absent from
  /// the returned map. An empty category value in the `journal.category`
  /// column is returned as `null` so callers can treat "no category" and
  /// "not present" uniformly.
  Future<Map<String, String?>> getCategoryIdsForEntryIds(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) return const <String, String?>{};
    final pairs = await _queryWithPrivateFilter<List<MapEntry<String, String>>>(
      allPrivate: () async {
        final rows = await journalCategoriesByIds(idList).get();
        return [for (final row in rows) MapEntry(row.id, row.category)];
      },
      filtered: (s) async {
        final rows = await journalCategoriesByIdsByPrivateStatuses(
          idList,
          s,
        ).get();
        return [for (final row in rows) MapEntry(row.id, row.category)];
      },
    );
    return {
      for (final pair in pairs)
        pair.key: pair.value.isEmpty ? null : pair.value,
    };
  }

  Future<List<String>> getJournalEntityIdsSortedByDateFromDesc(
    Iterable<String> ids,
  ) {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) {
      return Future.value(const <String>[]);
    }
    return _queryWithPrivateFilter(
      allPrivate: () => journalEntityIdsByDateFromDescAllPrivate(idList).get(),
      filtered: (s) => journalEntityIdsByDateFromDesc(idList, s).get(),
    );
  }

  Future<Map<String, Duration?>> getTaskEstimatesByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <String, Duration?>{};
    }

    final idList = ids.toSet().toList(growable: false);
    final placeholders = List.filled(idList.length, '?').join(', ');
    final rows = await customSelect(
      '''
      SELECT id, json_extract(serialized, '\$.data.estimate') AS estimate_us
      FROM journal
      WHERE deleted = FALSE
      AND type = 'Task'
      AND id IN ($placeholders)
      ''',
      variables: [
        for (final id in idList) Variable<String>(id),
      ],
      readsFrom: {journal},
    ).get();

    return <String, Duration?>{
      for (final row in rows)
        row.read<String>('id'): switch (row.readNullable<int>('estimate_us')) {
          final micros? => Duration(microseconds: micros),
          null => null,
        },
    };
  }

  /// Stream entries with their vector clocks for populating the sequence log.
  /// Yields batches of records with entry ID and vector clock map.
  /// Uses lightweight JSON extraction to avoid full deserialization.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamEntriesWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      final batch = await (select(journal)..limit(batchSize, offset: offset))
          .map(
            (row) => (
              id: row.id,
              vectorClock: _extractVectorClock(row.serialized),
            ),
          )
          .get();

      if (batch.isEmpty) break;

      yield batch;
      offset += batchSize;
    }
  }

  /// Stream entry links with their vector clocks for populating the sequence log.
  /// Yields batches of records with link ID and vector clock map.
  /// Uses lightweight JSON extraction to avoid full deserialization.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamEntryLinksWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      final batch =
          await (select(linkedEntries)..limit(batchSize, offset: offset))
              .map(
                (row) => (
                  id: row.id,
                  vectorClock: _extractEntryLinkVectorClock(row.serialized),
                ),
              )
              .get();

      if (batch.isEmpty) break;

      yield batch;
      offset += batchSize;
    }
  }

  /// Count total entries for progress reporting (includes deleted).
  Future<int> countAllJournalEntries() async {
    final count = journal.id.count();
    final query = selectOnly(journal)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Count total entry links for progress reporting.
  Future<int> countAllEntryLinks() async {
    final count = linkedEntries.id.count();
    final query = selectOnly(linkedEntries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Lightweight extraction of vector clock from serialized JSON.
  /// Avoids full deserialization of the entity.
  static Map<String, int>? _extractVectorClock(String serialized) {
    try {
      final json = jsonDecode(serialized) as Map<String, dynamic>;
      final meta = json['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;

      final vc = meta['vectorClock'] as Map<String, dynamic>?;
      if (vc == null) return null;

      return vc.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return null;
    }
  }

  /// Lightweight extraction of vector clock from serialized EntryLink JSON.
  static Map<String, int>? _extractEntryLinkVectorClock(String serialized) {
    try {
      final json = jsonDecode(serialized) as Map<String, dynamic>;
      final vc = json['vectorClock'] as Map<String, dynamic>?;
      if (vc == null) return null;

      // Validate all values are numeric before converting
      for (final v in vc.values) {
        if (v is! num) return null;
      }
      return vc.map((k, v) => MapEntry(k, (v as num).toInt()));
    } on FormatException catch (_) {
      // Invalid JSON format
      return null;
    }
  }

  Selectable<JournalDbEntity> _selectJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    required List<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  }) {
    final matchesAllStarredStates =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    final matchesAllFlagStates =
        flaggedStatuses.length == 2 &&
        flaggedStatuses.contains(0) &&
        flaggedStatuses.contains(1);
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);

    if (ids != null) {
      return filteredJournalByIds(
        types,
        ids,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
    } else if (categoryIds != null) {
      if (matchesAllStarredStates && matchesAllFlagStates) {
        return matchesAllPrivateStates
            ? filteredJournalByCategoriesFastAllPrivate(
                types,
                categoryIds,
                limit,
                offset,
              )
            : filteredJournalByCategoriesFast(
                types,
                privateStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      return filteredJournalByCategories(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        categoryIds,
        limit,
        offset,
      );
    } else if (matchesAllStarredStates && matchesAllFlagStates) {
      return matchesAllPrivateStates
          ? filteredJournalFastAllPrivate(
              types,
              limit,
              offset,
            )
          : filteredJournalFast(
              types,
              privateStatuses,
              limit,
              offset,
            );
    } else {
      return filteredJournal(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
    }
  }

  Future<List<JournalEntity>> getTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    bool sortByDate = false,
    int limit = 500,
    int offset = 0,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await _selectTasks(
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      priorities: priorities,
      ids: ids,
      sortByDate: sortByDate,
      limit: limit,
      offset: offset,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  /// Like [getTasks] but orders by due date (soonest first, nulls last)
  /// using the expression index on `json_extract(serialized, '$.data.due')`.
  ///
  /// Uses raw SQL because Drift doesn't support `INDEXED BY` or
  /// `json_extract` ORDER BY in generated queries.
  Future<List<JournalEntity>> getTasksSortedByDueDate({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await _buildTasksByDueDateQuery(
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      priorities: priorities,
      ids: ids,
      limit: limit,
      offset: offset,
    );
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalDbEntity>> _buildTasksByDueDateQuery({
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    if (taskStatuses.isEmpty ||
        categoryIds.isEmpty ||
        (ids != null && ids.isEmpty)) {
      return Future.value([]);
    }

    final variables = <Variable<Object>>[];
    final buf = StringBuffer()
      ..write(
        'SELECT * FROM journal '
        'INDEXED BY idx_journal_tasks_due_active ',
      )
      ..write("WHERE type = 'Task' AND task = 1 AND deleted = 0 ")
      // Task statuses
      ..write('AND task_status IN (');
    for (var i = 0; i < taskStatuses.length; i++) {
      if (i > 0) buf.write(', ');
      variables.add(Variable<String>(taskStatuses[i]));
      buf.write('?${variables.length}');
    }
    buf
      ..write(') ')
      // Categories
      ..write('AND category IN (');
    for (var i = 0; i < categoryIds.length; i++) {
      if (i > 0) buf.write(', ');
      variables.add(Variable<String>(categoryIds[i]));
      buf.write('?${variables.length}');
    }
    buf.write(') ');

    // Starred
    final matchesAllStarred =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    if (!matchesAllStarred) {
      buf.write('AND starred IN (');
      for (var i = 0; i < starredStatuses.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<bool>(starredStatuses[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Private
    final matchesAllPrivate = _matchesAllPrivateStates(privateStatuses);
    if (!matchesAllPrivate) {
      buf.write('AND private IN (');
      for (var i = 0; i < privateStatuses.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<bool>(privateStatuses[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // FTS ids filter
    if (ids != null && ids.isNotEmpty) {
      buf.write('AND id IN (');
      for (var i = 0; i < ids.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<String>(ids[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Labels (via the labeled join table, matching _selectTasks semantics)
    final selectedLabelIds = labelIds ?? <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds = selectedLabelIds
        .where((id) => id.isNotEmpty)
        .toList();
    if (includeUnlabeled || filteredLabelIds.isNotEmpty) {
      final conditions = <String>[];
      if (includeUnlabeled) {
        conditions.add(
          'NOT EXISTS (SELECT 1 FROM labeled '
          'WHERE journal_id = journal.id)',
        );
      }
      if (filteredLabelIds.isNotEmpty) {
        final placeholders = <String>[];
        for (final id in filteredLabelIds) {
          variables.add(Variable<String>(id));
          placeholders.add('?${variables.length}');
        }
        conditions.add(
          'EXISTS (SELECT 1 FROM labeled '
          'WHERE journal_id = journal.id '
          'AND label_id IN (${placeholders.join(", ")}))',
        );
      }
      buf.write('AND (${conditions.join(" OR ")}) ');
    }

    // Priorities
    if (priorities != null && priorities.isNotEmpty) {
      buf.write('AND task_priority IN (');
      for (var i = 0; i < priorities.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<String>(priorities[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Order: due date ASC (nulls last), then date_from DESC as tiebreaker
    buf
      ..write(
        r"ORDER BY CASE WHEN json_extract(serialized, '$.data.due') "
        'IS NULL THEN 1 ELSE 0 END, '
        r"json_extract(serialized, '$.data.due') ASC, "
        'date_from DESC ',
      )
      ..write('LIMIT ')
      ..write(limit)
      ..write(' OFFSET ')
      ..write(offset);

    return customSelect(
      buf.toString(),
      variables: variables,
      readsFrom: {journal, labeled},
    ).asyncMap(journal.mapFromRow).get();
  }

  Selectable<JournalDbEntity> _selectTasks({
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    bool sortByDate = false,
    int limit = 500,
    int offset = 0,
  }) {
    if (taskStatuses.isEmpty || categoryIds.isEmpty) {
      return emptyJournalSelection();
    }

    final matchesAllStarredStates =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);
    final selectedLabelIds = labelIds ?? <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds = selectedLabelIds
        .where((id) => id.isNotEmpty)
        .toList();
    final labelFilterCount = filteredLabelIds.length;
    final filterByLabels = includeUnlabeled || labelFilterCount > 0;
    final dbTaskStatuses = taskStatuses.cast<String?>();
    final selectedPriorities = priorities ?? <String>[];
    final filterByPriorities = selectedPriorities.isNotEmpty;
    final dbSelectedPriorities = selectedPriorities.cast<String?>();

    if (ids == null && matchesAllPrivateStates && matchesAllStarredStates) {
      if (!filterByLabels) {
        if (sortByDate) {
          return filterByPriorities
              ? filteredTasksByDateFastAllPrivateAllStarredWithPriorities(
                  dbTaskStatuses,
                  categoryIds,
                  dbSelectedPriorities,
                  limit,
                  offset,
                )
              : filteredTasksByDateFastAllPrivateAllStarred(
                  dbTaskStatuses,
                  categoryIds,
                  limit,
                  offset,
                );
        }

        return filterByPriorities
            ? filteredTasksFastAllPrivateAllStarredWithPriorities(
                dbTaskStatuses,
                categoryIds,
                dbSelectedPriorities,
                limit,
                offset,
              )
            : filteredTasksFastAllPrivateAllStarred(
                dbTaskStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      final effectiveLabelIds = labelFilterCount == 0
          ? <String>['__no_label__']
          : filteredLabelIds;
      final effectivePriorities = filterByPriorities
          ? selectedPriorities
          : <String>['__no_priority__'];
      final dbPriorities = effectivePriorities.cast<String?>();

      return sortByDate
          ? filteredTasksByDateAllPrivateAllStarred(
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasksAllPrivateAllStarred(
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    }

    if (ids == null && !filterByLabels) {
      if (sortByDate) {
        return filterByPriorities
            ? filteredTasksByDateFastWithPriorities(
                privateStatuses,
                starredStatuses,
                dbTaskStatuses,
                categoryIds,
                dbSelectedPriorities,
                limit,
                offset,
              )
            : filteredTasksByDateFast(
                privateStatuses,
                starredStatuses,
                dbTaskStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      return filterByPriorities
          ? filteredTasksFastWithPriorities(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              dbSelectedPriorities,
              limit,
              offset,
            )
          : filteredTasksFast(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              limit,
              offset,
            );
    }

    // Avoid passing an empty list to the SQL `IN (:labelIds)` clause.
    // SQLite (and SQL generally) does not allow an empty `IN ()`, so we
    // substitute a dummy value when no label IDs are selected. The query
    // never matches this magic string; it only keeps the SQL valid.
    final effectiveLabelIds = labelFilterCount == 0
        ? <String>['__no_label__']
        : filteredLabelIds;
    // Keep the generated SQL valid when no priorities are selected. Drift
    // still expands list parameters even when the CASE guard disables the
    // priority branch, so passing an empty list would yield `IN ()`.
    final effectivePriorities = filterByPriorities
        ? selectedPriorities
        : <String>['__no_priority__'];
    final dbPriorities = effectivePriorities.cast<String?>();

    if (ids != null) {
      // Use date-sorted or priority-sorted query based on sortByDate flag
      return sortByDate
          ? filteredTasksByDate2(
              ids,
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasks2(
              ids,
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    } else {
      // Use date-sorted or priority-sorted query based on sortByDate flag
      return sortByDate
          ? filteredTasksByDate(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasks(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    }
  }

  Future<int> getWipCount() async {
    final privateStatuses = await _visiblePrivateStatuses();
    return countInProgressTasks(
      privateStatuses,
      ['IN PROGRESS'],
    ).getSingle();
  }

  Future<Map<String, int>> getTaskCountsByCategory() async {
    final rows = await countTasksGroupedByCategory().get();
    return {for (final row in rows) row.category: row.taskCount};
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final dbEntities = await _queryWithPrivateFilter(
      allPrivate: () => linkedJournalEntitiesAllPrivate(linkedFrom).get(),
      filtered: (s) => linkedJournalEntities(linkedFrom, s).get(),
    );
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalDbEntity>> getLinkedToEntities(String linkedTo) {
    return _queryWithPrivateFilter(
      allPrivate: () => linkedToJournalEntities(linkedTo).get(),
      filtered: (s) =>
          linkedToJournalEntitiesByPrivateStatuses(linkedTo, s).get(),
    );
  }

  /// Get linked entities for multiple parent IDs in bulk to avoid N+1 queries
  Future<Map<String, List<JournalEntity>>> getBulkLinkedEntities(
    Set<String> fromIds,
  ) async {
    // Early return for empty set
    if (fromIds.isEmpty) {
      return <String, List<JournalEntity>>{};
    }

    // Get all links FROM the parent IDs (matching getLinkedEntities behavior)
    final linkEntries = await linksFromIds(fromIds.toList()).get();
    final links = linkEntries.map(entryLinkFromLinkedDbEntry).toList();

    // Collect all target IDs
    final targetIds = links.map((link) => link.toId).toSet();

    // Fetch all linked entities in one query
    final entities = await getJournalEntitiesForIdsUnordered(targetIds);

    // Group by parent ID with deduplication tracking
    final result = <String, List<JournalEntity>>{
      for (final id in fromIds) id: [],
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: {},
    };

    // Create entity lookup map for O(1) access
    final entityMap = <String, JournalEntity>{};
    for (final entity in entities) {
      entityMap[entity.meta.id] = entity;
    }

    // Map entities to their parent IDs using O(1) lookup with deduplication
    for (final link in links) {
      final entity = entityMap[link.toId];
      if (entity != null) {
        // Only add if not already seen for this parent
        if (seenEntities[link.fromId]!.add(entity.meta.id)) {
          result[link.fromId]?.add(entity);
        }
      }
    }

    // Sort each result list by dateFrom descending to match single-parent semantics
    for (final entry in result.entries) {
      entry.value.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    }

    return result;
  }

  Future<Map<String, List<LinkedEntityTimeSpan>>> getBulkLinkedTimeSpans(
    Set<String> fromIds,
  ) async {
    if (fromIds.isEmpty) {
      return <String, List<LinkedEntityTimeSpan>>{};
    }

    final fromIdList = fromIds.toList(growable: false);
    final fromPlaceholders = List.filled(fromIdList.length, '?').join(', ');
    final privateStatuses = await _visiblePrivateStatuses();
    final filterPrivate = !_matchesAllPrivateStates(privateStatuses);
    final privateClause = filterPrivate
        ? 'AND journal.private IN (${List.filled(privateStatuses.length, '?').join(', ')})'
        : '';

    final rows = await customSelect(
      '''
      SELECT
        linked_entries.from_id AS parent_id,
        journal.id AS entity_id,
        journal.date_from AS date_from,
        journal.date_to AS date_to
      FROM linked_entries
      INNER JOIN journal ON journal.id = linked_entries.to_id
      WHERE linked_entries.from_id IN ($fromPlaceholders)
        AND linked_entries.hidden = FALSE
        AND journal.deleted = FALSE
        AND journal.type NOT IN ('Task', 'AiResponse', 'JournalAudio')
        $privateClause
      ''',
      variables: [
        for (final fromId in fromIdList) Variable<String>(fromId),
        if (filterPrivate)
          for (final privateStatus in privateStatuses)
            Variable<bool>(privateStatus),
      ],
      readsFrom: {linkedEntries, journal},
    ).get();

    final result = <String, List<LinkedEntityTimeSpan>>{
      for (final id in fromIds) id: <LinkedEntityTimeSpan>[],
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: <String>{},
    };

    for (final row in rows) {
      final parentId = row.read<String>('parent_id');
      final entityId = row.read<String>('entity_id');
      final seenForParent = seenEntities[parentId];
      if (seenForParent == null || !seenForParent.add(entityId)) {
        continue;
      }

      result[parentId]!.add((
        id: entityId,
        dateFrom: row.read<DateTime>('date_from'),
        dateTo: row.read<DateTime>('date_to'),
      ));
    }

    return result;
  }

  Future<List<JournalEntity>> sortedCalendarEntries({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final dbEntities = await sortedCalenderEntriesInRange(
      rangeStart,
      rangeEnd,
    ).get();
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<int> getLabeledCount() async {
    return (await countLabeled().get()).first;
  }

  Future<int> getJournalCount() async {
    return (await countJournalEntries().get()).first;
  }

  Stream<Set<ConfigFlag>> watchConfigFlags() {
    return Stream<Set<ConfigFlag>>.multi((controller) {
      StreamSubscription<Set<ConfigFlag>>? subscription;
      Set<ConfigFlag>? lastEmitted;

      void emit(Set<ConfigFlag> flags) {
        final previousFlags = lastEmitted;
        if (previousFlags != null &&
            const SetEquality<ConfigFlag>().equals(previousFlags, flags)) {
          return;
        }

        lastEmitted = flags;
        controller.add(flags);
      }

      subscription = _configFlagsController.stream.listen(
        emit,
        onError: controller.addError,
        onDone: controller.close,
      );

      if (_configFlagsLoaded) {
        emit(_currentConfigFlags());
      } else {
        Future<void>(() async {
          await _ensureConfigFlagsLoaded();
          emit(_currentConfigFlags());
        });
      }

      controller.onCancel = () => subscription?.cancel();
    }, isBroadcast: true);
  }

  Stream<Set<String>> watchActiveConfigFlagNames() {
    return watchConfigFlags().map((configFlags) {
      final activeFlags = <String>{};
      for (final flag in configFlags) {
        if (flag.status) {
          activeFlags.add(flag.name);
        }
      }
      return activeFlags;
    });
  }

  bool findConfigFlag(String flagName, List<ConfigFlag> flags) {
    var flag = false;

    for (final configFlag in flags) {
      if (configFlag.name == flagName) {
        flag = configFlag.status;
      }
    }

    return flag;
  }

  Future<void> purgeDeletedFiles() async {
    final deletedEntries = await (select(
      journal,
    )..where((tbl) => tbl.deleted.equals(true))).get();

    for (final entry in deletedEntries) {
      try {
        final journalEntity = JournalEntity.fromJson(
          jsonDecode(entry.serialized) as Map<String, dynamic>,
        );

        await journalEntity.maybeMap(
          journalImage: (JournalImage image) async {
            final fullPath = getFullImagePath(image);
            final jsonPath = '$fullPath.json';
            await File(fullPath).delete();
            await File(jsonPath).delete();
          },
          journalAudio: (JournalAudio audio) async {
            final fullPath = await AudioUtils.getFullAudioPath(audio);
            final jsonPath = '$fullPath.json';
            await File(fullPath).delete();
            await File(jsonPath).delete();
          },
          orElse: () async {
            // For all other entry types, just delete the JSON file
            final docDir = getDocumentsDirectory();
            final jsonPath = entityPath(journalEntity, docDir);
            await File(jsonPath).delete();
          },
        );
      } catch (e) {
        // Log error but continue with other files
        getIt<LoggingService>().captureException(
          e,
          domain: 'Database',
          subDomain: 'purgeDeletedFiles',
        );
      }
    }
  }

  Stream<double> purgeDeleted({
    bool backup = true,
    Duration stepDelay = const Duration(milliseconds: 50),
  }) async* {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    // First delete the actual files
    await purgeDeletedFiles();

    // Get counts for each type
    final dashboardCount =
        await (select(dashboardDefinitions)
              ..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final measurableCount =
        await (select(measurableTypes)
              ..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final journalCount =
        await (select(journal)..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final totalItems = dashboardCount + measurableCount + journalCount;

    if (totalItems == 0) {
      yield 1.0; // Already empty
      return;
    }

    // Purge dashboards
    if (dashboardCount > 0) {
      await (delete(
        dashboardDefinitions,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.33; // 33% complete after dashboards
    await Future<void>.delayed(stepDelay);

    // Purge measurables
    if (measurableCount > 0) {
      await (delete(
        measurableTypes,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.66; // 66% complete after measurables
    await Future<void>.delayed(stepDelay);

    // Purge journal entries
    if (journalCount > 0) {
      await (delete(journal)..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 1.0; // 100% complete after journal entries
  }

  Future<bool> getConfigFlag(String flagName) async {
    await _ensureConfigFlagsLoaded();
    return _configFlagsByName[flagName]?.status ?? false;
  }

  Stream<bool> watchConfigFlag(String flagName) {
    return watchConfigFlags()
        .map(
          (_) => _configFlagsByName[flagName]?.status ?? false,
        )
        .distinct();
  }

  Future<ConfigFlag?> getConfigFlagByName(String flagName) async {
    await _ensureConfigFlagsLoaded();
    return _configFlagsByName[flagName];
  }

  Future<void> insertFlagIfNotExists(ConfigFlag configFlag) async {
    await _ensureConfigFlagsLoaded();
    final existing = _configFlagsByName[configFlag.name];

    if (existing == null) {
      await into(configFlags).insert(configFlag);
      _setConfigFlag(configFlag);
    }
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    await _ensureConfigFlagsLoaded();
    final result = await into(configFlags).insertOnConflictUpdate(configFlag);
    _setConfigFlag(configFlag);
    return result;
  }

  Future<void> toggleConfigFlag(String flagName) async {
    final configFlag = await getConfigFlagByName(flagName);

    if (configFlag != null) {
      await upsertConfigFlag(configFlag.copyWith(status: !configFlag.status));
    }
  }

  Future<List<bool>> _visiblePrivateStatuses() async {
    final showPrivateEntries = await getConfigFlag('private');
    return showPrivateEntries ? const [false, true] : const [false];
  }

  bool _matchesAllPrivateStates(List<bool> privateStatuses) =>
      privateStatuses.length == 2 &&
      privateStatuses.contains(true) &&
      privateStatuses.contains(false);

  /// Resolves private-visibility config and dispatches to either the
  /// [allPrivate] query (when all private states are visible) or the
  /// [filtered] query (passing the allowed statuses).
  Future<T> _queryWithPrivateFilter<T>({
    required Future<T> Function() allPrivate,
    required Future<T> Function(List<bool> statuses) filtered,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    return _matchesAllPrivateStates(privateStatuses)
        ? allPrivate()
        : filtered(privateStatuses);
  }

  Future<void> _ensureConfigFlagsLoaded() {
    final existingBootstrap = _configFlagsBootstrap;
    if (existingBootstrap != null) {
      return existingBootstrap;
    }

    late final Future<void> future;
    future = listConfigFlags()
        .get()
        .then((flags) {
          _configFlagsLoaded = true;
          _replaceConfigFlags(flags);
        })
        .whenComplete(() {
          if (identical(_configFlagsBootstrap, future)) {
            if (_configFlagsLoaded) {
              _configFlagsBootstrap = Future<void>.value();
            } else {
              _configFlagsBootstrap = null;
            }
          }
        });

    _configFlagsBootstrap = future;
    return future;
  }

  Set<ConfigFlag> _currentConfigFlags() => _configFlagsByName.values.toSet();

  void _replaceConfigFlags(Iterable<ConfigFlag> flags) {
    final next = <String, ConfigFlag>{
      for (final flag in flags) flag.name: flag,
    };

    if (const MapEquality<String, ConfigFlag>().equals(
      _configFlagsByName,
      next,
    )) {
      return;
    }

    _configFlagsByName
      ..clear()
      ..addAll(next);
    _emitConfigFlags();
  }

  void _setConfigFlag(ConfigFlag configFlag) {
    _configFlagsLoaded = true;
    final existing = _configFlagsByName[configFlag.name];
    if (existing == configFlag) {
      return;
    }

    _configFlagsByName[configFlag.name] = configFlag;
    _emitConfigFlags();
  }

  void _emitConfigFlags() {
    if (!_configFlagsController.isClosed) {
      _configFlagsController.add(_currentConfigFlags());
    }
  }

  @override
  Future<void> close() async {
    await _configFlagsController.close();
    await super.close();
  }

  Future<int> getCountImportFlagEntries() async {
    final res = await countImportFlagEntries().get();
    return res.first;
  }

  Future<int> getTasksCount({
    List<String> statuses = const ['IN PROGRESS'],
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await countInProgressTasks(
      privateStatuses,
      statuses.cast<String?>(),
    ).get();
    return res.first;
  }

  Future<MeasurableDataType?> getMeasurableDataTypeById(String id) async {
    final res = await measurableTypeById(id).get();
    return res.map(measurableDataType).firstOrNull;
  }

  Future<List<MeasurableDataType>> getAllMeasurableDataTypes() async {
    return measurableDataTypeStreamMapper(
      await activeMeasurableTypes().get(),
    );
  }

  Future<List<JournalEntity>> getMeasurementsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await measurementsByType(type, rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getHabitCompletionsByHabitId({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await habitCompletionsByHabitId(
      habitId,
      rangeStart,
      rangeEnd,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getHabitCompletionsInRange({
    required DateTime rangeStart,
  }) async {
    final res = await habitCompletionsInRange(rangeStart).get();
    return res.map(fromDbEntity).toList();
  }

  Future<DayPlanEntry?> getDayPlanById(String id) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => dayPlanById(id).get(),
      filtered: (s) => dayPlanByIdByPrivateStatuses(id, s).get(),
    );
    if (res.isEmpty) return null;
    return fromDbEntity(res.first) as DayPlanEntry;
  }

  /// Batch variant of [getDayPlanById]. Used by the coalescing layer in
  /// the day-plan repository so a prefetch window of N dates collapses
  /// into a single round-trip. Chunks inputs to stay under SQLite's
  /// default 999-variable limit even if a caller fans out far past the
  /// DailyOS prefetch window. Duplicate ids are removed before chunking
  /// so the `IN (…)` semantics of the original single-query form are
  /// preserved — otherwise dupes in different chunks would yield dupe
  /// rows.
  Future<List<DayPlanEntry>> getDayPlansByIds(Iterable<String> ids) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) return const [];
    final out = <DayPlanEntry>[];
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      final res = await _queryWithPrivateFilter(
        allPrivate: () => dayPlansByIds(chunk).get(),
        filtered: (s) => dayPlansByIdsByPrivateStatuses(chunk, s).get(),
      );
      out.addAll(res.map((e) => fromDbEntity(e) as DayPlanEntry));
    }
    return out;
  }

  Future<List<DayPlanEntry>> getDayPlansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => dayPlansInRange(rangeStart, rangeEnd).get(),
      filtered: (s) =>
          dayPlansInRangeByPrivateStatuses(rangeStart, rangeEnd, s).get(),
    );
    return res.map((e) => fromDbEntity(e) as DayPlanEntry).toList();
  }

  // ── Project queries ──────────────────────────────────────────────────────

  /// Returns all non-deleted projects for a category.
  Future<List<ProjectEntry>> getProjectsForCategory(
    String categoryId,
  ) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => projectsForCategory(categoryId).get(),
      filtered: (s) =>
          projectsForCategoryByPrivateStatuses(categoryId, s).get(),
    );
    return res.map(fromDbEntity).whereType<ProjectEntry>().toList();
  }

  /// Returns all non-deleted tasks linked to a project via ProjectLink.
  Future<List<Task>> getTasksForProject(String projectId) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => tasksForProject(projectId).get(),
      filtered: (s) => tasksForProjectByPrivateStatuses(projectId, s).get(),
    );
    return res.map(fromDbEntity).whereType<Task>().toList();
  }

  /// Returns the project linked to a task, or null if unlinked.
  Future<ProjectEntry?> getProjectForTask(String taskId) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await projectForTask(taskId).get();
    if (res.isEmpty) return null;
    final entity = fromDbEntity(res.first);
    if (entity is! ProjectEntry) return null;
    if (!privateStatuses.contains(entity.meta.private ?? false)) return null;
    return entity;
  }

  /// Returns the existing ProjectLink for a task, or null.
  Future<EntryLink?> getProjectLinkForTask(String taskId) async {
    final res = await projectLinkForTask(taskId).get();
    if (res.isEmpty) return null;
    return entryLinkFromLinkedDbEntry(res.first);
  }

  /// Returns tasks that are due on or before the specified date.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// This includes both tasks due on the specified day and overdue tasks.
  Future<List<Task>> getTasksDueOnOrBefore(DateTime date) async {
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final privateStatuses = await _visiblePrivateStatuses();
    final superset = await _coalesceOpenTasksDueUpTo(endOfDay, privateStatuses);
    return _filterTasks(
      superset,
      endInclusive: endOfDay,
    );
  }

  /// Returns tasks that are due on the specified date only.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// Does NOT include overdue tasks from previous days.
  Future<List<Task>> getTasksDueOn(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final privateStatuses = await _visiblePrivateStatuses();
    final superset = await _coalesceOpenTasksDueUpTo(endOfDay, privateStatuses);
    return _filterTasks(
      superset,
      startInclusive: startOfDay,
      endInclusive: endOfDay,
    );
  }

  // Microtask-coalescing state for `_coalesceOpenTasksDueUpTo`.
  //
  // The DailyOS prefetch window fires `getTasksDueOn` / `getTasksDueOnOrBefore`
  // once per date in a synchronous sweep. Instead of N round-trips through
  // `_selectTasksDue`, we share the widest `due <= max(endOfDay)` superset
  // across the whole wave and let each caller filter its own range
  // client-side from the in-memory list.
  //
  // The coalescer is keyed by the private-status shape so that private-filter
  // changes mid-wave (very rare but theoretically possible) still produce a
  // correct batch per shape.
  final Map<String, _PendingDueWave> _pendingDueWaves = {};

  /// Single-shot query executed by the tasks-due coalescer. Extracted as a
  /// protected seam so tests can count round-trips and inject failures
  /// without depending on a query interceptor.
  @protected
  @visibleForTesting
  Future<List<Task>> runTasksDueFetch({
    required DateTime endInclusive,
    required List<bool> privateStatuses,
  }) async {
    final rows = await _selectTasksDue(
      endIso: endInclusive.toIso8601String(),
      privateStatuses: privateStatuses,
    );
    return rows.map(fromDbEntity).whereType<Task>().toList(growable: false);
  }

  Future<List<Task>> _coalesceOpenTasksDueUpTo(
    DateTime endInclusive,
    List<bool> privateStatuses,
  ) {
    final key = privateStatuses.join(',');
    final existing = _pendingDueWaves[key];
    if (existing != null) {
      // Extend the existing wave's upper bound so the superset covers the
      // latest caller as well. Filtering happens per caller, so a slightly
      // wider range is free.
      if (endInclusive.isAfter(existing.endInclusive)) {
        existing.endInclusive = endInclusive;
      }
      return existing.completer.future;
    }

    final wave = _PendingDueWave(
      endInclusive: endInclusive,
      privateStatuses: List<bool>.unmodifiable(privateStatuses),
    );
    _pendingDueWaves[key] = wave;
    scheduleMicrotask(() async {
      _pendingDueWaves.remove(key);
      try {
        final tasks = await runTasksDueFetch(
          endInclusive: wave.endInclusive,
          privateStatuses: wave.privateStatuses,
        );
        wave.completer.complete(tasks);
      } catch (error, stack) {
        wave.completer.completeError(error, stack);
      }
    });
    return wave.completer.future;
  }

  static List<Task> _filterTasks(
    List<Task> superset, {
    required DateTime endInclusive,
    DateTime? startInclusive,
  }) {
    return [
      for (final task in superset)
        if (task.data.due != null &&
            !task.data.due!.isAfter(endInclusive) &&
            (startInclusive == null ||
                !task.data.due!.isBefore(startInclusive)))
          task,
    ];
  }

  // Drift SQL doesn't support `INDEXED BY`, so keep the due-date hot path in
  // raw SQL to force the dedicated expression index on large journal tables.
  // Uses the partial `idx_journal_tasks_due_open` so the ORDER BY streams
  // from the index without an external sort. The WHERE clause must match
  // the partial's predicates verbatim for SQLite to resolve INDEXED BY.
  Future<List<JournalDbEntity>> _selectTasksDue({
    required String endIso,
    required List<bool> privateStatuses,
    String? startIso,
  }) {
    final variables = <Variable<Object>>[];
    final buffer = StringBuffer()
      ..write('SELECT * FROM journal INDEXED BY idx_journal_tasks_due_open ')
      ..write("WHERE type = 'Task' ")
      ..write('AND task = 1 ')
      ..write('AND deleted = FALSE ')
      ..write("AND task_status NOT IN ('DONE', 'REJECTED') ")
      ..write(r"AND json_extract(serialized, '$.data.due') IS NOT NULL ");

    if (startIso != null) {
      variables.add(Variable<String>(startIso));
      buffer.write(
        r"AND json_extract(serialized, '$.data.due') >= "
        '?${variables.length} ',
      );
    }

    variables.add(Variable<String>(endIso));
    buffer
      ..write(
        r"AND json_extract(serialized, '$.data.due') <= "
        '?${variables.length} ',
      )
      ..write('AND private IN (');

    for (var i = 0; i < privateStatuses.length; i++) {
      if (i > 0) {
        buffer.write(', ');
      }
      variables.add(Variable<bool>(privateStatuses[i]));
      buffer.write('?${variables.length}');
    }

    buffer
      ..write(') ')
      ..write(r"ORDER BY json_extract(serialized, '$.data.due') ASC");

    return customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {journal},
    ).asyncMap(journal.mapFromRow).get();
  }

  /// Find existing rating entity for a target entry and catalog
  /// (for edit/re-open).
  Future<RatingEntry?> getRatingForTimeEntry(
    String targetId, {
    String catalogId = 'session',
  }) async {
    final res = await ratingForTimeEntry(targetId, catalogId).get();
    if (res.isEmpty) return null;
    final entity = fromDbEntity(res.first);
    return entity is RatingEntry ? entity : null;
  }

  /// Fetch all ratings linked to a target entity (across all catalogs).
  Future<List<RatingEntry>> getAllRatingsForTarget(String targetId) async {
    final res = await allRatingsForTarget(targetId).get();
    return res.map(fromDbEntity).whereType<RatingEntry>().toList();
  }

  /// Bulk fetch rating IDs for a set of time entries.
  ///
  /// The query orders by `updated_at ASC` so that when multiple ratings
  /// link to the same time entry, the most recently updated one wins
  /// (last-write-wins in the map comprehension).
  ///
  /// Concurrent callers within the same microtask (the DailyOS prefetch
  /// window fires `_fetchAllData` per date) share a single round-trip: the
  /// wave merges every caller's id set, issues one `ratingsForTimeEntries`
  /// query, and hands each caller a map restricted to its own ids.
  ///
  /// Per-row ordering (`j.updated_at ASC`) is preserved across the wave so
  /// last-write-wins remains stable within each caller's subset. The
  /// caller's set is snapshotted before scheduling so the post-query filter
  /// never reads a mutated view if the caller reuses or clears the set
  /// before the coalesced wave fires.
  Future<Map<String, String>> getRatingIdsForTimeEntries(
    Set<String> timeEntryIds,
  ) {
    final snapshot = Set<String>.unmodifiable(timeEntryIds);
    if (snapshot.isEmpty) return Future.value(const <String, String>{});
    return _coalesceRatings(snapshot);
  }

  _PendingRatingsWave? _pendingRatingsWave;

  /// Single-shot query executed by the ratings coalescer. Extracted as a
  /// protected seam so tests can count DB round-trips without depending on
  /// a query interceptor. The merged wave set can grow past SQLite's
  /// 999-variable limit when many prefetched dates converge in one
  /// microtask; chunk through [_sqliteInListChunk] with a stable
  /// `updated_at ASC` order preserved across chunks so last-write-wins
  /// holds at the map-comprehension step.
  @protected
  @visibleForTesting
  Future<List<RatingsForTimeEntriesResult>> runRatingsForTimeEntriesQueryForIds(
    Set<String> ids,
  ) async {
    final idList = ids.toList(growable: false);
    if (idList.length <= _sqliteInListChunk) {
      return ratingsForTimeEntries(idList).get();
    }
    final combined = <RatingsForTimeEntriesResult>[];
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      combined.addAll(await ratingsForTimeEntries(chunk).get());
    }
    return combined;
  }

  Future<Map<String, String>> _coalesceRatings(Set<String> ids) {
    final wave = _pendingRatingsWave ??= _PendingRatingsWave();
    wave.mergedIds.addAll(ids);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingRatingsWave = null;
        try {
          final rows = await runRatingsForTimeEntriesQueryForIds(
            wave.mergedIds,
          );
          wave.completer.complete(rows);
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then(
      (rows) => {
        for (final row in rows)
          if (ids.contains(row.timeEntryId)) row.timeEntryId: row.ratingId,
      },
    );
  }

  Future<List<JournalEntity>> getQuantitativeByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await quantitativeByType(type, rangeStart, rangeEnd).get();

    return res.map(fromDbEntity).toList();
  }

  Future<QuantitativeEntry?> latestQuantitativeByType(String type) async {
    final dbEntities = await latestQuantByType(type).get();
    if (dbEntities.isEmpty) {
      DevLogger.log(
        name: 'JournalDb',
        message: 'latestQuantitativeByType no result for $type',
      );
      return null;
    }
    return fromDbEntity(dbEntities.first) as QuantitativeEntry;
  }

  Future<WorkoutEntry?> latestWorkout() async {
    final dbEntities = await findLatestWorkout().get();
    if (dbEntities.isEmpty) {
      DevLogger.log(name: 'JournalDb', message: 'no workout found');
      return null;
    }
    return fromDbEntity(dbEntities.first) as WorkoutEntry;
  }

  Future<List<JournalEntity>> getSurveyCompletionsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await surveysByType(type, rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getWorkouts({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final res = await workouts(rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit).watch();
  }

  Stream<List<Conflict>> watchConflictById(String id) {
    return conflictsById(id).watch();
  }

  /// Snapshot version of label usage statistics for prompt construction or one-off queries
  Future<Map<String, int>> getLabelUsageCounts() async {
    final query = customSelect(
      '''
      SELECT label_id, COUNT(*) AS usage_count
      FROM labeled
      GROUP BY label_id
      ''',
      readsFrom: {labeled},
    );

    final rows = await query.get();
    final usage = <String, int>{};
    for (final row in rows) {
      usage[row.read<String>('label_id')] = row.read<int>('usage_count');
    }
    return usage;
  }

  /// Alias to snapshot method for clarity when used alongside the stream variant.
  Future<Map<String, int>> getLabelUsageCountsSnapshot() =>
      getLabelUsageCounts();

  Future<List<LabelDefinition>> getAllLabelDefinitions() async {
    final labels = await _queryWithPrivateFilter(
      allPrivate: () => allLabelDefinitions().get(),
      filtered: (s) => allLabelDefinitionsByPrivateStatuses(s).get(),
    );
    return labelDefinitionsStreamMapper(labels);
  }

  Future<LabelDefinition?> getLabelDefinitionById(String id) async {
    final result = await _queryWithPrivateFilter(
      allPrivate: () => labelDefinitionById(id).get(),
      filtered: (s) => labelDefinitionByIdByPrivateStatuses(id, s).get(),
    );
    return labelDefinitionsStreamMapper(result).firstOrNull;
  }

  Future<List<CategoryDefinition>> getAllCategories() async {
    return categoryDefinitionsStreamMapper(
      await allCategoryDefinitions().get(),
    );
  }

  Future<List<HabitDefinition>> getAllHabitDefinitions() async {
    return habitDefinitionsStreamMapper(
      await allHabitDefinitions().get(),
    );
  }

  Future<List<DashboardDefinition>> getAllDashboards() async {
    return dashboardStreamMapper(await allDashboards().get());
  }

  Future<CategoryDefinition?> getCategoryById(String id) async {
    final rows = await categoryById(id).get();
    return categoryDefinitionsStreamMapper(rows).firstOrNull;
  }

  Future<HabitDefinition?> getHabitById(String id) async {
    final rows = await habitById(id).get();
    return habitDefinitionsStreamMapper(rows).firstOrNull;
  }

  Future<DashboardDefinition?> getDashboardById(String id) async {
    final rows = await dashboardById(id).get();
    return dashboardStreamMapper(rows).firstOrNull;
  }

  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where((t) => t.id.equals(conflict.id))).write(
      conflict.copyWith(status: ConflictStatus.resolved.index),
    );
  }

  Future<int> upsertMeasurableDataType(
    MeasurableDataType entityDefinition,
  ) async {
    return into(
      measurableTypes,
    ).insertOnConflictUpdate(measurableDbEntity(entityDefinition));
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) async {
    return into(
      habitDefinitions,
    ).insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition));
  }

  Future<int> upsertDashboardDefinition(
    DashboardDefinition dashboardDefinition,
  ) async {
    return into(dashboardDefinitions).insertOnConflictUpdate(
      dashboardDefinitionDbEntity(dashboardDefinition),
    );
  }

  Future<int> upsertCategoryDefinition(
    CategoryDefinition categoryDefinition,
  ) async {
    return into(categoryDefinitions).insertOnConflictUpdate(
      categoryDefinitionDbEntity(categoryDefinition),
    );
  }

  Future<List<EntryLink>> linksForEntryIds(Set<String> ids) async {
    if (ids.isEmpty) return <EntryLink>[];
    final entryLinks = await linksForIds(ids.toList()).get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
  }

  /// Returns only [BasicLink] entries for the given [ids], filtering out
  /// RatingLinks at the SQL level using the `type` column.
  ///
  /// Concurrent callers within the same microtask (e.g. the DailyOS prefetch
  /// window firing `_fetchAllData` per date) share a single round-trip: the
  /// wave merges every caller's id set, issues one `to_id IN (…)` query, and
  /// hands each caller the subset matching its own ids.
  ///
  /// The caller's set is snapshotted before scheduling so the post-query
  /// filter never reads a mutated view if the caller reuses or clears the
  /// set before the coalesced wave fires.
  Future<List<EntryLink>> basicLinksForEntryIds(Set<String> ids) {
    final snapshot = Set<String>.unmodifiable(ids);
    if (snapshot.isEmpty) return Future.value(const <EntryLink>[]);
    return _coalesceBasicLinks(snapshot);
  }

  _PendingLinksWave? _pendingBasicLinksWave;

  /// Single-shot query executed by the basic-links coalescer. Extracted as a
  /// protected seam so tests can count DB round-trips without depending on
  /// a query interceptor.
  @protected
  @visibleForTesting
  Future<List<EntryLink>> runBasicLinksQueryForIds(Set<String> ids) async {
    final rows =
        await (select(linkedEntries)..where(
              (t) => t.toId.isIn(ids.toList()) & t.type.equals('BasicLink'),
            ))
            .get();
    return rows.map(entryLinkFromLinkedDbEntry).toList();
  }

  Future<List<EntryLink>> _coalesceBasicLinks(Set<String> ids) {
    final wave = _pendingBasicLinksWave ??= _PendingLinksWave();
    wave.mergedIds.addAll(ids);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingBasicLinksWave = null;
        try {
          final links = await runBasicLinksQueryForIds(wave.mergedIds);
          wave.completer.complete(links);
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then(
      (links) => [
        for (final link in links)
          if (ids.contains(link.toId)) link,
      ],
    );
  }

  Future<List<EntryLink>> linksForEntryIdsBidirectional(Set<String> ids) async {
    if (ids.isEmpty) return <EntryLink>[];
    final idList = ids.toList();
    final entryLinks =
        await (select(linkedEntries)..where(
              (t) => t.fromId.isIn(idList) | t.toId.isIn(idList),
            ))
            .get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
  }

  Future<EntryLink?> entryLinkById(String id) async {
    final res = await (select(
      linkedEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (res == null) return null;
    return entryLinkFromLinkedDbEntry(res);
  }

  Future<int> upsertEntryLink(EntryLink link) async {
    if (link.fromId != link.toId) {
      try {
        // Equality precheck: if an entry with the same id exists and the
        // serialized payload is identical, skip the UPSERT to avoid a no-op
        // UPDATE and downstream log noise.
        final existing = await (select(
          linkedEntries,
        )..where((t) => t.id.equals(link.id))).getSingleOrNull();
        if (existing != null) {
          final incomingSerialized = jsonEncode(link);
          if (existing.serialized == incomingSerialized) {
            return 0; // no change needed
          }
        }
      } catch (_) {
        // Best-effort precheck only; fall through to UPSERT on failure.
      }

      // Guard against secondary UNIQUE(from_id, to_id, type) constraint.
      // insertOnConflictUpdate only handles primary key conflicts, so a
      // duplicate (from_id, to_id, type) with a different id would throw.
      final dbLink = linkedDbEntity(link);
      final existingByTriple =
          await (select(linkedEntries)..where(
                (t) =>
                    t.fromId.equals(dbLink.fromId) &
                    t.toId.equals(dbLink.toId) &
                    t.type.equals(dbLink.type),
              ))
              .getSingleOrNull();
      if (existingByTriple != null && existingByTriple.id != dbLink.id) {
        if (existingByTriple.hidden != true) {
          return 0; // genuine active duplicate — block it
        }
        // The existing row is a soft-deleted tombstone. Hard-delete it so the
        // UNIQUE(from_id, to_id, type) constraint doesn't block the new insert.
        await (delete(
          linkedEntries,
        )..where((t) => t.id.equals(existingByTriple.id))).go();
      }

      final res = await into(linkedEntries).insertOnConflictUpdate(dbLink);

      // Keep the denormalized project_id column in sync whenever a
      // ProjectLink is created or soft-deleted. Use the same "latest
      // non-hidden ProjectLink wins" subquery so late-arriving sync
      // messages and hide-then-restore sequences remain correct.
      if (res != 0 && dbLink.type == 'ProjectLink') {
        await customStatement(
          'UPDATE journal SET project_id = ($_projectIdSubquery) WHERE id = ?',
          [dbLink.toId],
        );
      }

      return res;
    } else {
      return 0;
    }
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    final linesAffected = await entityDefinition.map(
      measurableDataType: (MeasurableDataType measurableDataType) async {
        return upsertMeasurableDataType(measurableDataType);
      },
      habit: upsertHabitDefinition,
      dashboard: upsertDashboardDefinition,
      categoryDefinition: upsertCategoryDefinition,
      labelDefinition: upsertLabelDefinition,
    );
    return linesAffected;
  }

  Future<int> upsertLabelDefinition(
    LabelDefinition labelDefinition,
  ) async {
    return into(
      labelDefinitions,
    ).insertOnConflictUpdate(labelDefinitionDbEntity(labelDefinition));
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

  void _captureException(
    Object error, {
    required String domain,
    required String subDomain,
    required StackTrace? stackTrace,
  }) {
    final logger = _logger;
    if (logger == null) {
      return;
    }

    logger.captureException(
      error,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
    );
  }

  void _captureEvent(
    String message, {
    required String domain,
    required String subDomain,
  }) {
    final logger = _logger;
    if (logger == null) {
      return;
    }

    logger.captureEvent(
      message,
      domain: domain,
      subDomain: subDomain,
    );
  }

  LoggingService? get _logger {
    if (_loggingService != null) {
      return _loggingService;
    }

    if (getIt.isRegistered<LoggingService>()) {
      return getIt<LoggingService>();
    }

    return null;
  }
}

/// In-flight coalescing wave for the open-task-due-date superset fetch.
/// Every caller in the same microtask wave that shares a private-status
/// shape joins the same wave; the wave issues a single `_selectTasksDue`
/// covering the widest `endInclusive` seen before the microtask fires.
class _PendingDueWave {
  _PendingDueWave({
    required this.endInclusive,
    required this.privateStatuses,
  });

  DateTime endInclusive;
  final List<bool> privateStatuses;
  final Completer<List<Task>> completer = Completer<List<Task>>.sync();
}

/// In-flight coalescing wave for `basicLinksForEntryIds`. Concurrent callers
/// within the same microtask merge their id sets; the wave fires one
/// `to_id IN (…)` query and each caller filters the full result down to
/// its own ids.
class _PendingLinksWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<List<EntryLink>> completer =
      Completer<List<EntryLink>>.sync();
}

/// In-flight coalescing wave for `getRatingIdsForTimeEntries`. Mirrors
/// [_PendingLinksWave] but keeps drift's rating-query result rows so each
/// caller can reconstruct its own last-write-wins map for its id subset.
class _PendingRatingsWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<List<RatingsForTimeEntriesResult>> completer =
      Completer<List<RatingsForTimeEntriesResult>>.sync();
}
