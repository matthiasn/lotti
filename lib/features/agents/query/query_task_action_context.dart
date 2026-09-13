import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';

/// Loads bounded, live task metadata for explicit user-requested changes.
/// No report, transcript, neighbour body or historical instruction is included.
class QueryTaskActionContextLoader {
  const QueryTaskActionContextLoader({required this.access});

  final QuerySourceAccess access;

  static String _preview(String text) =>
      text.length > 200 ? text.substring(0, 200) : text;

  Future<QueryTaskActionContext> load(
    String taskId, {
    Iterable<String> relatedIds = const [],
    String? runningTimerId,
  }) async {
    final homeAccess = await access.load([taskId]);
    final task = homeAccess.entries[taskId];
    if (task is! Task || !homeAccess.allowsEntry(task)) {
      throw const QueryScopeUnavailable();
    }
    final links = await access.journal.linksForEntryIdsBidirectional({taskId});
    final linkedIds = <String>{
      for (final link in links)
        if (link.hidden != true && link.deletedAt == null) ...[
          link.fromId,
          link.toId,
        ],
    }..remove(taskId);
    final checklistIds = task.data.checklistIds ?? const <String>[];
    final lists = await access.load(checklistIds);
    final itemIds = <String>{
      for (final checklist in lists.entries.values)
        if (checklist is Checklist &&
            lists.allowsEntry(checklist) &&
            checklist.meta.categoryId == task.meta.categoryId)
          ...checklist.data.linkedChecklistItems,
    };
    final ids = <String>{
      taskId,
      ...checklistIds,
      ...itemIds.take(100),
      ...linkedIds.take(80),
      ...relatedIds.take(80),
    };
    final current = await access.load(ids);
    if (!current.allowsEntry(task)) throw const QueryScopeUnavailable();
    final visible = current.entries.values
        .where(
          (entry) =>
              current.allowsEntry(entry) &&
              entry.meta.categoryId == task.meta.categoryId,
        )
        .toList();
    final home = visible
        .whereType<Task>()
        .where((t) => t.meta.id == taskId)
        .firstOrNull;
    if (home == null) throw const QueryScopeUnavailable();
    final liveItemIds = <String>{
      for (final checklist in visible.whereType<Checklist>())
        if (home.data.checklistIds?.contains(checklist.meta.id) ?? false)
          ...checklist.data.linkedChecklistItems,
    };
    final checklists = visible
        .whereType<ChecklistItem>()
        .where((entry) => liveItemIds.contains(entry.meta.id))
        .toList();
    final times = visible
        .whereType<JournalEntry>()
        .where(
          (entry) =>
              linkedIds.contains(entry.meta.id) &&
              (entry.meta.dateFrom != entry.meta.dateTo ||
                  entry.meta.id == runningTimerId),
        )
        .toList();
    final tasks = visible
        .whereType<Task>()
        .where((t) => t.meta.id != taskId)
        .toList();
    final labels = (await access.journal.getAllLabelDefinitions())
        .where(
          (label) =>
              label.deletedAt == null &&
              (label.private != true || current.showPrivate) &&
              (label.applicableCategoryIds == null ||
                  label.applicableCategoryIds!.isEmpty ||
                  label.applicableCategoryIds!.contains(
                    home.meta.categoryId,
                  )) &&
              !(home.data.aiSuppressedLabelIds?.contains(label.id) ?? false),
        )
        .take(80)
        .toList();
    final timer = times.where((t) => t.meta.id == runningTimerId).firstOrNull;
    return QueryTaskActionContext(
      taskId: taskId,
      dependencies: visible.map(current.reference).toList(),
      checklistIds: checklists.map((e) => e.meta.id).toSet(),
      timeEntryIds: times
          .where((e) => e.meta.id != runningTimerId)
          .map((e) => e.meta.id)
          .toSet(),
      taskIds: tasks.map((t) => t.meta.id).toSet(),
      labelIds: labels.map((l) => l.id).toSet(),
      runningTimerId: timer?.meta.id,
      input: {
        'task': {
          'id': taskId,
          'title': home.data.title,
          'status': home.data.status.toDbString,
          'dueDate': home.data.due?.toIso8601String(),
          'estimateMinutes': home.data.estimate?.inMinutes,
          'priority': home.data.priority.name,
          'languageCode': home.data.languageCode,
        },
        'checklistItems': [
          for (final entry in checklists)
            {...entry.data.toJson(), 'id': entry.meta.id},
        ],
        'timeEntries': [
          for (final entry in times)
            {
              'id': entry.meta.id,
              'startTime': entry.meta.dateFrom.toIso8601String(),
              'endTime': entry.meta.dateTo.toIso8601String(),
              'summaryPreview': _preview(entry.entryText?.plainText ?? ''),
              'textTruncated': (entry.entryText?.plainText.length ?? 0) > 200,
            },
        ],
        'runningTimerId': timer?.meta.id,
        'tasks': [
          for (final entry in tasks)
            {'id': entry.meta.id, 'title': entry.data.title},
        ],
        'labels': [
          for (final label in labels) {'id': label.id, 'name': label.name},
        ],
      },
    );
  }
}
