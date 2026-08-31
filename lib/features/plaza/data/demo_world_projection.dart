/// Projects the penguin demo world into plaza tasks.
///
/// The plaza's "small project" preset uses real task surfaces — titles,
/// states, checklists and links from [ManualDemoWorld.penguinLogistics] —
/// instead of synthetic filler, per the fixture policy (demo world only,
/// never user data).
library;

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Fallback category color when the demo category has none.
const _fallbackColor = 0xFF5C9DFF;

/// Builds the plaza task list from the Project Waddle demo world.
List<PlazaTask> plazaTasksFromDemoWorld({DateTime? now}) {
  final world = ManualDemoWorld.penguinLogistics(now: now);

  final categoryColors = <String, int>{
    for (final category in world.categories)
      category.id: _parseHexColor(category.color) ?? _fallbackColor,
  };

  // Checklist items per task, resolved through the checklist layer.
  final itemById = <String, ChecklistItemData>{
    for (final item in world.checklistItems) item.meta.id: item.data,
  };
  final itemsByTask = <String, List<ChecklistItemData>>{};
  for (final checklist in world.checklists) {
    for (final taskId in checklist.data.linkedTasks) {
      final items = itemsByTask.putIfAbsent(taskId, () => []);
      for (final itemId in checklist.data.linkedChecklistItems) {
        final item = itemById[itemId];
        if (item != null && !item.isArchived) items.add(item);
      }
    }
  }

  final taskIds = {for (final task in world.tasks) task.meta.id};
  final linksByTask = <String, Set<String>>{};
  for (final link in world.links) {
    if (taskIds.contains(link.fromId) && taskIds.contains(link.toId)) {
      linksByTask.putIfAbsent(link.fromId, () => {}).add(link.toId);
    }
  }

  return [
    for (final task in world.tasks)
      _project(
        task: task,
        items: itemsByTask[task.meta.id] ?? const [],
        links: linksByTask[task.meta.id] ?? const {},
        categoryColor: categoryColors[task.meta.categoryId] ?? _fallbackColor,
      ),
  ];
}

PlazaTask _project({
  required Task task,
  required List<ChecklistItemData> items,
  required Set<String> links,
  required int categoryColor,
}) {
  final checked = items.where((i) => i.isChecked).length;
  // Demo cover art lives in the public immutable R2 catalog; the harness
  // loads it straight over HTTP, no hydrator or app storage involved.
  final cover = demoMediaAssets
      .where((asset) => asset.taskId == task.meta.id && asset.isCover)
      .firstOrNull;
  return PlazaTask(
    id: task.meta.id,
    createdAt: task.meta.createdAt,
    coverImageUrl: cover?.uri.toString(),
    openChecklistItems: [
      for (final item in items)
        if (!item.isChecked) item.title,
    ].take(8).toList(),
    title: task.data.title,
    state: _mapStatus(task.data.status),
    due: task.data.due,
    progress: items.isEmpty ? 0 : checked / items.length,
    checklistItems: items.length,
    linkedTaskIds: links.toList()..sort(),
    categoryColor: categoryColor,
    deleted: task.meta.deletedAt != null,
  );
}

PlazaTaskState _mapStatus(TaskStatus status) {
  return switch (status) {
    TaskOpen() || TaskGroomed() => PlazaTaskState.open,
    TaskInProgress() => PlazaTaskState.inProgress,
    TaskBlocked() || TaskOnHold() => PlazaTaskState.blocked,
    TaskDone() => PlazaTaskState.done,
    TaskRejected() => PlazaTaskState.cancelled,
  };
}

int? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return int.tryParse(value, radix: 16);
}
