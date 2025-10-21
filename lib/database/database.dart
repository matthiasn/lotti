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
  int get schemaVersion => 25;

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
      },
    );
  }

  Future<int> upsertJournalDbEntity(JournalDbEntity entry) async {
    final res = into(journal).insertOnConflictUpdate(entry);
    return res;
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

  Future<int> updateJournalEntity(
    JournalEntity updated, {
    bool overrideComparison = false,
    bool overwrite = true,
  }) async {
    var rowsAffected = 0;
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    final existingDbEntity = await entityById(dbEntity.id);

    if (existingDbEntity != null && !overwrite) {
      return rowsAffected;
    }

    if (existingDbEntity != null) {
      final existing = fromDbEntity(existingDbEntity);
      final status = await detectConflict(existing, updated);

      if (status == VclockStatus.b_gt_a || overrideComparison) {
        rowsAffected = await upsertJournalDbEntity(dbEntity);

        final existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else {
        getIt<LoggingService>().captureEvent(
          EnumToString.convertToString(status),
          domain: 'JOURNAL_DB',
          subDomain: 'Conflict status',
        );
      }
    } else {
      rowsAffected = await upsertJournalDbEntity(dbEntity);
    }
    await saveJournalEntityJson(updated);
    await addTagged(updated);

    return rowsAffected;
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
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    final res = await _selectTasks(
      starredStatuses: starredStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
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
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    final types = <String>['Task'];
    if (ids != null) {
      return filteredTasks2(
        types,
        ids,
        starredStatuses,
        taskStatuses,
        categoryIds,
        limit,
        offset,
      );
    } else {
      return filteredTasks(
        types,
        starredStatuses,
        taskStatuses,
        categoryIds,
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
    );
    return linesAffected;
  }
}
