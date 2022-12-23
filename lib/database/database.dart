import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/stream_helpers.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

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
  JournalDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            journalDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  JournalDb.connect(super.connection) : super.connect();

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 18;

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

        await () async {
          debugPrint('Creating habit_definitions table and indices');
          await m.createTable(habitDefinitions);
          await m.createIndex(idxHabitDefinitionsId);
          await m.createIndex(idxHabitDefinitionsName);
          await m.createIndex(idxHabitDefinitionsPrivate);
        }();

        await () async {
          debugPrint('Creating dashboard_definitions table and indices');
          await m.createTable(dashboardDefinitions);
          await m.createIndex(idxDashboardDefinitionsId);
          await m.createIndex(idxDashboardDefinitionsName);
          await m.createIndex(idxDashboardDefinitionsPrivate);
        }();

        await () async {
          debugPrint('Add last_reviewed column in dashboard_definitions');
          await m.addColumn(
            dashboardDefinitions,
            dashboardDefinitions.lastReviewed,
          );
        }();

        await () async {
          debugPrint('Creating tagged table and indices');
          await m.createTable(tagged);
          await m.createIndex(idxTaggedJournalId);
          await m.createIndex(idxTaggedTagEntityId);
        }();

        await () async {
          debugPrint('Creating task columns and indices');
          await m.addColumn(journal, journal.taskStatus);
          await m.createIndex(idxJournalTaskStatus);
          await m.addColumn(journal, journal.task);
          await m.createIndex(idxJournalTask);
        }();

        await () async {
          debugPrint('Creating linked entries table and indices');
          await m.createTable(linkedEntries);
          await m.createIndex(idxLinkedEntriesFromId);
          await m.createIndex(idxLinkedEntriesToId);
          await m.createIndex(idxLinkedEntriesType);
        }();

        await () async {
          debugPrint('Creating tag_entities table and indices');
          await m.createTable(tagEntities);
          await m.createIndex(idxTagEntitiesId);
          await m.createIndex(idxTagEntitiesTag);
          await m.createIndex(idxTagEntitiesType);
          await m.createIndex(idxTagEntitiesInactive);
          await m.createIndex(idxTagEntitiesPrivate);
        }();

        await () async {
          debugPrint('Remove journal_tags table');
          await m.deleteTable('journal_tags');
        }();

        await () async {
          debugPrint('Remove tag_definitions table');
          await m.deleteTable('tag_definitions');
        }();
      },
    );
  }

  Future<int> upsertJournalDbEntity(JournalDbEntity entry) async {
    return into(journal).insertOnConflictUpdate(entry);
  }

  Future<int> addConflict(Conflict conflict) async {
    return into(conflicts).insertOnConflictUpdate(conflict);
  }

  Future<int?> addJournalEntity(JournalEntity journalEntity) async {
    final dbEntity = toDbEntity(journalEntity);
    await saveJournalEntityJson(journalEntity);

    final exists = (await entityById(dbEntity.id)) != null;
    if (!exists) {
      return upsertJournalDbEntity(dbEntity);
    } else {
      return 0;
    }
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

  Future<int> updateJournalEntity(JournalEntity updated) async {
    var rowsAffected = 0;
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    final existingDbEntity = await entityById(dbEntity.id);
    if (existingDbEntity != null) {
      final existing = fromDbEntity(existingDbEntity);
      final status = await detectConflict(existing, updated);
      debugPrint('Conflict status: ${EnumToString.convertToString(status)}');

      if (status == VclockStatus.b_gt_a) {
        rowsAffected = await upsertJournalDbEntity(dbEntity);

        final existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else {}
    } else {
      rowsAffected = await upsertJournalDbEntity(dbEntity);
    }

    await saveJournalEntityJson(updated);
    await addTagged(updated);

    return rowsAffected;
  }

  Future<JournalDbEntity?> entityById(String id) async {
    final res = await (select(journal)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Stream<JournalEntity?> watchEntityById(String id) {
    final res = (select(journal)..where((t) => t.id.equals(id)))
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper)
        .map((entities) => entities.isNotEmpty ? entities.first : null);
    return res;
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

  Future<List<String>> entryIdsByTagId(String tagId) async {
    return entryIdsForTagId(tagId).get();
  }

  Stream<List<JournalEntity>> watchJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    int limit = 500,
  }) {
    if (ids != null) {
      return filteredByTagJournal(
        types,
        ids,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
      ).watch().where(makeDuplicateFilter()).map(entityStreamMapper);
    } else {
      return filteredJournal(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
      ).watch().where(makeDuplicateFilter()).map(entityStreamMapper);
    }
  }

  Stream<List<JournalEntity>> watchJournalEntitiesByTag({
    required String tagId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int limit = 1000,
  }) {
    return filteredByTaggedWithId(
      tagId,
      rangeStart,
      rangeEnd,
      limit,
    ).watch().where(makeDuplicateFilter()).map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchJournalByTagIds({
    required String match,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return filteredByTagMatch(
      '%$match%',
      rangeStart,
      rangeEnd,
    ).watch().where(makeDuplicateFilter()).map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    List<String>? ids,
    int limit = 1000,
  }) {
    final types = <String>['Task'];
    if (ids != null) {
      return filteredTasksByTag(
        types,
        ids,
        starredStatuses,
        taskStatuses,
        limit,
      ).watch().where(makeDuplicateFilter()).map(entityStreamMapper);
    } else {
      return filteredTasks(types, starredStatuses, taskStatuses, limit)
          .watch()
          .where(makeDuplicateFilter())
          .map(entityStreamMapper);
    }
  }

  Future<int> getWipCount() async {
    final res =
        await filteredTasks(['Task'], [true, false], ['IN PROGRESS'], 1000)
            .get();
    return res.length;
  }

  Stream<List<JournalEntity>> watchLinkedEntities({
    required String linkedFrom,
  }) {
    return linkedJournalEntities(linkedFrom)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  FutureOr<List<String>> getSortedLinkedEntityIds(
    List<String> linkedIds,
  ) async {
    final dbEntities = await journalEntitiesByIds(linkedIds).get();
    return dbEntities.map((dbEntity) => dbEntity.id).toList();
  }

  // Returns stream with a sorted list of items IDs linked to from the
  // provided item id.
  Stream<List<String>> watchLinkedEntityIds(String linkedFrom) {
    return linkedJournalEntityIds(linkedFrom)
        .watch()
        .where(makeDuplicateFilter())
        .asyncMap(getSortedLinkedEntityIds)
        .where(makeDuplicateFilter());
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final dbEntities = await linkedJournalEntities(linkedFrom).get();
    return dbEntities.map(fromDbEntity).toList();
  }

  Stream<Map<String, Duration>> watchLinkedTotalDuration({
    required String linkedFrom,
  }) {
    return watchLinkedEntities(
      linkedFrom: linkedFrom,
    ).map((
      List<JournalEntity> items,
    ) {
      final durations = <String, Duration>{};
      for (final journalEntity in items) {
        if (journalEntity is! Task) {
          final duration = entryDuration(journalEntity);
          durations[journalEntity.meta.id] = duration;
        }
      }
      return durations;
    });
  }

  Stream<List<JournalEntity>> watchLinkedToEntities({
    required String linkedTo,
  }) {
    return linkedToJournalEntities(linkedTo)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchFlaggedImport({
    int limit = 1000,
  }) {
    return entriesFlaggedImport(limit)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<int> watchJournalCount() {
    return countJournalEntries()
        .watch()
        .where(makeDuplicateFilter())
        .map((List<int> res) => res.first);
  }

  Stream<int> watchTaskCount(String status) {
    return filteredTasks(['Task'], [true, false], [status], 10000)
        .watch()
        .where(makeDuplicateFilter())
        .map((res) => res.length);
  }

  Stream<int> watchTaggedCount() {
    return countTagged()
        .watch()
        .where(makeDuplicateFilter())
        .map((List<int> res) => res.first);
  }

  Future<int> getJournalCount() async {
    return (await countJournalEntries().get()).first;
  }

  Stream<Set<ConfigFlag>> watchConfigFlags() {
    return listConfigFlags()
        .watch()
        .where(makeDuplicateFilter())
        .map((flags) => flags.toSet());
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

  Future<void> purgeDeleted({bool backup = true}) async {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    await purgeDeletedDashboards();
    await purgeDeletedMeasurables();
    await purgeDeletedTagEntities();
    await purgeDeletedJournalEntities();
  }

  Future<bool> getConfigFlag(String flagName) async {
    final flags = await listConfigFlags().get();
    return findConfigFlag(flagName, flags);
  }

  Stream<bool> watchConfigFlag(String flagName) {
    return listConfigFlags()
        .watch()
        .where(makeDuplicateFilter())
        .map((List<ConfigFlag> flags) {
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

  Future<void> setConfigFlag(String flagName, {required bool value}) async {
    final configFlag = await getConfigFlagByName(flagName);

    if (configFlag != null) {
      await upsertConfigFlag(configFlag.copyWith(status: value));
    }
  }

  Future<int> getCountImportFlagEntries() async {
    final res = await countImportFlagEntries().get();
    return res.first;
  }

  Stream<int> watchCountImportFlagEntries() {
    return countImportFlagEntries()
        .watch()
        .where(makeDuplicateFilter())
        .map((event) => event.first);
  }

  Stream<List<MeasurableDataType>> watchMeasurableDataTypes() {
    return activeMeasurableTypes()
        .watch()
        .where(makeDuplicateFilter())
        .map(measurableDataTypeStreamMapper);
  }

  Stream<MeasurableDataType?> watchMeasurableDataTypeById(String id) {
    return measurableTypeById(id)
        .watch()
        .where(makeDuplicateFilter())
        .map(measurableDataTypeStreamMapper)
        .map((List<MeasurableDataType> res) => res.firstOrNull);
  }

  Future<MeasurableDataType?> getMeasurableDataTypeById(String id) async {
    final res = await measurableTypeById(id).get();
    return res.map(measurableDataType).firstOrNull;
  }

  Stream<List<JournalEntity>> watchMeasurementsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return measurementsByType(type, rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchHabitCompletionsByHabitId({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return habitCompletionsByHabitId(habitId, rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchHabitCompletionsInRange({
    required DateTime rangeStart,
  }) {
    return habitCompletionsInRange(rangeStart)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchQuantitativeByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return quantitativeByType(type, rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
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

  Stream<List<JournalEntity>> watchSurveysByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return surveysByType(type, rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchQuantitativeByTypes({
    required List<String> types,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return quantitativeByTypes(types, rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchWorkouts({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return workouts(rangeStart, rangeEnd)
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper);
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit)
        .watch()
        .where(makeDuplicateFilter());
  }

  Stream<List<Conflict>> watchConflictById(String id) {
    return conflictsById(id).watch();
  }

  Stream<List<TagEntity>> watchTags() {
    return allTagEntities()
        .watch()
        .where(makeDuplicateFilter())
        .map(tagStreamMapper);
  }

  Stream<List<DashboardDefinition>> watchDashboards() {
    return allDashboards()
        .watch()
        .where(makeDuplicateFilter())
        .map(dashboardStreamMapper);
  }

  Stream<List<DashboardDefinition>> watchDashboardById(String id) {
    return dashboardById(id)
        .watch()
        .where(makeDuplicateFilter())
        .map(dashboardStreamMapper);
  }

  Stream<List<HabitDefinition>> watchHabitDefinitions() {
    return allHabitDefinitions()
        .watch()
        .where(makeDuplicateFilter())
        .map(habitDefinitionsStreamMapper);
  }

  Stream<HabitDefinition?> watchHabitById(String id) {
    return habitById(id)
        .watch()
        .where(makeDuplicateFilter())
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

  Stream<List<TagEntity>> watchMatchingTags(
    String match, {
    int limit = 10,
    bool inactive = false,
  }) {
    return matchingTagEntities('%$match%', inactive, limit).watch().map(
          (dbEntities) => dbEntities.map(fromTagDbEntity).toList(),
        );
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

  Future<List<String>> linksForEntryId(String entryId) {
    return linkedEntriesFor(entryId).get();
  }

  Future<int> upsertEntryLink(EntryLink link) async {
    if (link.fromId != link.toId) {
      return into(linkedEntries).insertOnConflictUpdate(linkedDbEntity(link));
    } else {
      return 0;
    }
  }

  Future<int> removeLink({
    required String fromId,
    required String toId,
  }) async {
    return deleteLink(fromId, toId);
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    final linesAffected = await entityDefinition.map(
      measurableDataType: (MeasurableDataType measurableDataType) async {
        return upsertMeasurableDataType(measurableDataType);
      },
      habit: upsertHabitDefinition,
      dashboard: upsertDashboardDefinition,
    );
    return linesAffected;
  }
}

JournalDb getJournalDb() {
  return JournalDb.connect(getDatabaseConnection(journalDbFileName));
}
