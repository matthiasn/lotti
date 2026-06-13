part of 'database.dart';

/// Schema migration strategy for [JournalDb], split from the main database
/// file for size. Kept as a mixin so it still overrides `_$JournalDb.migration`
/// and can call the table/column probes that remain on the concrete database.
mixin _JournalDbMigration on _$JournalDb, _JournalDbMigrationRecent {
  // _tableExists / _columnExists are inherited as contracts from
  // _JournalDbMigrationRecent (this mixin's on-clause).
  Future<void> _ensureLabelTables(Migrator migrator);
  Future<void> _rebuildLabeledWithFkCascade();
  bool get inMemoryDatabase;

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

        await _onUpgradeRecent(m, from);
      },
    );
  }
}
