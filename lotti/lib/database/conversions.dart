import 'dart:convert';

import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';

import 'database.dart';

JournalDbEntity toDbEntity(JournalEntity journalEntity) {
  final DateTime createdAt = journalEntity.meta.createdAt;
  final subtype = journalEntity.maybeMap(
    quantitative: (qd) => qd.data.dataType,
    survey: (SurveyEntry surveyEntry) => surveyEntry.data.taskResult.identifier,
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

JournalEntity fromDbEntity(JournalDbEntity dbEntity) {
  return JournalEntity.fromJson(json.decode(dbEntity.serialized));
}

MeasurableDataType measurableDataType(MeasurableDbEntity dbEntity) {
  return MeasurableDataType.fromJson(json.decode(dbEntity.serialized));
}

MeasurableDbEntity measurableDbEntity(EntityDefinition dataType) {
  return MeasurableDbEntity(
    id: dataType.id,
    uniqueName: dataType.name,
    createdAt: dataType.createdAt,
    updatedAt: dataType.updatedAt,
    serialized: jsonEncode(dataType),
    version: dataType.version,
    status: 0,
  );
}
