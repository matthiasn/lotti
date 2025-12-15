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
  }) : super(
          openDbConnection(
            overriddenFilename ?? journalDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 29;

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
        debugPrint('Migration from v$from to v$to');

        if (from < 19) {
          await () async {
            debugPrint('Creating category_definitions table and indices');
            await m.createTable(categoryDefinitions);
            await m.createIndex(idxCategoryDefinitionsName);
            await m.createIndex(idxCategoryDefinitionsId);
            await m.createIndex(idxCategoryDefinitionsPrivate);
          }();
        }

        if (from < 21) {
          await () async {
            debugPrint('Add category_id in journal table, with index');
            await m.addColumn(journal, journal.category);
          }();
        }

        if (from < 22) {
          await () async {
            debugPrint('Add hidden in linked_entries table, with index');
            await m.addColumn(linkedEntries, linkedEntries.hidden);
            await m.createIndex(idxLinkedEntriesHidden);
          }();
        }

        if (from < 23) {
          await () async {
            debugPrint('Add timestamps in linked_entries table, with index');
            await m.addColumn(linkedEntries, linkedEntries.createdAt);
            await m.addColumn(linkedEntries, linkedEntries.updatedAt);
          }();
        }

        if (from < 24) {
          await () async {
            debugPrint('Adding composite indices');
            await m.createIndex(idxLinkedEntriesFromIdHidden);
            await m.createIndex(idxLinkedEntriesToIdHidden);
          }();
        }

        if (from < 25) {
          await () async {
            debugPrint('Adding composite indices');
            await m.createIndex(idxJournalTab);
            await m.createIndex(idxJournalTasks);
            await m.createIndex(idxJournalTypeSubtype);
          }();
        }

        if (from < 26) {
          await () async {
            debugPrint('Creating label_definitions and labeled tables');
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
            debugPrint('Ensuring label tables exist for legacy v26 installs');
            await _ensureLabelTables(m);
          }();
        }

        // v28: Rebuild `labeled` with FK on label_id -> label_definitions(id) ON DELETE CASCADE
        if (from < 28) {
          await () async {
            debugPrint(
                'Rebuilding labeled table to add FK with ON DELETE CASCADE');
            await _rebuildLabeledWithFkCascade();
          }();
        }

        // v29: Add task priority columns and update tasks index
        if (from < 29) {
          await () async {
            debugPrint('Adding task priority columns and updating index');

            // Add columns only if missing to avoid masking other errors
            final hasTaskPriority =
                await _columnExists('journal', 'task_priority');
            if (!hasTaskPriority) {
              await m.addColumn(journal, journal.taskPriority);
            }

            final hasTaskPriorityRank =
                await _columnExists('journal', 'task_priority_rank');
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
    final res = into(journal).insertOnConflictUpdate(entry);
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
      debugPrint('updateTaskPriorityColumn error: $e');
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
        debugPrint('Conflicting vector clocks: $status');
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
      );
    } catch (ex) {
      debugPrint(ex.toString());
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
      debugPrint(ex.toString());
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
        getIt<LoggingService>().captureException(
          error,
          domain: 'JOURNAL_DB',
          subDomain: 'detectConflict',
          stackTrace: stackTrace,
        );
        skipReason = JournalUpdateSkipReason.conflict;
      }

      final canApply = status == VclockStatus.b_gt_a ||
          (overrideComparison && status != null);

      if (canApply) {
        rowsWritten = await upsertJournalDbEntity(dbEntity);
        applied = true;
        final existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else if (status != null) {
        getIt<LoggingService>().captureEvent(
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
      await saveJournalEntityJson(updated);
      await addTagged(updated);
      await addLabeled(updated);
      return JournalUpdateResult.applied(rowsWritten: rowsWritten);
    }

    return JournalUpdateResult.skipped(
      reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
    );
  }

  Future<JournalDbEntity?> entityById(String id) async {
    final res = await (select(journal)
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
    final res = await journalEntitiesByIds(ids.toList()).get();
    return res.map(fromDbEntity).toList();
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
      return filteredJournalByCategories(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        categoryIds,
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
    int limit = 500,
    int offset = 0,
  }) async {
    final res = await _selectTasks(
      starredStatuses: starredStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      priorities: priorities,
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();

    return res.map(fromDbEntity).toList();
  }

  Selectable<JournalDbEntity> _selectTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    final types = <String>['Task'];
    final selectedLabelIds = labelIds ?? <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds =
        selectedLabelIds.where((id) => id.isNotEmpty).toList();
    final labelFilterCount = filteredLabelIds.length;
    // Avoid passing an empty list to the SQL `IN (:labelIds)` clause.
    // SQLite (and SQL generally) does not allow an empty `IN ()`, so we
    // substitute a dummy value when no label IDs are selected. The query
    // never matches this magic string; it only keeps the SQL valid.
    final effectiveLabelIds =
        labelFilterCount == 0 ? <String>['__no_label__'] : filteredLabelIds;
    final filterByLabels = includeUnlabeled || labelFilterCount > 0;
    final dbTaskStatuses = taskStatuses.cast<String?>();
    final selectedPriorities = priorities ?? <String>[];
    final filterByPriorities = selectedPriorities.isNotEmpty;
    final dbPriorities = selectedPriorities.cast<String?>();

    if (ids != null) {
      return filteredTasks2(
        types,
        ids,
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
      return filteredTasks(
        types,
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
    final res = await _selectTasks(
      starredStatuses: [true, false],
      taskStatuses: ['IN PROGRESS'],
      categoryIds: [''],
      limit: 100000,
    ).get();
    return res.length;
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final dbEntities = await linkedJournalEntities(linkedFrom).get();
    return dbEntities.map(fromDbEntity).toList();
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
      for (final id in fromIds) id: []
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: {}
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
    final dbEntities =
        await sortedCalenderEntriesInRange(rangeStart, rangeEnd).get();
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
    return listConfigFlags().watch().map((flags) => flags.toSet());
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
    final deletedEntries =
        await (select(journal)..where((tbl) => tbl.deleted.equals(true))).get();

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

  Stream<double> purgeDeleted({bool backup = true}) async* {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    // First delete the actual files
    await purgeDeletedFiles();

    // Get counts for each type
    final dashboardCount = await (select(dashboardDefinitions)
          ..where((tbl) => tbl.deleted.equals(true)))
        .get()
        .then((list) => list.length);

    final measurableCount = await (select(measurableTypes)
          ..where((tbl) => tbl.deleted.equals(true)))
        .get()
        .then((list) => list.length);

    final tagCount = await (select(tagEntities)
          ..where((tbl) => tbl.deleted.equals(true)))
        .get()
        .then((list) => list.length);

    final journalCount = await (select(journal)
          ..where((tbl) => tbl.deleted.equals(true)))
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
      await (delete(dashboardDefinitions)
            ..where((tbl) => tbl.deleted.equals(true)))
          .go();
    }
    yield 0.25; // 25% complete after dashboards
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Purge measurables
    if (measurableCount > 0) {
      await (delete(measurableTypes)..where((tbl) => tbl.deleted.equals(true)))
          .go();
    }
    yield 0.5; // 50% complete after measurables
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Purge tags
    if (tagCount > 0) {
      await (delete(tagEntities)..where((tbl) => tbl.deleted.equals(true)))
          .go();
    }
    yield 0.75; // 75% complete after tags
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Purge journal entries
    if (journalCount > 0) {
      await (delete(journal)..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 1.0; // 100% complete after journal entries
  }

  Future<bool> getConfigFlag(String flagName) async {
    final flags = await listConfigFlags().get();
    return findConfigFlag(flagName, flags);
  }

  Stream<bool> watchConfigFlag(String flagName) {
    return listConfigFlags().watch().map((List<ConfigFlag> flags) {
      return findConfigFlag(flagName, flags);
    });
  }

  Future<ConfigFlag?> getConfigFlagByName(String flagName) async {
    final flags = await configFlagByName(flagName).get();

    if (flags.isNotEmpty) {
      return flags.first;
    }
    return null;
  }

  Future<void> insertFlagIfNotExists(ConfigFlag configFlag) async {
    final existing = await getConfigFlagByName(configFlag.name);

    if (existing == null) {
      await into(configFlags).insert(configFlag);
    }
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    return into(configFlags).insertOnConflictUpdate(configFlag);
  }

  Future<void> toggleConfigFlag(String flagName) async {
    final configFlag = await getConfigFlagByName(flagName);

    if (configFlag != null) {
      await upsertConfigFlag(configFlag.copyWith(status: !configFlag.status));
    }
  }

  Future<int> getCountImportFlagEntries() async {
    final res = await countImportFlagEntries().get();
    return res.first;
  }

  Future<int> getTasksCount({
    List<String> statuses = const ['IN PROGRESS'],
  }) async {
    final res = await countInProgressTasks(statuses).get();
    return res.first;
  }

  Stream<List<MeasurableDataType>> watchMeasurableDataTypes() {
    return activeMeasurableTypes().watch().map(measurableDataTypeStreamMapper);
  }

  Stream<MeasurableDataType?> watchMeasurableDataTypeById(String id) {
    return measurableTypeById(id)
        .watch()
        .map(measurableDataTypeStreamMapper)
        .map((List<MeasurableDataType> res) => res.firstOrNull);
  }

  Future<MeasurableDataType?> getMeasurableDataTypeById(String id) async {
    final res = await measurableTypeById(id).get();
    return res.map(measurableDataType).firstOrNull;
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
    final res =
        await habitCompletionsByHabitId(habitId, rangeStart, rangeEnd).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getHabitCompletionsInRange({
    required DateTime rangeStart,
  }) async {
    final res = await habitCompletionsInRange(rangeStart).get();
    return res.map(fromDbEntity).toList();
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
      debugPrint('latestQuantitativeByType no result for $type');
      return null;
    }
    return fromDbEntity(dbEntities.first) as QuantitativeEntry;
  }

  Future<WorkoutEntry?> latestWorkout() async {
    final dbEntities = await findLatestWorkout().get();
    if (dbEntities.isEmpty) {
      debugPrint('no workout found');
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

  Stream<List<TagEntity>> watchTags() {
    return allTagEntities().watch().map(tagStreamMapper);
  }

  Stream<List<DashboardDefinition>> watchDashboards() {
    return allDashboards().watch().map(dashboardStreamMapper);
  }

  Stream<DashboardDefinition?> watchDashboardById(String id) {
    return dashboardById(id)
        .watch()
        .map(dashboardStreamMapper)
        .map((res) => res.firstOrNull);
  }

  Stream<List<HabitDefinition>> watchHabitDefinitions() {
    return allHabitDefinitions().watch().map(habitDefinitionsStreamMapper);
  }

  Stream<List<CategoryDefinition>> watchCategories() {
    return allCategoryDefinitions()
        .watch()
        .map(categoryDefinitionsStreamMapper);
  }

  Stream<List<LabelDefinition>> watchLabelDefinitions() {
    return allLabelDefinitions().watch().map(labelDefinitionsStreamMapper);
  }

  Stream<Map<String, int>> watchLabelUsageCounts() {
    final query = customSelect(
      '''
      SELECT label_id, COUNT(*) AS usage_count
      FROM labeled
      GROUP BY label_id
      ''',
      readsFrom: {labeled},
    );

    return query.watch().map((rows) {
      final usage = <String, int>{};
      for (final row in rows) {
        final labelId = row.read<String>('label_id');
        usage[labelId] = row.read<int>('usage_count');
      }
      return usage;
    });
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

  Stream<LabelDefinition?> watchLabelDefinitionById(String id) {
    // For single-entity watches, do not filter by the global private flag.
    // Settings and edit flows need to observe changes (including private toggles)
    // for a specific label. We only exclude hard-deleted rows here.
    final query = select(labelDefinitions)
      ..where((t) => t.id.equals(id) & t.deleted.equals(false));
    return query.watch().map(labelDefinitionsStreamMapper).map(
          (List<LabelDefinition> res) => res.firstOrNull,
        );
  }

  Future<List<LabelDefinition>> getAllLabelDefinitions() async {
    final labels = await allLabelDefinitions().get();
    return labelDefinitionsStreamMapper(labels);
  }

  Future<LabelDefinition?> getLabelDefinitionById(String id) async {
    final result = await labelDefinitionById(id).get();
    return labelDefinitionsStreamMapper(result).firstOrNull;
  }

  Stream<CategoryDefinition?> watchCategoryById(String id) {
    return categoryById(id)
        .watch()
        .map(categoryDefinitionsStreamMapper)
        .map((List<CategoryDefinition> res) => res.firstOrNull);
  }

  Stream<HabitDefinition?> watchHabitById(String id) {
    return habitById(id)
        .watch()
        .map(habitDefinitionsStreamMapper)
        .map((List<HabitDefinition> res) => res.firstOrNull);
  }

  Future<List<TagEntity>> getMatchingTags(
    String match, {
    int limit = 10,
    bool inactive = false,
  }) async {
    return (await matchingTagEntities('%$match%', inactive, limit).get())
        .map(fromTagDbEntity)
        .toList();
  }

  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where((t) => t.id.equals(conflict.id)))
        .write(conflict.copyWith(status: ConflictStatus.resolved.index));
  }

  Future<int> upsertMeasurableDataType(
    MeasurableDataType entityDefinition,
  ) async {
    return into(measurableTypes)
        .insertOnConflictUpdate(measurableDbEntity(entityDefinition));
  }

  Future<int> upsertTagEntity(TagEntity tag) async {
    final dbEntity = tagDbEntity(tag);
    return into(tagEntities).insertOnConflictUpdate(dbEntity);
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) async {
    return into(habitDefinitions)
        .insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition));
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
    final entryLinks = await linksForIds(ids.toList()).get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
  }

  Future<EntryLink?> entryLinkById(String id) async {
    final res = await (select(linkedEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (res == null) return null;
    return entryLinkFromLinkedDbEntry(res);
  }

  Future<int> upsertEntryLink(EntryLink link) async {
    if (link.fromId != link.toId) {
      try {
        // Equality precheck: if an entry with the same id exists and the
        // serialized payload is identical, skip the UPSERT to avoid a no-op
        // UPDATE and downstream log noise.
        final existing = await (select(linkedEntries)
              ..where((t) => t.id.equals(link.id)))
            .getSingleOrNull();
        if (existing != null) {
          final incomingSerialized = jsonEncode(link);
          if (existing.serialized == incomingSerialized) {
            return 0; // no change needed
          }
        }
      } catch (_) {
        // Best-effort precheck only; fall through to UPSERT on failure.
      }

      final res = into(linkedEntries).insertOnConflictUpdate(
        linkedDbEntity(link),
      );
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
    return into(labelDefinitions)
        .insertOnConflictUpdate(labelDefinitionDbEntity(labelDefinition));
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
        'CREATE INDEX IF NOT EXISTS idx_labeled_journal_id ON labeled (journal_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_labeled_label_id ON labeled (label_id)');
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
}
