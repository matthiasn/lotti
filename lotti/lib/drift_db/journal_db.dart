import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'journal_db.g.dart';

@DriftDatabase(
  include: {'journal_tables.drift'},
)
class JournalDb extends _$JournalDb {
  JournalDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> addJournalEntry(JournalDbEntity entry) {
    return into(journal).insert(entry);
  }

  Future<int> addJournalEntity(JournalEntity journalEntity) async {
    JournalDbEntity dbEntity = toDbEntity(journalEntity);
    return into(journal).insert(dbEntity);
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

  Future<int> updateJournalEntity(JournalEntity journalEntity) {
    JournalDbEntity dbEntity = toDbEntity(journalEntity).copyWith(
      updatedAt: DateTime.now(),
    );

    return (update(journal)..where((t) => t.id.equals(dbEntity.id)))
        .write(dbEntity);
  }

  Future<List<JournalDbEntity>> latestEntries(int limit) {
    return (select(journal)
          ..orderBy([(t) => OrderingTerm(expression: t.dateFrom)])
          ..limit(limit))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
