import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_search_hit.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/search_hit.dart';

/// The kinds a task is found through: its own text, and the text of what
/// belongs to it — the entries, recordings, photos and AI responses linked
/// from it, and its checklists and their items.
const taskSearchTypes = <String>{
  taskEntityTypeName,
  'JournalEntry',
  'JournalAudio',
  'JournalImage',
  'Checklist',
  'ChecklistItem',
  'AiResponse',
};

/// The tasks [query] finds, best first: a match in a task's own text, or in
/// anything [taskSearchTypes] names that belongs to it, counts for the task,
/// and each task keeps its best match's snippet.
///
/// The index ranks every match together ([Fts5Db.matchHits]), so a task
/// whose checklist item matches better than another task's description
/// comes first. The ids may include parents that are not tasks; the task
/// query the caller runs on them leaves those out, along with deleted and
/// hidden ones.
Future<List<TaskSearchHit>> searchTasks({
  required Fts5Db fts5Db,
  required JournalDb journalDb,
  required String query,
  required bool includePrivate,
  Set<String>? categoryIds,
  int limit = Fts5Db.defaultMatchLimit,
}) async {
  final hits = await fts5Db.matchHits(
    query,
    types: taskSearchTypes,
    categoryIds: categoryIds,
    includePrivate: includePrivate,
    limit: limit,
  );
  final parents = await _taskParents(journalDb, hits);
  final seen = <String>{};
  return [
    for (final hit in hits)
      for (final taskId
          in hit.type == taskEntityTypeName
              ? [hit.entityId]
              : parents[hit.entityId] ?? const <String>[])
        if (seen.add(taskId))
          TaskSearchHit(
            taskId: taskId,
            snippet: hit.snippet,
            matchedType: hit.type,
          ),
  ];
}

/// The ids each non-task hit belongs to: what links to it, and for a
/// checklist or checklist item the tasks its checklist names. Read in three
/// batched queries, never one per hit.
Future<Map<String, List<String>>> _taskParents(
  JournalDb journalDb,
  List<SearchHit> hits,
) async {
  final childIds = [
    for (final hit in hits)
      if (hit.type != taskEntityTypeName) hit.entityId,
  ];
  if (childIds.isEmpty) return const {};
  final parents = <String, List<String>>{};
  for (final link in await journalDb.linksForIds(childIds).get()) {
    (parents[link.toId] ??= []).add(link.fromId);
  }

  final checklistKinds = {'Checklist', 'ChecklistItem'};
  final checklistHitIds = {
    for (final hit in hits)
      if (checklistKinds.contains(hit.type)) hit.entityId,
  };
  if (checklistHitIds.isEmpty) return parents;
  final checklistHits = await journalDb.getJournalEntitiesForIdsUnordered(
    checklistHitIds,
  );
  final itemChecklists = <String, List<String>>{
    for (final entity in checklistHits)
      if (entity is ChecklistItem) entity.id: entity.data.linkedChecklists,
  };
  final checklists = <String, Checklist>{
    for (final entity in [
      ...checklistHits,
      ...await journalDb.getJournalEntitiesForIdsUnordered({
        for (final ids in itemChecklists.values) ...ids,
      }),
    ])
      if (entity is Checklist) entity.id: entity,
  };
  for (final checklist in checklists.values) {
    if (checklistHitIds.contains(checklist.id)) {
      (parents[checklist.id] ??= []).addAll(checklist.data.linkedTasks);
    }
  }
  for (final MapEntry(key: itemId, value: checklistIds)
      in itemChecklists.entries) {
    for (final checklistId in checklistIds) {
      (parents[itemId] ??= []).addAll(
        checklists[checklistId]?.data.linkedTasks ?? const [],
      );
    }
  }
  return parents;
}
