import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';

import 'database.dart';

JournalDbEntity toDbEntity(JournalEntity entity) {
  final DateTime createdAt = entity.meta.createdAt;
  final String subtype = entity.maybeMap(
    quantitative: (QuantitativeEntry entry) => entry.data.dataType,
    measurement: (MeasurementEntry entry) =>
        entry.data.dataType.name.toLowerCase(),
    survey: (SurveyEntry entry) =>
        entry.data.taskResult.identifier.toLowerCase(),
    workout: (WorkoutEntry entry) => entry.data.workoutType,
    orElse: () => '',
  );

  final bool task = entity.maybeMap(
    task: (qd) => true,
    orElse: () => false,
  );

  Geolocation? geolocation;
  entity.mapOrNull(
    journalAudio: (item) => geolocation = item.geolocation,
    journalImage: (item) => geolocation = item.geolocation,
    journalEntry: (item) => geolocation = item.geolocation,
    measurement: (item) => geolocation = item.geolocation,
    task: (item) => geolocation = item.geolocation,
  );

  final String taskStatus = entity.maybeMap(
    task: (task) => task.data.status.map(
      open: (_) => 'OPEN',
      started: (_) => 'STARTED',
      inProgress: (_) => 'IN PROGRESS',
      blocked: (_) => 'BLOCKED',
      onHold: (_) => 'ON HOLD',
      done: (_) => 'DONE',
      rejected: (_) => 'REJECTED',
    ),
    orElse: () => '',
  );

  String id = entity.meta.id;
  JournalDbEntity dbEntity = JournalDbEntity(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    dateFrom: entity.meta.dateFrom,
    deleted: entity.meta.deletedAt != null,
    starred: entity.meta.starred ?? false,
    private: entity.meta.private ?? false,
    flag: entity.meta.flag?.index ?? 0,
    task: task,
    taskStatus: taskStatus,
    dateTo: entity.meta.dateTo,
    type: entity.runtimeType.toString().replaceFirst(r'_$', ''),
    subtype: subtype,
    serialized: json.encode(entity),
    schemaVersion: 0,
    longitude: geolocation?.longitude,
    latitude: geolocation?.latitude,
    geohashString: geolocation?.geohashString,
  );

  return dbEntity;
}

JournalEntity fromSerialized(String serialized) {
  return JournalEntity.fromJson(json.decode(serialized));
}

JournalEntity fromDbEntity(JournalDbEntity dbEntity) {
  return fromSerialized(dbEntity.serialized);
}

List<JournalEntity> entityStreamMapper(List<JournalDbEntity> dbEntities) {
  return dbEntities.map((e) => fromDbEntity(e)).toList();
}

MeasurableDataType measurableDataType(MeasurableDbEntity dbEntity) {
  return MeasurableDataType.fromJson(json.decode(dbEntity.serialized));
}

List<MeasurableDataType> measurableDataTypeStreamMapper(
    List<MeasurableDbEntity> dbEntities) {
  return dbEntities.map((e) => measurableDataType(e)).toList();
}

MeasurableDbEntity measurableDbEntity(MeasurableDataType dataType) {
  return MeasurableDbEntity(
    id: dataType.id,
    uniqueName: dataType.name,
    createdAt: dataType.createdAt,
    updatedAt: dataType.updatedAt,
    serialized: jsonEncode(dataType),
    version: dataType.version,
    status: 0,
    private: dataType.private ?? false,
    deleted: dataType.deletedAt != null,
  );
}

TagDbEntity tagDbEntity(TagEntity tag) {
  return TagDbEntity(
    id: tag.id,
    tag: tag.tag,
    private: tag.private,
    inactive: tag.inactive ?? false,
    createdAt: tag.createdAt,
    updatedAt: tag.updatedAt,
    serialized: jsonEncode(tag),
    deleted: tag.deletedAt != null,
    type: tag.map(
        genericTag: (_) => 'GenericTag',
        personTag: (_) => 'PersonTag',
        storyTag: (_) => 'StoryTag'),
  );
}

HabitDefinitionDbEntity habitDefinitionDbEntity(HabitDefinition habit) {
  return HabitDefinitionDbEntity(
    id: habit.id,
    createdAt: habit.createdAt,
    updatedAt: habit.updatedAt,
    serialized: jsonEncode(habit),
    private: habit.private,
    deleted: habit.deletedAt != null,
    active: habit.active,
    name: habit.name,
  );
}

DashboardDefinitionDbEntity dashboardDefinitionDbEntity(
  DashboardDefinition dashboard,
) {
  return DashboardDefinitionDbEntity(
    id: dashboard.id,
    createdAt: dashboard.createdAt,
    updatedAt: dashboard.updatedAt,
    lastReviewed: dashboard.lastReviewed,
    serialized: jsonEncode(dashboard),
    private: dashboard.private,
    deleted: dashboard.deletedAt != null,
    active: dashboard.active,
    name: dashboard.name,
  );
}

LinkedDbEntry linkedDbEntity(EntryLink link) {
  return LinkedDbEntry(
    id: link.id,
    serialized: jsonEncode(link),
    fromId: link.fromId,
    toId: link.toId,
    type: link.map(
      basic: (_) => 'BasicLink',
    ),
  );
}

EntryLink entryLinkFromDbEntity(LinkedDbEntry dbEntity) {
  return EntryLink.fromJson(json.decode(dbEntity.serialized));
}

TagEntity fromTagDbEntity(TagDbEntity dbEntity) {
  return TagEntity.fromJson(json.decode(dbEntity.serialized));
}

DashboardDefinition fromDashboardDbEntity(
    DashboardDefinitionDbEntity dbEntity) {
  return DashboardDefinition.fromJson(json.decode(dbEntity.serialized));
}

List<TagEntity> tagStreamMapper(List<TagDbEntity> dbEntities) {
  return dbEntities.map((e) => fromTagDbEntity(e)).toList();
}

List<DashboardDefinition> dashboardStreamMapper(
    List<DashboardDefinitionDbEntity> dbEntities) {
  return dbEntities.map((e) => fromDashboardDbEntity(e)).toList();
}

HabitDefinition fromHabitDefinitionDbEntity(HabitDefinitionDbEntity dbEntity) {
  return HabitDefinition.fromJson(json.decode(dbEntity.serialized));
}

List<HabitDefinition> habitDefinitionsStreamMapper(
    List<HabitDefinitionDbEntity> dbEntities) {
  return dbEntities.map((e) => fromHabitDefinitionDbEntity(e)).toList();
}
