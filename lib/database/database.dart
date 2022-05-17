import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/stream_helpers.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'conversions.dart';

part 'database.g.dart';

enum ConflictStatus {
  unresolved,
  resolved,
}

@DriftDatabase(
  include: {'database.drift'},
)
class JournalDb extends _$JournalDb {
  JournalDb() : super(_openConnection());

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onCreate: (Migrator m) {
        return m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        debugPrint('Migration from v$from to v$to');

        () async {
          debugPrint('Creating habit_definitions table and indices');
          await m.createTable(habitDefinitions);
          await m.createIndex(idxHabitDefinitionsId);
          await m.createIndex(idxHabitDefinitionsName);
          await m.createIndex(idxHabitDefinitionsPrivate);
        }();

        () async {
          debugPrint('Creating dashboard_definitions table and indices');
          await m.createTable(dashboardDefinitions);
          await m.createIndex(idxDashboardDefinitionsId);
          await m.createIndex(idxDashboardDefinitionsName);
          await m.createIndex(idxDashboardDefinitionsPrivate);
        }();

        () async {
          debugPrint('Add last_reviewed column in dashboard_definitions');
          await m.addColumn(
            dashboardDefinitions,
            dashboardDefinitions.lastReviewed,
          );
        }();

        () async {
          debugPrint('Creating tagged table and indices');
          await m.createTable(tagged);
          await m.createIndex(idxTaggedJournalId);
          await m.createIndex(idxTaggedTagEntityId);
        }();

        () async {
          debugPrint('Creating task columns and indices');
          await m.addColumn(journal, journal.taskStatus);
          await m.createIndex(idxJournalTaskStatus);
          await m.addColumn(journal, journal.task);
          await m.createIndex(idxJournalTask);
        }();

        () async {
          debugPrint('Creating linked entries table and indices');
          await m.createTable(linkedEntries);
          await m.createIndex(idxLinkedEntriesFromId);
          await m.createIndex(idxLinkedEntriesToId);
          await m.createIndex(idxLinkedEntriesType);
        }();

        () async {
          debugPrint('Creating tag_entities table and indices');
          await m.createTable(tagEntities);
          await m.createIndex(idxTagEntitiesId);
          await m.createIndex(idxTagEntitiesTag);
          await m.createIndex(idxTagEntitiesType);
          await m.createIndex(idxTagEntitiesInactive);
          await m.createIndex(idxTagEntitiesPrivate);
        }();

        () async {
          debugPrint('Remove journal_tags table');
          await m.deleteTable('journal_tags');
        }();

        () async {
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
    JournalDbEntity dbEntity = toDbEntity(journalEntity);

    bool exists = (await entityById(dbEntity.id)) != null;
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
    VectorClock? vcA = existing.meta.vectorClock;
    VectorClock? vcB = updated.meta.vectorClock;

    if (vcA != null && vcB != null) {
      VclockStatus status = VectorClock.compare(vcA, vcB);

      if (status == VclockStatus.concurrent) {
        debugPrint('Conflicting vector clocks: $status');
        DateTime now = DateTime.now();
        await addConflict(Conflict(
          id: updated.meta.id,
          createdAt: now,
          updatedAt: now,
          serialized: jsonEncode(updated),
          schemaVersion: schemaVersion,
          status: ConflictStatus.unresolved.index,
        ));
      }

      return status;
    }
    return VclockStatus.b_gt_a;
  }

  Future<void> insertTag(String id, String tagId) async {
    try {
      await into(tagged).insert(TaggedWith(
        id: uuid.v1(),
        journalId: id,
        tagEntityId: tagId,
      ));
    } catch (ex) {
      debugPrint(ex.toString());
    }
  }

  Future<void> addTagged(JournalEntity journalEntity) async {
    String id = journalEntity.meta.id;
    List<String> tagIds = journalEntity.meta.tagIds ?? [];
    await deleteTaggedForId(id);

    for (String tagId in tagIds) {
      insertTag(id, tagId);
    }
  }

  Future<int> updateJournalEntity(JournalEntity updated) async {
    int rowsAffected = 0;
    JournalDbEntity dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    JournalDbEntity? existingDbEntity = await entityById(dbEntity.id);
    if (existingDbEntity != null) {
      JournalEntity existing = fromDbEntity(existingDbEntity);
      VclockStatus status = await detectConflict(existing, updated);
      debugPrint('Conflict status: ${EnumToString.convertToString(status)}');

      if (status == VclockStatus.b_gt_a) {
        rowsAffected = await upsertJournalDbEntity(dbEntity);

        Conflict? existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else {}
    } else {
      rowsAffected = await upsertJournalDbEntity(dbEntity);
    }
    return rowsAffected;
  }

  Future<JournalDbEntity?> entityById(String id) async {
    List<JournalDbEntity> res =
        await (select(journal)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Stream<JournalEntity?> watchEntityById(String id) {
    Stream<JournalEntity?> res = (select(journal)
          ..where((t) => t.id.equals(id)))
        .watch()
        .where(makeDuplicateFilter())
        .map(entityStreamMapper)
        .map((event) => event.first);
    return res;
  }

  Future<Conflict?> conflictById(String id) async {
    List<Conflict> res =
        await (select(conflicts)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<JournalEntity?> journalEntityById(String id) async {
    JournalDbEntity? dbEntity = await entityById(id);
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
    int limit = 1000,
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

  Stream<List<JournalEntity>> watchTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    List<String>? ids,
    int limit = 1000,
  }) {
    List<String> types = ['Task'];
    if (ids != null) {
      return filteredTasksByTag(
              types, ids, starredStatuses, taskStatuses, limit)
          .watch()
          .where(makeDuplicateFilter())
          .map(entityStreamMapper);
    } else {
      return filteredTasks(types, starredStatuses, taskStatuses, limit)
          .watch()
          .where(makeDuplicateFilter())
          .map(entityStreamMapper);
    }
  }

  Future<int> getWipCount() async {
    List<JournalDbEntity> res =
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
      List<String> linkedIds) async {
    var dbEntities = await journalEntitiesByIds(linkedIds).get();
    return dbEntities.map((dbEntity) => dbEntity.id).toList();
  }

  // Returns stream with a sorted list of items IDs linked to from the
  // provided item id.
  Stream<List<String>> watchLinkedEntityIds(String linkedFrom) {
    return linkedJournalEntityIds(linkedFrom)
        .watch()
        .where(makeDuplicateFilter())
        .asyncMap((List<String> itemIds) {
      return getSortedLinkedEntityIds(itemIds);
    }).where(makeDuplicateFilter());
  }

  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    var dbEntities = await linkedJournalEntities(linkedFrom).get();
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
      Map<String, Duration> durations = {};
      for (JournalEntity journalEntity in items) {
        if (journalEntity is! Task) {
          Duration duration = entryDuration(journalEntity);
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

  Stream<List<ConfigFlag>> watchConfigFlags() {
    return listConfigFlags().watch().where(makeDuplicateFilter());
  }

  Future<List<ConfigFlag>> getConfigFlags() {
    return listConfigFlags().get();
  }

  Future<bool> getConfigFlag(String flagName) async {
    bool flag = false;
    List<ConfigFlag> flags = await listConfigFlags().get();
    for (ConfigFlag configFlag in flags) {
      if (configFlag.name == flagName) {
        flag = configFlag.status;
      }
    }

    return flag;
  }

  Future<ConfigFlag?> getConfigFlagByName(String flagName) async {
    List<ConfigFlag> flags = await configFlagByName(flagName).get();

    if (flags.isNotEmpty) {
      return flags.first;
    }
    return null;
  }

  Future<void> insertFlagIfNotExists(ConfigFlag configFlag) async {
    ConfigFlag? existing = await getConfigFlagByName(configFlag.name);

    if (existing == null) {
      into(configFlags).insert(configFlag);
    }
  }

  Future<void> initConfigFlags() async {
    insertFlagIfNotExists(
      ConfigFlag(
        name: 'private',
        description: 'Show private entries?',
        status: true,
      ),
    );
    insertFlagIfNotExists(
      ConfigFlag(
        name: 'notify_exceptions',
        description: 'Notify when exceptions occur?',
        status: false,
      ),
    );
    insertFlagIfNotExists(
      ConfigFlag(
        name: 'hide_for_screenshot',
        description: 'Hide Lotti when taking screenshots?',
        status: true,
      ),
    );
    if (Platform.isMacOS) {
      insertFlagIfNotExists(
        ConfigFlag(
          name: 'listen_to_global_screenshot_hotkey',
          description: 'Listen to global screenshot hotkey?',
          status: true,
        ),
      );
      insertFlagIfNotExists(
        ConfigFlag(
          name: 'enable_notifications',
          description: 'Enable desktop notifications?',
          status: false,
        ),
      );
    }
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    return into(configFlags).insertOnConflictUpdate(configFlag);
  }

  Future<int> getCountImportFlagEntries() async {
    List<int> res = await countImportFlagEntries().get();
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
    var res = await measurableTypeById(id).get();
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
    var dbEntities = await latestQuantByType(type).get();
    if (dbEntities.isEmpty) {
      debugPrint('latestQuantitativeByType no result for $type');
      return null;
    }
    return fromDbEntity(dbEntities.first) as QuantitativeEntry;
  }

  Future<WorkoutEntry?> latestWorkout() async {
    var dbEntities = await findLatestWorkout().get();
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

  Future<List<TagEntity>> getMatchingTags(
    String match, {
    int limit = 10,
    bool inactive = false,
  }) async {
    return (await matchingTagEntities('%$match%', inactive, limit).get())
        .map((dbEntity) => fromTagDbEntity(dbEntity))
        .toList();
  }

  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where((t) => t.id.equals(conflict.id)))
        .write(conflict.copyWith(status: ConflictStatus.resolved.index));
  }

  Future<int> upsertMeasurableDataType(
      MeasurableDataType entityDefinition) async {
    return into(measurableTypes)
        .insertOnConflictUpdate(measurableDbEntity(entityDefinition));
  }

  Future<int> upsertTagEntity(TagEntity tag) async {
    final TagDbEntity dbEntity = tagDbEntity(tag);
    return into(tagEntities).insertOnConflictUpdate(dbEntity);
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) async {
    return into(habitDefinitions)
        .insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition));
  }

  Future<int> upsertDashboardDefinition(
      DashboardDefinition dashboardDefinition) async {
    return into(dashboardDefinitions).insertOnConflictUpdate(
        dashboardDefinitionDbEntity(dashboardDefinition));
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
    int linesAffected = await entityDefinition.map(
      measurableDataType: (MeasurableDataType measurableDataType) async {
        return upsertMeasurableDataType(measurableDataType);
      },
      habit: (HabitDefinition habitDefinition) {
        return upsertHabitDefinition(habitDefinition);
      },
      dashboard: (DashboardDefinition dashboardDefinition) {
        return upsertDashboardDefinition(dashboardDefinition);
      },
    );
    return linesAffected;
  }
}

Future<File> getDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'db.sqlite'));
}

Future<void> createDbBackup() async {
  final File file = await getDatabaseFile();
  String ts = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(DateTime.now());
  Directory backupDir =
      await Directory('${file.parent.path}/backup').create(recursive: true);
  await file.copy('${backupDir.path}/db.$ts.sqlite');
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final File file = await getDatabaseFile();
    return NativeDatabase(file);
  });
}
