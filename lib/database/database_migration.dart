part of 'database.dart';

/// Schema migration strategy for [JournalDb], split from the main database
/// file for size. Kept as a mixin so it still overrides `_$JournalDb.migration`
/// and can call the table/column probes that remain on the concrete database.
mixin _JournalDbMigration on _$JournalDb, _JournalDbMigrationRecent {
  Future<void> _ensureLabelTables(Migrator migrator);
  Future<void> _rebuildLabeledWithFkCascade();
  bool get inMemoryDatabase;
  String get fileName;
  Future<Directory> Function()? get _documentsDirectoryProvider;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // PRAGMA is connection-local — must run on every connection.
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement(_createIdxJournalQuantLatestSql);
        await customStatement(_createIdxConflictsStatusCreatedSql);
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
          await backupBeforeMigration(
            fileName,
            from: from,
            to: to,
            documentsDirectoryProvider: _documentsDirectoryProvider,
          );
        }

        // Every step, the index reconcile that ends them, and the version
        // stamp, in one transaction. Drift runs onUpgrade outside one and
        // writes user_version only after onUpgrade and beforeOpen have both
        // completed; SQLite's DDL is transactional, so an interrupted
        // upgrade — a crash, a kill mid rebuild — rolls back to the version
        // that was running instead of leaving a half-applied schema at the
        // old user_version that the next launch would try to migrate again,
        // and a kill after the commit cannot leave the new schema under the
        // old stamp either. Foreign-key enforcement cannot change inside a
        // transaction and is off on a fresh connection; it is switched on in
        // beforeOpen once the upgrade has committed.
        await customStatement('PRAGMA foreign_keys = OFF');
        await transaction(() async {
          if (from < 19) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Creating category_definitions table and indices',
              );
              await m.createTable(categoryDefinitions);
              await m.createIndex(idxCategoryDefinitionsName);
              await m.createIndex(idxCategoryDefinitionsPrivate);
            }();
          }

          if (from < 21) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Add category_id in journal table, with index',
              );
              await _addColumnUnlessPresent(
                journal.actualTableName,
                journal.category.name,
                () => m.addColumn(journal, journal.category),
              );
            }();
          }

          if (from < 22) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Add hidden in linked_entries table',
              );
              await _addColumnUnlessPresent(
                linkedEntries.actualTableName,
                linkedEntries.hidden.name,
                () => m.addColumn(linkedEntries, linkedEntries.hidden),
              );
            }();
          }

          if (from < 23) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Add timestamps in linked_entries table, with index',
              );
              await _addColumnUnlessPresent(
                linkedEntries.actualTableName,
                linkedEntries.createdAt.name,
                () => m.addColumn(linkedEntries, linkedEntries.createdAt),
              );
              await _addColumnUnlessPresent(
                linkedEntries.actualTableName,
                linkedEntries.updatedAt.name,
                () => m.addColumn(linkedEntries, linkedEntries.updatedAt),
              );
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
              // The current task index references priority columns introduced
              // in v29. That step below creates it after adding the columns;
              // creating it here would fail on an actual pre-v25 database.
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

              await _addColumnUnlessPresent(
                journal.actualTableName,
                journal.taskPriority.name,
                () => m.addColumn(journal, journal.taskPriority),
              );
              await _addColumnUnlessPresent(
                journal.actualTableName,
                journal.taskPriorityRank.name,
                () => m.addColumn(journal, journal.taskPriorityRank),
              );

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
                message:
                    'Fixing idx_linked_entries_to_id_hidden to index to_id',
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
              await customStatement(
                'DROP INDEX IF EXISTS idx_habit_definitions_deleted_private',
              );
              await m.createIndex(idxHabitDefinitionsDeletedPrivate);
              await customStatement(
                'DROP INDEX IF EXISTS idx_label_definitions_deleted_private_name',
              );
              await m.createIndex(idxLabelDefinitionsDeletedPrivateName);
              await customStatement(
                'DROP INDEX IF EXISTS idx_dashboard_definitions_deleted_private_name',
              );
              await m.createIndex(idxDashboardDefinitionsDeletedPrivateName);
              // tag_entities index migration removed — table is no longer
              // managed by drift but left intact in existing databases.
              await customStatement(
                'DROP INDEX IF EXISTS idx_linked_entries_from_id_hidden_created_at_desc',
              );
              await m.createIndex(idxLinkedEntriesFromIdHiddenCreatedAtDesc);
            }();
          }

          // v35: Add a date-oriented task index for date-sorted task queries.
          if (from < 35) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Adding date-oriented task index',
              );
              await customStatement(
                'DROP INDEX IF EXISTS idx_journal_tasks_date',
              );
              await m.createIndex(idxJournalTasksDate);
            }();
          }

          // v36: Add a browse-oriented journal index for common journal lists.
          if (from < 36) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Adding browse-oriented journal index',
              );
              await customStatement('DROP INDEX IF EXISTS idx_journal_browse');
              await m.createIndex(idxJournalBrowse);
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
              // Remove redundant index — the UNIQUE(journal_id, label_id)
              // constraint already creates an equivalent implicit index.
              await customStatement(
                'DROP INDEX IF EXISTS idx_labeled_journal_id_label_id',
              );
            }();
          }

          // v38: Add denormalized project_id column to journal for efficient
          // task-by-project filtering without a JOIN on linked_entries.
          if (from < 38) {
            await () async {
              DevLogger.log(
                name: 'JournalDb',
                message: 'Adding project_id column to journal table',
              );
              await _addColumnUnlessPresent(
                journal.actualTableName,
                journal.projectId.name,
                () => m.addColumn(journal, journal.projectId),
              );
              // Backfill project_id from the most-recent active ProjectLink.
              await customStatement(
                "UPDATE journal SET project_id = ($_projectIdSubquery) WHERE type = 'Task'",
              );
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
            }();
          }

          await _onUpgradeRecent(m, from);
          await _reconcileIndexesWithSchema(m);
          // Drift repeats this write after beforeOpen; stamping here makes
          // the schema and its version commit together.
          await customStatement('PRAGMA user_version = $to');
        });
      },
    );
  }

  /// Brings the indexes of every Drift-managed table in line with the
  /// declared schema: drops indexes the schema no longer declares, recreates
  /// declared ones whose stored definition differs, creates declared ones
  /// that are missing.
  ///
  /// Runs at the end of every upgrade. `database.drift` is the single
  /// statement of which indexes exist and what they look like, so an index
  /// change — new, gone, or reshaped under the same name — is an edit there
  /// plus a version bump, with no hand-written `CREATE`/`DROP INDEX` in the
  /// migration. It exists because the history did not work that way:
  /// installs from before v25 still carried every single-column index the
  /// original schema created and later versions stopped declaring but never
  /// dropped, up to seventeen on `journal`, each paid for on every write.
  ///
  /// Definitions are compared through [normaliseIndexDefinition], which
  /// removes only spelling that does not change an index (case, whitespace,
  /// quoting, the default `COLLATE BINARY` and `ASC`), so a `.drift`
  /// declaration and the raw statement a past migration used compare equal
  /// and nothing is rebuilt for cosmetics.
  ///
  /// Only explicitly created indexes on managed tables are touched;
  /// SQLite's own constraint indexes and any table Drift does not manage
  /// (legacy tables left in place) are ignored. A declared index whose
  /// table is absent — the case in minimal migration fixtures — is skipped.
  Future<void> _reconcileIndexesWithSchema(Migrator m) async {
    final managedTables = {
      for (final table in allTables) table.actualTableName,
    };
    final declared = {
      for (final index in allSchemaEntities.whereType<Index>())
        index.entityName: index,
    };
    final existingRows = await customSelect(
      "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' "
      'AND sql IS NOT NULL',
    ).get();
    final existing = <String, ({String table, String sql})>{
      for (final row in existingRows)
        row.read<String>('name'): (
          table: row.read<String>('tbl_name'),
          sql: row.read<String>('sql'),
        ),
    };
    final existingTables = {
      for (final row in await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ).get())
        row.read<String>('name'),
    };

    final toCreate = <Index>[];
    for (final entry in existing.entries) {
      final name = entry.key;
      final table = entry.value.table;
      if (!managedTables.contains(table)) continue;
      final index = declared[name];
      if (index == null) {
        DevLogger.log(
          name: 'JournalDb',
          message: 'Dropping undeclared index $name on $table',
        );
        await customStatement('DROP INDEX IF EXISTS "$name"');
        continue;
      }
      final declaredSql = _declaredStatement(index);
      if (declaredSql != null &&
          normaliseIndexDefinition(entry.value.sql) !=
              normaliseIndexDefinition(declaredSql)) {
        DevLogger.log(
          name: 'JournalDb',
          message: 'Recreating index $name on $table: definition changed',
        );
        await customStatement('DROP INDEX IF EXISTS "$name"');
        toCreate.add(index);
      }
    }

    for (final index in declared.values) {
      if (existing.containsKey(index.entityName) && !toCreate.contains(index)) {
        continue;
      }
      final table = _indexedTable(index);
      if (table == null || !existingTables.contains(table)) continue;
      if (!toCreate.contains(index)) {
        DevLogger.log(
          name: 'JournalDb',
          message: 'Creating declared index ${index.entityName} on $table',
        );
      }
      await m.createIndex(index);
    }
  }

  static String? _declaredStatement(Index index) =>
      index.createStatementsByDialect[SqlDialect.sqlite];

  /// The table an index is declared on, read from its `CREATE INDEX`
  /// statement; Drift's runtime [Index] does not carry the reference.
  static String? _indexedTable(Index index) {
    final statement = _declaredStatement(index);
    if (statement == null) return null;
    return RegExp(
      r'\bON\s+"?([A-Za-z0-9_]+)"?\s*\(',
      caseSensitive: false,
    ).firstMatch(statement)?.group(1);
  }
}

/// Reduces a `CREATE INDEX` statement to the spelling that determines what
/// the index is, so two statements compare equal exactly when they would
/// build the same index.
///
/// Removed: case, whitespace, double quotes, `IF NOT EXISTS`, spacing around
/// parentheses, commas and `=`, and the defaults SQLite applies anyway —
/// `COLLATE BINARY` and `ASC`. Kept: columns and their order, `DESC`,
/// `UNIQUE`, expressions, and the partial `WHERE` clause.
String normaliseIndexDefinition(String sql) {
  return sql
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' if not exists', '')
      .replaceAll('"', '')
      .replaceAll(RegExp(r'\s*\(\s*'), '(')
      .replaceAll(RegExp(r'\s*\)\s*'), ')')
      .replaceAll(RegExp(r'\s*,\s*'), ',')
      .replaceAll(' collate binary', '')
      .replaceAll(RegExp(r' asc\b'), '')
      .replaceAll(RegExp(r'\s*=\s*'), '=')
      .replaceAll(RegExp(r';\s*$'), '')
      .trim();
}
