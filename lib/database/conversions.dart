import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';

JournalDbEntity toDbEntity(JournalEntity entity) {
  final createdAt = entity.meta.createdAt;
  final subtype = entity.maybeMap(
    quantitative: (QuantitativeEntry entry) => entry.data.dataType,
    measurement: (MeasurementEntry entry) => entry.data.dataTypeId,
    survey: (SurveyEntry entry) =>
        entry.data.taskResult.identifier.toLowerCase(),
    workout: (WorkoutEntry entry) => entry.data.workoutType,
    habitCompletion: (HabitCompletionEntry entry) => entry.data.habitId,
    orElse: () => '',
  );

  final task = entity.maybeMap(
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

  final taskStatus = entity.maybeMap(
    task: (task) => task.data.status.map(
      open: (_) => 'OPEN',
      groomed: (_) => 'GROOMED',
      started: (_) => 'STARTED',
      inProgress: (_) => 'IN PROGRESS',
      blocked: (_) => 'BLOCKED',
      onHold: (_) => 'ON HOLD',
      done: (_) => 'DONE',
      rejected: (_) => 'REJECTED',
    ),
    orElse: () => '',
  );

  final id = entity.meta.id;
  final dbEntity = JournalDbEntity(
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
    category: entity.meta.categoryId ?? '',
    dateTo: entity.meta.dateTo,
    plainText: entity.entryText?.plainText,
    type: entity.map(
      journalEntry: (_) => 'JournalEntry',
      journalImage: (_) => 'JournalImage',
      journalAudio: (_) => 'JournalAudio',
      task: (_) => 'Task',
      event: (_) => 'JournalEvent',
      checklist: (_) => 'Checklist',
      checklistItem: (_) => 'ChecklistItem',
      quantitative: (_) => 'QuantitativeEntry',
      measurement: (_) => 'MeasurementEntry',
      workout: (_) => 'WorkoutEntry',
      habitCompletion: (_) => 'HabitCompletionEntry',
      survey: (_) => 'SurveyEntry',
    ),
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
  return JournalEntity.fromJson(
    json.decode(serialized) as Map<String, dynamic>,
  );
}

JournalEntity fromDbEntity(JournalDbEntity dbEntity) {
  return fromSerialized(dbEntity.serialized);
}

List<JournalEntity> entityStreamMapper(List<JournalDbEntity> dbEntities) {
  return dbEntities.map(fromDbEntity).toList();
}

MeasurableDataType measurableDataType(MeasurableDbEntity dbEntity) {
  return MeasurableDataType.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

List<MeasurableDataType> measurableDataTypeStreamMapper(
  List<MeasurableDbEntity> items,
) {
  final res = items.map(measurableDataType).toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

  return res;
}

MeasurableDbEntity measurableDbEntity(MeasurableDataType dataType) {
  return MeasurableDbEntity(
    id: dataType.id,
    uniqueName: dataType.id,
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
      storyTag: (_) => 'StoryTag',
    ),
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
    name: dashboard.id,
  );
}

CategoryDefinitionDbEntity categoryDefinitionDbEntity(
  CategoryDefinition category,
) {
  final deleted = category.deletedAt != null;

  return CategoryDefinitionDbEntity(
    id: category.id,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
    serialized: jsonEncode(category),
    private: category.private,
    active: category.active,
    name: deleted ? category.id : category.name,
    deleted: deleted,
  );
}

LinkedDbEntry linkedDbEntity(EntryLink link) {
  return LinkedDbEntry(
    id: link.id,
    serialized: jsonEncode(link),
    fromId: link.fromId,
    toId: link.toId,
    hidden: link.hidden ?? false,
    createdAt: link.createdAt,
    updatedAt: link.updatedAt,
    type: link.map(
      basic: (_) => 'BasicLink',
    ),
  );
}

EntryLink entryLinkFromLinkedDbEntry(LinkedDbEntry dbEntity) {
  return EntryLink.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

TagEntity fromTagDbEntity(TagDbEntity dbEntity) {
  return TagEntity.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

DashboardDefinition fromDashboardDbEntity(
  DashboardDefinitionDbEntity dbEntity,
) {
  return DashboardDefinition.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

List<TagEntity> tagStreamMapper(List<TagDbEntity> dbEntities) {
  return dbEntities.map(fromTagDbEntity).toList();
}

List<DashboardDefinition> dashboardStreamMapper(
  List<DashboardDefinitionDbEntity> dbEntities,
) {
  return dbEntities.map(fromDashboardDbEntity).toList();
}

HabitDefinition fromHabitDefinitionDbEntity(HabitDefinitionDbEntity dbEntity) {
  return HabitDefinition.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

List<HabitDefinition> habitDefinitionsStreamMapper(
  List<HabitDefinitionDbEntity> dbEntities,
) {
  return dbEntities.map(fromHabitDefinitionDbEntity).toList();
}

CategoryDefinition fromCategoryDefinitionDbEntity(
  CategoryDefinitionDbEntity dbEntity,
) {
  return CategoryDefinition.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

List<CategoryDefinition> categoryDefinitionsStreamMapper(
  List<CategoryDefinitionDbEntity> dbEntities,
) {
  return dbEntities.map(fromCategoryDefinitionDbEntity).toList();
}
