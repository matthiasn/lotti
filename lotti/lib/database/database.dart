import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
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
  int get schemaVersion => 12;

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
          debugPrint('Add tag_definitions inactive column');
          await m.addColumn(tagDefinitions, tagDefinitions.inactive);
          await m.createIndex(idxTagDefinitionsInactive);
        }();

        () async {
          debugPrint('Creating journal_tags table and indices');
          await m.createTable(journalTags);
          await m.createIndex(idxJournalTagsJournalId);
          await m.createIndex(idxJournalTagsTagDefinitionId);
        }();

        () async {
          debugPrint('Add missing column in tag_definitions table');
          await m.addColumn(tagDefinitions, tagDefinitions.deleted);
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
      debugPrint('PersistenceDb already exists: ${dbEntity.id}');
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

  Future<void> addTagLinks(JournalEntity journalEntity) async {
    String id = journalEntity.meta.id;
    List<String> tagIds = journalEntity.meta.tagIds ?? [];
    debugPrint('addTagLinks: $id $tagIds');

    await deleteJournalTagLinksForId(id);

    for (String tagId in tagIds) {
      into(journalTags).insert(JournalTagLink(
        id: uuid.v1(),
        journalId: id,
        tagDefinitionId: tagId,
      ));
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
  }

  Stream<JournalEntity?> watchEntityById(String id) {
    Stream<JournalEntity?> res = (select(journal)
          ..where((t) => t.id.equals(id)))
        .watch()
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
  }

  Future<JournalEntity?> journalEntityById(String id) async {
    JournalDbEntity? dbEntity = await entityById(id);
    if (dbEntity != null) {
      return fromDbEntity(dbEntity);
    }
  }

  Future<List<String>> entryIdsByTagId(String tagId) async {
    return entryIdsForTagId(tagId).get();
  }

  Stream<List<JournalEntity>> watchJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String>? ids,
    int limit = 1000,
  }) {
    if (ids != null) {
      return filteredByTagJournal(
              types, ids, starredStatuses, privateStatuses, limit)
          .watch()
          .map(entityStreamMapper);
    } else {
      return filteredJournal(types, starredStatuses, privateStatuses, limit)
          .watch()
          .map(entityStreamMapper);
    }
  }

  Stream<List<JournalEntity>> watchFlaggedImport({
    int limit = 1000,
  }) {
    return entriesFlaggedImport(limit).watch().map(entityStreamMapper);
  }

  Stream<int> watchJournalCount() {
    return countJournalEntries().watch().map((List<int> res) => res.first);
  }

  Future<int> getJournalCount() async {
    return (await countJournalEntries().get()).first;
  }

  Stream<List<ConfigFlag>> watchConfigFlags() {
    return listConfigFlags().watch();
  }

  Future<void> initConfigFlags() async {
    into(configFlags).insert(ConfigFlag(
      name: 'private',
      description: 'Show private entries?',
      status: true,
    ));
  }

  Future<List<ConfigFlag>> getConfigFlags() {
    return listConfigFlags().get();
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    return into(configFlags).insertOnConflictUpdate(configFlag);
  }

  Future<int> getCountImportFlagEntries() async {
    List<int> res = await countImportFlagEntries().get();
    return res.first;
  }

  Stream<int> watchCountImportFlagEntries() {
    return countImportFlagEntries().watch().map((event) => event.first);
  }

  Stream<List<MeasurableDataType>> watchMeasurableDataTypes() {
    return activeMeasurableTypes().watch().map(measurableDataTypeStreamMapper);
  }

  Stream<List<JournalEntity>> watchMeasurementsByType(
    String type,
    DateTime from,
  ) {
    return measurementsByType(type, from).watch().map(entityStreamMapper);
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit).watch();
  }

  Stream<List<TagDefinition>> watchTags() {
    return allTagDefinitions().watch().map(tagDefinitionsStreamMapper);
  }

  Stream<List<HabitDefinition>> watchHabitDefinitions() {
    return allHabitDefinitions().watch().map(habitDefinitionsStreamMapper);
  }

  Future<List<TagDefinition>> getMatchingTags(
    String match, {
    int limit = 10,
    bool inactive = false,
  }) async {
    return (await matchingTagDefinitions('%$match%', inactive, limit).get())
        .map((dbEntity) => fromTagDefinitionDbEntity(dbEntity))
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

  Future<int> upsertTagDefinition(TagDefinition tagDefinition) async {
    final TagDefinitionDbEntity dbEntity = tagDefinitionDbEntity(tagDefinition);
    // would not update with insertOnConflictUpdate
    return into(tagDefinitions).insert(dbEntity, mode: InsertMode.replace);
  }

  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) async {
    return into(habitDefinitions)
        .insertOnConflictUpdate(habitDefinitionDbEntity(habitDefinition));
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    int linesAffected = await entityDefinition.map(
      measurableDataType: (MeasurableDataType measurableDataType) async {
        return upsertMeasurableDataType(measurableDataType);
      },
      tagDefinition: (TagDefinition tagDefinition) async {
        return upsertTagDefinition(tagDefinition);
      },
      habitDefinition: (HabitDefinition habitDefinition) {
        return upsertHabitDefinition(habitDefinition);
      },
    );
    return linesAffected;
  }

  Future<void> recreateJournalTagLinks() async {
    deleteJournalTagLinks();
    int count = await getJournalCount();
    int pageSize = 100;
    int pages = (count / pageSize).ceil();

    for (int page = 0; page <= pages; page++) {
      List<JournalDbEntity> dbEntities =
          await orderedJournal(pageSize, page * pageSize).get();

      List<JournalEntity> entries = entityStreamMapper(dbEntities);
      for (JournalEntity entry in entries) {
        await addTagLinks(entry);
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
