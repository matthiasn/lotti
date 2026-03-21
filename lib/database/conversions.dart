import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/services/dev_logger.dart';

JournalDbEntity toDbEntity(JournalEntity entity) {
  final createdAt = entity.meta.createdAt;

  final subtype = entity.maybeMap(
    quantitative: (QuantitativeEntry entry) => entry.data.dataType,
    measurement: (MeasurementEntry entry) => entry.data.dataTypeId,
    survey: (SurveyEntry entry) =>
        entry.data.taskResult.identifier.toLowerCase(),
    workout: (WorkoutEntry entry) => entry.data.workoutType,
    habitCompletion: (HabitCompletionEntry entry) => entry.data.habitId,
    aiResponse: (AiResponseEntry entry) => entry.data.type?.name,
    rating: (RatingEntry entry) => entry.data.catalogId,
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
    task: (task) => task.data.status.toDbString,
    orElse: () => '',
  );
  final taskPriority = entity.maybeMap(
    task: (task) => task.data.priority.short,
    orElse: () => null,
  );
  final taskPriorityRank = entity.maybeMap(
    task: (task) => task.data.priority.rank,
    orElse: () => null,
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
    taskPriority: taskPriority,
    taskPriorityRank: taskPriorityRank,
    category: entity.meta.categoryId ?? '',
    dateTo: entity.meta.dateTo,
    plainText: entity.entryText?.plainText,
    type: entity.map(
      journalEntry: (_) => 'JournalEntry',
      journalImage: (_) => 'JournalImage',
      journalAudio: (_) => 'JournalAudio',
      task: (_) => 'Task',
      event: (_) => 'JournalEvent',
      aiResponse: (_) => 'AiResponse',
      checklist: (_) => 'Checklist',
      checklistItem: (_) => 'ChecklistItem',
      quantitative: (_) => 'QuantitativeEntry',
      measurement: (_) => 'MeasurementEntry',
      workout: (_) => 'WorkoutEntry',
      habitCompletion: (_) => 'HabitCompletionEntry',
      survey: (_) => 'SurveyEntry',
      dayPlan: (_) => 'DayPlanEntry',
      rating: (_) => 'RatingEntry',
      project: (_) => 'Project',
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
  final entity = fromSerialized(dbEntity.serialized);

  // Patch denormalized fields that may be missing from legacy JSON or
  // when codegen is temporarily out of sync (e.g., after a hot restart).
  // Priority: prefer DB column when present to ensure UI reflects the latest
  // persisted value.
  if (dbEntity.taskPriority != null && dbEntity.taskPriority!.isNotEmpty) {
    return entity.maybeMap(
      task: (t) {
        final prio = taskPriorityFromString(dbEntity.taskPriority!);
        if (t.data.priority == prio) return t;
        return t.copyWith(data: t.data.copyWith(priority: prio));
      },
      orElse: () => entity,
    );
  }

  return entity;
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

LabelDefinition fromLabelDefinitionDbEntity(
  LabelDefinitionDbEntity dbEntity,
) {
  return LabelDefinition.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

List<LabelDefinition> labelDefinitionsStreamMapper(
  List<LabelDefinitionDbEntity> dbEntities,
) {
  return dbEntities.map(fromLabelDefinitionDbEntity).toList();
}

LabelDefinitionDbEntity labelDefinitionDbEntity(LabelDefinition label) {
  final deleted = label.deletedAt != null;

  return LabelDefinitionDbEntity(
    id: label.id,
    createdAt: label.createdAt,
    updatedAt: label.updatedAt,
    serialized: jsonEncode(label),
    private: label.private ?? false,
    name: deleted ? label.id : label.name,
    deleted: deleted,
    color: label.color,
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
      rating: (_) => 'RatingLink',
      project: (_) => 'ProjectLink',
    ),
  );
}

EntryLink entryLinkFromLinkedDbEntry(LinkedDbEntry dbEntity) {
  return EntryLink.fromJson(
    json.decode(dbEntity.serialized) as Map<String, dynamic>,
  );
}

/// Known DashboardItem runtimeType discriminator values.
/// Used to filter out removed/unknown types during JSON deserialization
/// so that legacy data in the database does not crash the app.
const _knownDashboardItemTypes = {
  'measurement',
  'healthChart',
  'workoutChart',
  'habitChart',
  'surveyChart',
};

/// Filters out DashboardItem entries with unknown runtimeType values
/// from the dashboard JSON before deserialization.
/// Returns the sanitized JSON and whether any items were removed.
(Map<String, dynamic>, bool) _sanitizeDashboardJson(
  Map<String, dynamic> dashboardJson,
) {
  final items = dashboardJson['items'];
  if (items is! List) return (dashboardJson, false);

  final filtered = <dynamic>[];
  final removedTypes = <dynamic>[];

  for (final item in items) {
    if (item is Map<String, dynamic>) {
      final runtimeType = item['runtimeType'];
      if (runtimeType is String &&
          _knownDashboardItemTypes.contains(runtimeType)) {
        filtered.add(item);
        continue;
      }
    }
    removedTypes.add(
      item is Map<String, dynamic>
          ? item['runtimeType']
          : 'invalid_item_structure',
    );
  }

  if (removedTypes.isEmpty) return (dashboardJson, false);

  DevLogger.log(
    name: 'conversions',
    message:
        'Removed ${removedTypes.length} unknown dashboard item(s) '
        'with types: $removedTypes',
  );

  return ({...dashboardJson, 'items': filtered}, true);
}

DashboardDefinition fromDashboardDbEntity(
  DashboardDefinitionDbEntity dbEntity,
) {
  final rawJson = json.decode(dbEntity.serialized) as Map<String, dynamic>;
  final (sanitizedJson, _) = _sanitizeDashboardJson(rawJson);
  return DashboardDefinition.fromJson(sanitizedJson);
}

List<DashboardDefinition> dashboardStreamMapper(
  List<DashboardDefinitionDbEntity> dbEntities,
) {
  final results = <DashboardDefinition>[];
  for (final dbEntity in dbEntities) {
    try {
      results.add(fromDashboardDbEntity(dbEntity));
    } on Object catch (e) {
      DevLogger.log(
        name: 'conversions',
        message: 'Failed to parse dashboard ${dbEntity.id}: $e — skipping',
      );
    }
  }
  return results;
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
