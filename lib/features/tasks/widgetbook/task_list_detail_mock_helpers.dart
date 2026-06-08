part of 'task_list_detail_mock_data.dart';

CategoryDefinition _category({
  required String id,
  required String name,
  required String color,
  required CategoryIcon icon,
}) {
  final createdAt = DateTime(2026, 3, 30, 8);
  return EntityDefinition.categoryDefinition(
        id: id,
        createdAt: createdAt,
        updatedAt: createdAt,
        name: name,
        vectorClock: null,
        private: false,
        active: true,
        color: color,
        icon: icon,
      )
      as CategoryDefinition;
}

TaskRecord _taskRecord({
  required String id,
  required CategoryDefinition category,
  required String title,
  required String projectTitle,
  required String sectionTitle,
  required DateTime sectionDate,
  required DateTime createdAt,
  required DateTime due,
  required TaskPriority priority,
  required TaskStatus status,
  required String timeRange,
  required List<TaskShowcaseLabel> labels,
  required String aiSummary,
  required String description,
  required String trackedDurationLabel,
  required List<TaskShowcaseTimeEntry> trackerEntries,
  required List<TaskShowcaseChecklistItem> checklistItems,
  required List<TaskShowcaseAudioEntry> audioEntries,
}) {
  final task =
      JournalEntity.task(
            meta: Metadata(
              id: id,
              createdAt: createdAt,
              updatedAt: createdAt,
              dateFrom: createdAt,
              dateTo: createdAt.add(const Duration(minutes: 30)),
              categoryId: category.id,
            ),
            data: TaskData(
              status: status,
              statusHistory: const [],
              title: title,
              dateFrom: createdAt,
              dateTo: createdAt.add(const Duration(minutes: 30)),
              due: due,
              priority: priority,
            ),
            entryText: EntryText(
              plainText: '$projectTitle\n$description\n$timeRange',
            ),
          )
          as Task;

  return TaskRecord(
    task: task,
    category: category,
    sectionTitle: sectionTitle,
    sectionDate: sectionDate,
    projectTitle: projectTitle,
    timeRange: timeRange,
    labels: labels,
    aiSummary: aiSummary,
    description: description,
    trackedDurationLabel: trackedDurationLabel,
    trackerEntries: trackerEntries,
    checklistItems: checklistItems,
    audioEntries: audioEntries,
  );
}

TaskStatus _taskOpen(DateTime createdAt) {
  return TaskStatus.open(
    id: 'open-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
  );
}

TaskStatus _taskBlocked(DateTime createdAt, String reason) {
  return TaskStatus.blocked(
    id: 'blocked-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
    reason: reason,
  );
}

TaskStatus _taskOnHold(DateTime createdAt, String reason) {
  return TaskStatus.onHold(
    id: 'on-hold-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
    reason: reason,
  );
}

TaskStatus _taskGroomed(DateTime createdAt) {
  return TaskStatus.groomed(
    id: 'groomed-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
  );
}
