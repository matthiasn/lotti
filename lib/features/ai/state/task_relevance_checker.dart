import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Helper class to determine if database updates are relevant to a specific task
class TaskRelevanceChecker {
  TaskRelevanceChecker({required this.taskId});

  final String taskId;

  /// Checks if the given notification should be skipped entirely
  bool shouldSkipNotification(Set<String> affectedIds) {
    // Skip only if the update is solely an AI response notification
    return affectedIds.length == 1 &&
        affectedIds.contains(aiResponseNotification);
  }

  /// Determines if any of the affected IDs represent updates relevant to this task
  Future<bool> isUpdateRelevantToTask(Set<String> affectedIds) async {
    // Quick check: if task ID is in affected IDs, it's definitely relevant
    if (affectedIds.contains(taskId)) {
      return true;
    }

    // Filter out notification constants and the task ID itself
    final relevantIds = _filterRelevantIds(affectedIds);
    if (relevantIds.isEmpty) {
      return false;
    }

    // Batch fetch all entities to avoid N+1 queries
    final entities = await _batchFetchEntities(relevantIds);

    // Check each entity for relevance
    for (final entity in entities) {
      if (entity == null) continue;

      final isRelevant = await isEntityRelevantToTask(entity, affectedIds);
      if (isRelevant) {
        return true;
      }
    }

    return false;
  }

  /// Filters out notification constants and the task ID from the affected IDs
  List<String> _filterRelevantIds(Set<String> affectedIds) {
    return affectedIds
        .where((id) =>
            !id.endsWith('_NOTIFICATION') &&
            id != aiResponseNotification &&
            id != taskId)
        .toList();
  }

  /// Batch fetches entities by their IDs
  Future<List<JournalEntity?>> _batchFetchEntities(List<String> ids) async {
    // In a real implementation, this could be optimized with a batch query
    // For now, we'll fetch them individually but in parallel
    final futures =
        ids.map((id) => getIt<JournalDb>().journalEntityById(id)).toList();
    return Future.wait(futures);
  }

  /// Determines if a specific entity is relevant to the task
  Future<bool> isEntityRelevantToTask(
    JournalEntity entity,
    Set<String> affectedIds,
  ) async {
    if (entity is ChecklistItem) {
      return isChecklistItemRelevant(entity, affectedIds);
    } else if (entity is Checklist) {
      return isChecklistRelevant(entity);
    } else if (entity is JournalEntry) {
      return isJournalEntryRelevant(entity);
    }
    return false;
  }

  /// Checks if a checklist item is relevant to the task
  Future<bool> isChecklistItemRelevant(
    ChecklistItem item,
    Set<String> affectedIds,
  ) async {
    // If task ID is in affected IDs, this item is already linked to our task
    if (affectedIds.contains(taskId)) {
      return true;
    }

    // Check if this item is linked through its checklists
    if (item.data.linkedChecklists.isEmpty) {
      return false;
    }

    // Batch fetch all linked checklists
    final checklists = await _batchFetchEntities(item.data.linkedChecklists);

    for (final checklist in checklists) {
      if (checklist is Checklist &&
          checklist.data.linkedTasks.contains(taskId)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a checklist is relevant to the task
  bool isChecklistRelevant(Checklist checklist) {
    // Handle checklist updates (e.g., when items are removed)
    return checklist.data.linkedTasks.contains(taskId);
  }

  /// Checks if a journal entry is relevant to the task
  Future<bool> isJournalEntryRelevant(JournalEntry entry) async {
    // For other entries (text/audio/image), check if they're linked to this task
    final hasText = entry.entryText?.plainText.trim().isNotEmpty ?? false;

    if (!hasText) {
      return false;
    }

    // Check if this entry is linked to our task
    final links =
        await getIt<JournalDb>().linksFromId(entry.meta.id, [false]).get();
    return links.any((link) => link.toId == taskId);
  }
}
