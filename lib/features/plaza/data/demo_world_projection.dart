/// Projects the penguin demo world into plaza tasks.
///
/// The plaza's "small project" preset uses real task surfaces — titles,
/// states, checklists and links from [ManualDemoWorld.penguinLogistics] —
/// instead of synthetic filler, per the fixture policy (demo world only,
/// never user data).
library;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/task_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Fallback category color when the demo category has none.
const _fallbackColor = 0xFF5C9DFF;

/// Category names keyed by the lower-case hex of their colour, for the
/// side panel's category label (plaza tasks carry only the colour).
Map<String, String> demoCategoryLabels({DateTime? now}) {
  final world = ManualDemoWorld.penguinLogistics(now: now);
  return {
    for (final category in world.categories)
      (_parseHexColor(category.color) ?? _fallbackColor).toRadixString(16):
          category.name,
  };
}

/// Builds the plaza task list from the Project Waddle demo world.
List<PlazaTask> plazaTasksFromDemoWorld({DateTime? now}) {
  final world = ManualDemoWorld.penguinLogistics(now: now);

  final categoryColors = <String, int>{
    for (final category in world.categories)
      category.id: _parseHexColor(category.color) ?? _fallbackColor,
  };

  // Checklist items per task, resolved through the checklist layer.
  final itemById = <String, ChecklistItem>{
    for (final item in world.checklistItems) item.meta.id: item,
  };
  final itemsByTask = <String, List<ChecklistItem>>{};
  for (final checklist in world.checklists) {
    for (final taskId in checklist.data.linkedTasks) {
      final items = itemsByTask.putIfAbsent(taskId, () => []);
      for (final itemId in checklist.data.linkedChecklistItems) {
        final item = itemById[itemId];
        if (item != null) items.add(item);
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
      projectPlazaTask(
        task: task,
        checklistItems: itemsByTask[task.meta.id] ?? const [],
        linkedTaskIds: linksByTask[task.meta.id] ?? const {},
        categoryColor: categoryColors[task.meta.categoryId] ?? _fallbackColor,
        coverImageUrl: demoMediaAssets
            .where((asset) => asset.taskId == task.meta.id && asset.isCover)
            .firstOrNull
            ?.uri
            .toString(),
      ),
  ];
}

int? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return int.tryParse(value, radix: 16);
}
