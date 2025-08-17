import 'dart:developer' as developer;

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
    // If this is an AI response notification with entity IDs, check if any are AI responses
    if (affectedIds.contains(aiResponseNotification)) {
      developer.log(
        'AI response notification detected',
        name: 'TaskRelevanceChecker.$taskId',
        error: {'affectedIds': affectedIds.join(', ')},
      );

      // Check if this is an AI response being linked to our task
      if (affectedIds.contains(taskId)) {
        // Filter to get only entity IDs (not notification constants and not the task ID)
        final entityIds = _filterRelevantIds(affectedIds);

        developer.log(
          'AI response with task ID detected',
          name: 'TaskRelevanceChecker.$taskId',
          error: {
            'affectedIds': affectedIds.join(', '),
            'filteredEntityIds': entityIds.join(', '),
          },
        );

        if (entityIds.isNotEmpty) {
          // Check if all non-task entities are AI responses
          final entities = await _batchFetchEntities(entityIds);

          // Check both existing entities and if they're AiResponseEntry
          final nonNullEntities = entities.where((e) => e != null).toList();
          final aiResponseCount =
              nonNullEntities.whereType<AiResponseEntry>().length;

          developer.log(
            'Checking if AI response is being linked to task',
            name: 'TaskRelevanceChecker.$taskId',
            error: {
              'totalEntities': entityIds.length,
              'foundEntities': nonNullEntities.length,
              'aiResponseCount': aiResponseCount,
              'entityTypes': entities
                  .map((e) => e?.runtimeType.toString() ?? 'null')
                  .join(', '),
            },
          );

          // If all entities are either null (not yet saved) or AI responses, skip
          if (aiResponseCount == nonNullEntities.length &&
              nonNullEntities.isNotEmpty) {
            developer.log(
              'Skipping update: AI response linked to task',
              name: 'TaskRelevanceChecker.$taskId',
            );
            return false;
          }
        } else if (affectedIds.length == 2) {
          // Special case: just task ID + AI_RESPONSE notification
          developer.log(
            'Skipping update: Only task ID and AI response notification',
            name: 'TaskRelevanceChecker.$taskId',
          );
          return false;
        }
      }
    }

    // Check if task ID is in affected IDs
    if (affectedIds.contains(taskId)) {
      // Special case: if it's just task ID + one other ID, check if it's an AI response
      if (affectedIds.length == 2) {
        final otherId = affectedIds.firstWhere((id) => id != taskId);

        // Quick check: does the other ID look like a UUID (potential AI response)?
        if (_isUuid(otherId)) {
          final entity = await getIt<JournalDb>().journalEntityById(otherId);

          developer.log(
            'Checking two-ID pattern with task',
            name: 'TaskRelevanceChecker.$taskId',
            error: {
              'otherId': otherId,
              'entityType': entity?.runtimeType.toString() ?? 'null',
              'isAiResponse': entity is AiResponseEntry,
            },
          );

          if (entity is AiResponseEntry) {
            developer.log(
              'Skipping update: AI response being created with task',
              name: 'TaskRelevanceChecker.$taskId',
            );
            return false;
          }
        }
      }

      developer.log(
        'Task ID found in affected IDs',
        name: 'TaskRelevanceChecker.$taskId',
      );
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
        developer.log(
          'Found relevant entity',
          name: 'TaskRelevanceChecker.$taskId',
          error: {
            'entityId': entity.id,
            'entityType': entity.runtimeType.toString(),
          },
        );
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

  /// Simple UUID format check
  bool _isUuid(String id) {
    // Basic UUID format: 8-4-4-4-12 hexadecimal characters
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
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
    } else if (entity is AiResponseEntry) {
      // AI response entries should never trigger updates
      return false;
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
