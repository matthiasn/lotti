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
/// comes first; at most [limit] tasks come back. The ids may include parents
/// that are not tasks; the task query the caller runs on them leaves those
/// out, along with deleted and hidden ones.
Future<List<TaskSearchHit>> searchTasks({
  required Fts5Db fts5Db,
  required JournalDb journalDb,
  required String query,
  required bool includePrivate,
  Set<String>? categoryIds,
  int limit = Fts5Db.defaultMatchLimit,
}) async {
  final found = <TaskSearchHit>[];
  final seen = <String>{};
  // The ranking is read a page at a time until [limit] tasks are found: a
  // page can be all entries that belong to no task, or many children of one,
  // and cutting the ranking before resolving them would hide tasks that
  // match further down. Bounded, so a query matching mostly loose entries
  // stops after ten pages.
  for (var offset = 0; offset < limit * _maxPages; offset += limit) {
    final hits = await fts5Db.matchHits(
      query,
      types: taskSearchTypes,
      categoryIds: categoryIds,
      includePrivate: includePrivate,
      limit: limit,
      offset: offset,
    );
    final parents = await _taskParents(journalDb, hits);
    for (final hit in hits) {
      final taskIds = hit.type == taskEntityTypeName
          ? [hit.entityId]
          : parents[hit.entityId] ?? const <String>[];
      for (final taskId in taskIds) {
        if (!seen.add(taskId)) continue;
        found.add(
          TaskSearchHit(
            taskId: taskId,
            snippet: hit.snippet,
            matchedType: hit.type,
          ),
        );
        if (found.length == limit) return found;
      }
    }
    if (hits.length < limit) break;
  }
  return found;
}

/// Pages of the ranking [searchTasks] reads at most.
const _maxPages = 10;

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
