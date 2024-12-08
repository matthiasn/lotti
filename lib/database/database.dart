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
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';

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
  int get schemaVersion => 21;

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
            await m.createIndex(idxJournalCategory);
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
  }) async {
    var rowsAffected = 0;
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    final existingDbEntity = await entityById(dbEntity.id);
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
        getIt<LoggingDb>().captureEvent(
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

  Stream<JournalEntity?> watchEntityById(String id) {
    final res = (select(journal)..where((t) => t.id.equals(id)))
        .watch()
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

  Future<List<JournalEntity>> getJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    final res = await _selectJournalEntities(
      types: types,
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      flaggedStatuses: flaggedStatuses,
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesForIds(
    Set<String> ids,
  ) async {
    final res = await entriesForIds(ids.toList()).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<String>> getJournalEntityIds({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    return _selectJournalEntityIds(
      types: types,
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      flaggedStatuses: flaggedStatuses,
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();
  }

  Selectable<JournalDbEntity> _selectJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
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

  Selectable<String> _selectJournalEntityIds({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    if (ids != null) {
      return filteredJournalIds2(
        types,
        ids,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
    } else {
      return filteredJournalIds(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
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
    ).watch().map(entityStreamMapper);
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
    ).watch().map(entityStreamMapper);
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

  Future<List<String>> getTasksIds({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    return _selectTaskIds(
      starredStatuses: starredStatuses,
      taskStatuses: taskStatuses,
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();
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

  Selectable<String> _selectTaskIds({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    final types = <String>['Task'];
    if (ids != null) {
      return filteredTaskIds2(
        types,
        ids,
        starredStatuses,
        taskStatuses,
        limit,
        offset,
      );
    } else {
      return filteredTaskIds(
        types,
        starredStatuses,
        taskStatuses,
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

  Stream<List<JournalEntity>> watchLinkedEntities({
    required String linkedFrom,
  }) {
    return linkedJournalEntities(linkedFrom).watch().map(entityStreamMapper);
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
        .asyncMap(getSortedLinkedEntityIds);
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final dbEntities = await linkedJournalEntities(linkedFrom).get();
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> sortedJournalEntities({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final dbEntities = await sortedInRange(rangeStart, rangeEnd).get();
    return dbEntities.map(fromDbEntity).toList();
  }

  Stream<List<JournalEntity>> watchLinkedToEntities({
    required String linkedTo,
  }) {
    return linkedToJournalEntities(linkedTo).watch().map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchFlaggedImport({
    int limit = 1000,
  }) {
    return entriesFlaggedImport(limit).watch().map(entityStreamMapper);
  }

  Stream<int> watchJournalCount() {
    return countJournalEntries().watch().map((List<int> res) => res.first);
  }

  Stream<int> watchTaskCount(String status) {
    return _selectTasks(
      starredStatuses: [true, false],
      taskStatuses: [status],
      categoryIds: [''],
      limit: 100000,
    ).watch().map((res) => res.length);
  }

  Stream<int> watchTaggedCount() {
    return countTagged().watch().map((List<int> res) => res.first);
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
    return countImportFlagEntries().watch().map((event) => event.first);
  }

  Stream<int> watchInProgressTasksCount() {
    return countInProgressTasks(['IN PROGRESS'])
        .watch()
        .map((event) => event.first);
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

  Stream<List<JournalEntity>> watchMeasurementsByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return measurementsByType(type, rangeStart, rangeEnd)
        .watch()
        .map(entityStreamMapper);
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

  Stream<List<JournalEntity>> watchHabitCompletionsInRange({
    required DateTime rangeStart,
  }) {
    return habitCompletionsInRange(rangeStart).watch().map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchQuantitativeByType({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return quantitativeByType(type, rangeStart, rangeEnd)
        .watch()
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
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchQuantitativeByTypes({
    required List<String> types,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return quantitativeByTypes(types, rangeStart, rangeEnd)
        .watch()
        .map(entityStreamMapper);
  }

  Stream<List<JournalEntity>> watchWorkouts({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return workouts(rangeStart, rangeEnd).watch().map(entityStreamMapper);
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
      final res =
          into(linkedEntries).insertOnConflictUpdate(linkedDbEntity(link));
      return res;
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
      categoryDefinition: upsertCategoryDefinition,
    );
    return linesAffected;
  }
}
