import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/plaza/domain/plaza_connection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';

/// Projects only relationships whose two tasks are already visible in scope.
/// Hidden/deleted edges and self-links are omitted. Symmetric associations
/// deduplicate across directions; distinct typed relations retain direction.
List<PlazaConnection> projectPlazaConnections({
  required Iterable<EntryLink> links,
  required Set<String> visibleTaskIds,
}) {
  final sorted = links.toList()..sort((a, b) => a.id.compareTo(b.id));
  final connections = <(String, String, EntryLinkType), PlazaConnection>{};
  for (final link in sorted) {
    if (link.hidden == true ||
        link.deletedAt != null ||
        link.fromId == link.toId ||
        !visibleTaskIds.contains(link.fromId) ||
        !visibleTaskIds.contains(link.toId)) {
      continue;
    }
    final type = entryLinkTypeOf(link);
    if (!relationshipSelectorTypes.contains(type)) continue;
    final reverse =
        type == EntryLinkType.basic && link.fromId.compareTo(link.toId) > 0;
    final fromId = reverse ? link.toId : link.fromId;
    final toId = reverse ? link.fromId : link.toId;
    connections.putIfAbsent(
      (fromId, toId, type),
      () => PlazaConnection(
        id: link.id,
        fromId: fromId,
        toId: toId,
        type: type,
      ),
    );
  }
  return List.unmodifiable(connections.values);
}

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
