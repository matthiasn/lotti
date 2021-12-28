import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/sync/vector_clock.dart';
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
  int get schemaVersion => 2;

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

  Stream<List<JournalEntity>> watchJournalEntities({
    required List<String> types,
    int limit = 1000,
  }) {
    return filteredJournal(types, limit).watch().map(entityStreamMapper);
  }

  Stream<List<MeasurableDataType>> watchMeasurableDataTypes() {
    return activeMeasurableTypes().watch().map(measurableDataTypeStreamMapper);
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit).watch();
  }

  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where((t) => t.id.equals(conflict.id)))
        .write(conflict.copyWith(status: ConflictStatus.resolved.index));
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    return into(measurableTypes)
        .insertOnConflictUpdate(measurableDbEntity(entityDefinition));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
