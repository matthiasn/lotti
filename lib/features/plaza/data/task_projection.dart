import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Projects a persisted task and its resolved checklist items into the plaza.
///
/// Callers own project membership, privacy filtering, category colours and
/// cover resolution. Checklist order is preserved, duplicate item IDs are
/// counted once, and archived or deleted items never affect progress. Surface
/// previews are capped at eight open items; progress uses the full checklist.
PlazaTask projectPlazaTask({
  required Task task,
  required Iterable<ChecklistItem> checklistItems,
  required Iterable<String> linkedTaskIds,
  required int categoryColor,
  String? coverImageUrl,
}) {
  final itemsById = {
    for (final item in checklistItems)
      if (item.meta.deletedAt == null && !item.data.isArchived)
        item.meta.id: item,
  };
  final items = itemsById.values;
  final checked = items.where((item) => item.data.isChecked).length;
  final open = items.where((item) => !item.data.isChecked).take(8).toList();
  final links = linkedTaskIds.where((id) => id != task.meta.id).toSet().toList()
    ..sort();

  return PlazaTask(
    id: task.meta.id,
    createdAt: task.meta.createdAt,
    title: task.data.title,
    state: mapTaskStatusToPlazaState(task.data.status),
    due: task.data.due,
    progress: items.isEmpty ? 0 : checked / items.length,
    checklistItems: items.length,
    openChecklistItems: [for (final item in open) item.data.title],
    openChecklistItemIds: [for (final item in open) item.meta.id],
    linkedTaskIds: links,
    categoryColor: categoryColor,
    coverImageUrl: coverImageUrl,
    deleted: task.meta.deletedAt != null,
    priority: task.data.priority.index,
    lastActivityAt: task.meta.updatedAt,
  );
}

/// Maps every app task status onto a plaza surface state.
PlazaTaskState mapTaskStatusToPlazaState(TaskStatus status) => switch (status) {
  TaskOpen() || TaskGroomed() => PlazaTaskState.open,
  TaskInProgress() => PlazaTaskState.inProgress,
  TaskBlocked() || TaskOnHold() => PlazaTaskState.blocked,
  TaskDone() => PlazaTaskState.done,
  TaskRejected() => PlazaTaskState.cancelled,
};
