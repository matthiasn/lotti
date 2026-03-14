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
import 'package:lotti/classes/tag_type_definitions.dart';
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
  final Map<String, JournalDbEntity?> _journalEntityByIdCache =
      <String, JournalDbEntity?>{};
  final Map<String, Completer<JournalDbEntity?>> _journalEntityByIdPending =
      <String, Completer<JournalDbEntity?>>{};
  final Map<String, List<JournalEntity>> _tasksQueryCache =
      <String, List<JournalEntity>>{};
  final Map<String, Future<List<JournalEntity>>> _tasksQueryPending =
      <String, Future<List<JournalEntity>>>{};
  Future<void>? _configFlagsBootstrap;
  bool _configFlagsLoaded = false;
  bool _journalEntityByIdFlushScheduled = false;
  int _tasksQueryCacheGeneration = 0;

  @override
  int get schemaVersion => 37;

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
              await m.createIndex(idxHabitDefinitionsDeletedPrivate);
            }
            if (await _tableExists('label_definitions')) {
              await m.createIndex(idxLabelDefinitionsDeletedPrivateName);
            }
            if (await _tableExists('dashboard_definitions')) {
              await m.createIndex(idxDashboardDefinitionsDeletedPrivateName);
            }
            if (await _tableExists('tag_entities')) {
              await m.createIndex(idxTagEntitiesDeletedPrivateTag);
            }
            if (await _tableExists('linked_entries')) {
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
              await m.createIndex(idxLabeledJournalIdLabelId);
            }
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
    _cacheJournalDbEntity(
      entry.id,
      entry.deleted ? null : entry,
    );
    _invalidateTaskQueryCache();
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
      _journalEntityByIdCache.remove(id);
      _invalidateTaskQueryCache();
    } catch (e) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'updateTaskPriorityColumn error',
        error: e,
      );
    }
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

  Future<void> insertTag(String id, String tagId) async {
    try {
      await into(tagged).insert(
        TaggedWith(
          id: uuid.v1(),
          journalId: id,
          tagEntityId: tagId,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    } catch (ex) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'insertTag failed',
        error: ex,
      );
    }
  }

  Future<void> addTagged(JournalEntity journalEntity) async {
    final id = journalEntity.meta.id;
    final tagIds = journalEntity.meta.tagIds ?? [];
    await deleteTaggedForId(id);

    for (final tagId in tagIds) {
      await insertTag(id, tagId);
    }
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
    _invalidateTaskQueryCache();
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
      await addTagged(updated);
      await addLabeled(updated);
      return JournalUpdateResult.applied(rowsWritten: rowsWritten);
    }

    return JournalUpdateResult.skipped(
      reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
    );
  }

  Future<JournalDbEntity?> entityById(String id) async {
    if (_journalEntityByIdCache.containsKey(id)) {
      return _journalEntityByIdCache[id];
    }

    final pending = _journalEntityByIdPending[id];
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<JournalDbEntity?>();
    _journalEntityByIdPending[id] = completer;

    if (!_journalEntityByIdFlushScheduled) {
      _journalEntityByIdFlushScheduled = true;
      scheduleMicrotask(_flushPendingJournalEntityByIdLookups);
    }

    return completer.future;
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
    final res = await journalEntitiesByIds(
      ids.toList(),
      await _visiblePrivateStatuses(),
    ).get();
    _seedJournalEntityCache(res);
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <JournalEntity>[];
    }

    final res = await entriesForIds(ids.toList()).get();
    _seedJournalEntityCache(
      res.where((entity) => !entity.deleted),
    );
    return res.where((entity) => !entity.deleted).map(fromDbEntity).toList();
  }

  Future<void> _flushPendingJournalEntityByIdLookups() async {
    _journalEntityByIdFlushScheduled = false;
    if (_journalEntityByIdPending.isEmpty) {
      return;
    }

    final pending = Map<String, Completer<JournalDbEntity?>>.from(
      _journalEntityByIdPending,
    );
    _journalEntityByIdPending.clear();
    final ids = pending.keys.toList(growable: false);

    try {
      final rows = await entriesForIds(ids).get();
      final rowById = <String, JournalDbEntity>{
        for (final row in rows)
          if (!row.deleted) row.id: row,
      };

      for (final id in ids) {
        final entity = rowById[id];
        _cacheJournalDbEntity(id, entity);
        pending[id]?.complete(entity);
      }
    } catch (error, stackTrace) {
      for (final completer in pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    }
  }

  void _cacheJournalDbEntity(String id, JournalDbEntity? entity) {
    _journalEntityByIdCache[id] = entity;
  }

  void _seedJournalEntityCache(Iterable<JournalDbEntity> entities) {
    for (final entity in entities) {
      _cacheJournalDbEntity(entity.id, entity.deleted ? null : entity);
    }
  }

  Future<List<String>> getJournalEntityIdsSortedByDateFromDesc(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) {
      return const <String>[];
    }

    return journalEntityIdsByDateFromDesc(
      idList,
      await _visiblePrivateStatuses(),
    ).get();
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
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);

    if (ids != null) {
      return filteredByTagJournal(
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
    final cacheKey = _buildTasksQueryCacheKey(
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
    );
    final cached = _tasksQueryCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final pending = _tasksQueryPending[cacheKey];
    if (pending != null) {
      return pending;
    }

    final generation = _tasksQueryCacheGeneration;
    late final Future<List<JournalEntity>> future;
    future =
        _selectTasks(
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
            )
            .get()
            .then((res) {
              final entities = List<JournalEntity>.unmodifiable(
                res.map(fromDbEntity),
              );

              if (generation == _tasksQueryCacheGeneration) {
                _tasksQueryCache[cacheKey] = entities;
              }
              return entities;
            })
            .whenComplete(() {
              if (identical(_tasksQueryPending[cacheKey], future)) {
                _tasksQueryPending.remove(cacheKey);
              }
            });

    _tasksQueryPending[cacheKey] = future;
    return future;
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
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);
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

  String _buildTasksQueryCacheKey({
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    required List<String>? labelIds,
    required List<String>? priorities,
    required List<String>? ids,
    required bool sortByDate,
    required int limit,
    required int offset,
  }) {
    String normalizeBools(List<bool> values) {
      final normalized = [...values]..sort((a, b) => a == b ? 0 : (a ? 1 : -1));
      return normalized.join(',');
    }

    String normalizeStrings(Iterable<String> values) {
      final normalized = values.toSet().toList()..sort();
      return normalized.join(',');
    }

    return [
      'star=${normalizeBools(starredStatuses)}',
      'private=${normalizeBools(privateStatuses)}',
      'status=${normalizeStrings(taskStatuses)}',
      'category=${normalizeStrings(categoryIds)}',
      'label=${normalizeStrings(labelIds ?? const <String>[])}',
      'priority=${normalizeStrings(priorities ?? const <String>[])}',
      'ids=${normalizeStrings(ids ?? const <String>[])}',
      'sortByDate=$sortByDate',
      'limit=$limit',
      'offset=$offset',
    ].join('|');
  }

  void _invalidateTaskQueryCache() {
    _tasksQueryCacheGeneration++;
    _tasksQueryCache.clear();
    _tasksQueryPending.clear();
  }

  Future<int> getWipCount() async {
    final privateStatuses = await _visiblePrivateStatuses();
    return countInProgressTasks(
      privateStatuses,
      ['IN PROGRESS'],
    ).getSingle();
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);

    final dbEntities = matchesAllPrivateStates
        ? await linkedJournalEntitiesAllPrivate(linkedFrom).get()
        : await linkedJournalEntities(
            linkedFrom,
            privateStatuses,
          ).get();
    _seedJournalEntityCache(dbEntities);
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalDbEntity>> getLinkedToEntities(String linkedTo) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);

    final dbEntities = matchesAllPrivateStates
        ? await linkedToJournalEntities(linkedTo).get()
        : await linkedToJournalEntitiesByPrivateStatuses(
            linkedTo,
            privateStatuses,
          ).get();
    _seedJournalEntityCache(dbEntities);
    return dbEntities;
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
    final entities = await getJournalEntitiesForIds(targetIds);

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

  Future<int> getTaggedCount() async {
    return (await countTagged().get()).first;
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

    final tagCount =
        await (select(tagEntities)..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final journalCount =
        await (select(journal)..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final totalItems =
        dashboardCount + measurableCount + tagCount + journalCount;

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
    yield 0.25; // 25% complete after dashboards
    await Future<void>.delayed(stepDelay);

    // Purge measurables
    if (measurableCount > 0) {
      await (delete(
        measurableTypes,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.5; // 50% complete after measurables
    await Future<void>.delayed(stepDelay);

    // Purge tags
    if (tagCount > 0) {
      await (delete(
        tagEntities,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.75; // 75% complete after tags
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
      _invalidateTaskQueryCache();
    }
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    await _ensureConfigFlagsLoaded();
    final result = await into(configFlags).insertOnConflictUpdate(configFlag);
    _setConfigFlag(configFlag);
    _invalidateTaskQueryCache();
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
            _configFlagsBootstrap = Future<void>.value();
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
    for (final completer in _journalEntityByIdPending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('JournalDb closed before entity lookup completed'),
        );
      }
    }
    _journalEntityByIdCache.clear();
    _journalEntityByIdPending.clear();
    _tasksQueryCache.clear();
    _tasksQueryPending.clear();
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
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);
    final res = matchesAllPrivateStates
        ? await dayPlanById(id).get()
        : await dayPlanByIdByPrivateStatuses(id, privateStatuses).get();
    if (res.isEmpty) return null;
    return fromDbEntity(res.first) as DayPlanEntry;
  }

  Future<List<DayPlanEntry>> getDayPlansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);
    final res = matchesAllPrivateStates
        ? await dayPlansInRange(rangeStart, rangeEnd).get()
        : await dayPlansInRangeByPrivateStatuses(
            rangeStart,
            rangeEnd,
            privateStatuses,
          ).get();
    return res.map((e) => fromDbEntity(e) as DayPlanEntry).toList();
  }

  /// Returns tasks that are due on or before the specified date.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// This includes both tasks due on the specified day and overdue tasks.
  Future<List<Task>> getTasksDueOnOrBefore(DateTime date) async {
    // Use end of day to capture tasks due on this day
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final endIso = endOfDay.toIso8601String();

    final res = await _selectTasksDue(
      endIso: endIso,
      privateStatuses: await _visiblePrivateStatuses(),
    );
    return res.map(fromDbEntity).whereType<Task>().toList();
  }

  /// Returns tasks that are due on the specified date only.
  /// Excludes completed (DONE) and rejected (REJECTED) tasks.
  /// Does NOT include overdue tasks from previous days.
  Future<List<Task>> getTasksDueOn(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final startIso = startOfDay.toIso8601String();
    final endIso = endOfDay.toIso8601String();

    final res = await _selectTasksDue(
      startIso: startIso,
      endIso: endIso,
      privateStatuses: await _visiblePrivateStatuses(),
    );
    return res.map(fromDbEntity).whereType<Task>().toList();
  }

  // Drift SQL doesn't support `INDEXED BY`, so keep the due-date hot path in
  // raw SQL to force the dedicated expression index on large journal tables.
  Future<List<JournalDbEntity>> _selectTasksDue({
    required String endIso,
    required List<bool> privateStatuses,
    String? startIso,
  }) {
    final variables = <Variable<Object>>[];
    final buffer = StringBuffer()
      ..write('SELECT * FROM journal INDEXED BY idx_journal_tasks_due_active ')
      ..write("WHERE type = 'Task' ")
      ..write('AND deleted = 0 ')
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
  Future<Map<String, String>> getRatingIdsForTimeEntries(
    Set<String> timeEntryIds,
  ) async {
    if (timeEntryIds.isEmpty) return {};
    final rows = await ratingsForTimeEntries(timeEntryIds.toList()).get();
    return {for (final row in rows) row.timeEntryId: row.ratingId};
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
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);
    final labels = matchesAllPrivateStates
        ? await allLabelDefinitions().get()
        : await allLabelDefinitionsByPrivateStatuses(privateStatuses).get();
    return labelDefinitionsStreamMapper(labels);
  }

  Future<LabelDefinition?> getLabelDefinitionById(String id) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates =
        privateStatuses.length == 2 &&
        privateStatuses.contains(true) &&
        privateStatuses.contains(false);
    final result = matchesAllPrivateStates
        ? await labelDefinitionById(id).get()
        : await labelDefinitionByIdByPrivateStatuses(id, privateStatuses).get();
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

  Future<List<TagEntity>> getAllTags() async {
    return tagStreamMapper(await allTagEntities().get());
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

  Future<List<TagEntity>> getMatchingTags(
    String match, {
    int limit = 10,
    bool inactive = false,
  }) async {
    return (await matchingTagEntities(
      '%$match%',
      inactive,
      limit,
    ).get()).map(fromTagDbEntity).toList();
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

  Future<int> upsertTagEntity(TagEntity tag) async {
    final dbEntity = tagDbEntity(tag);
    return into(tagEntities).insertOnConflictUpdate(dbEntity);
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
  Future<List<EntryLink>> basicLinksForEntryIds(Set<String> ids) async {
    if (ids.isEmpty) return <EntryLink>[];
    final entryLinks =
        await (select(linkedEntries)..where(
              (t) => t.toId.isIn(ids.toList()) & t.type.equals('BasicLink'),
            ))
            .get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
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
        return 0; // duplicate secondary key
      }

      final res = into(linkedEntries).insertOnConflictUpdate(dbLink);
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
