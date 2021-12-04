import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DriftDatabase(
  include: {'tables.drift'},
)
class JournalDb extends _$JournalDb {
  JournalDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> addJournalDbEntity(JournalDbEntity entry) async {
    return into(journal).insert(entry);
  }

  Future<int?> addJournalEntity(JournalEntity journalEntity) async {
    JournalDbEntity dbEntity = toDbEntity(journalEntity);

    bool exists = await entityById(dbEntity.id) != null;
    if (!exists) {
      return addJournalDbEntity(dbEntity);
    } else {
      debugPrint('PersistenceDb already exists: ${dbEntity.id}');
    }
  }

  JournalDbEntity toDbEntity(JournalEntity journalEntity) {
    final DateTime createdAt = journalEntity.meta.createdAt;
    final subtype = journalEntity.maybeMap(
      quantitative: (qd) => qd.data.dataType,
      survey: (SurveyEntry surveyEntry) =>
          surveyEntry.data.taskResult.identifier,
      orElse: () => '',
    );

    Geolocation? geolocation;
    journalEntity.mapOrNull(
      journalAudio: (item) => geolocation = item.geolocation,
      journalImage: (item) => geolocation = item.geolocation,
      journalEntry: (item) => geolocation = item.geolocation,
    );

    String id = journalEntity.meta.id;
    JournalDbEntity dbEntity = JournalDbEntity(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      dateFrom: journalEntity.meta.dateFrom,
      dateTo: journalEntity.meta.dateTo,
      type: journalEntity.runtimeType.toString(),
      subtype: subtype,
      serialized: json.encode(journalEntity),
      schemaVersion: 0,
      longitude: geolocation?.longitude,
      latitude: geolocation?.latitude,
      geohashString: geolocation?.geohashString,
    );

    return dbEntity;
  }

  Future<int> updateJournalEntity(JournalEntity journalEntity) async {
    JournalDbEntity dbEntity = toDbEntity(journalEntity).copyWith(
      updatedAt: DateTime.now(),
    );

    bool exists = await entityById(dbEntity.id) != null;
    if (exists) {
      return (update(journal)..where((t) => t.id.equals(dbEntity.id)))
          .write(dbEntity);
    } else {
      return addJournalDbEntity(dbEntity);
    }
  }

  Future<List<JournalDbEntity>> latestDbEntities(int limit) async {
    return (select(journal)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.dateFrom,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .get();
  }

  Future<JournalDbEntity?> entityById(String id) async {
    List<JournalDbEntity> res =
        await (select(journal)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
  }

  Future<List<JournalEntity>> latestJournalEntities(int limit) async {
    List<JournalDbEntity> dbEntities = await latestDbEntities(limit);
    return dbEntities
        .map((JournalDbEntity dbEntity) =>
            JournalEntity.fromJson(json.decode(dbEntity.serialized)))
        .toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
