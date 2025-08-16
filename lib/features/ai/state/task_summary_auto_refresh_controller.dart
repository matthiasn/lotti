import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_auto_refresh_controller.g.dart';

@riverpod
class TaskSummaryAutoRefreshController
    extends _$TaskSummaryAutoRefreshController {
  StreamSubscription<Set<String>>? _updateSubscription;
  Timer? _debounceTimer;
  bool _isRefreshing = false;
  bool _hasPendingRefresh = false;

  @override
  void build({
    required String taskId,
  }) {
    ref.onDispose(() {
      _updateSubscription?.cancel();
      _debounceTimer?.cancel();
    });

    _listenForTaskUpdates();
  }

  void _listenForTaskUpdates() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      // Skip if this update includes AI response notification
      if (affectedIds.contains(aiResponseNotification)) {
        return;
      }

      // Check if task is in the affected IDs
      if (affectedIds.contains(taskId)) {
        // Look for checklist item updates
        // When a checklist item is updated, the notification includes:
        // - The checklist item ID
        // - The task ID (as linkedId)
        // - Potentially other notification constants

        for (final id in affectedIds) {
          // Skip the task ID itself and notification constants
          if (id == taskId ||
              id.endsWith('_NOTIFICATION') ||
              id == aiResponseNotification) {
            continue;
          }

          // Check if this is a checklist item or checklist update
          final entity = await getIt<JournalDb>().journalEntityById(id);
          if (entity is ChecklistItem) {
            _scheduleRefresh();
            return;
          }
          // Also handle checklist updates (e.g., when items are removed)
          if (entity is Checklist) {
            _scheduleRefresh();
            return;
          }
        }
      }

      // Also check for checklist items that might not include the task ID in the notification
      // This happens when checklist items are deleted
      for (final id in affectedIds) {
        // Skip notification constants
        if (id.endsWith('_NOTIFICATION') ||
            id == aiResponseNotification ||
            id == taskId) {
          continue;
        }

        // Check if this is a checklist item linked to our task
        final entity = await getIt<JournalDb>().journalEntityById(id);
        if (entity is ChecklistItem) {
          // Check if this checklist item is linked to our task through its checklists
          final checklistIds = entity.data.linkedChecklists;
          for (final checklistId in checklistIds) {
            final checklist =
                await getIt<JournalDb>().journalEntityById(checklistId);
            if (checklist is Checklist &&
                checklist.data.linkedTasks.contains(taskId)) {
              _scheduleRefresh();
              return;
            }
          }
        }
      }

      // For other entries (text/audio/image), we need to check if they're linked to this task
      final hasRelevantUpdate = affectedIds.contains(textEntryNotification) ||
          affectedIds.contains(audioNotification) ||
          affectedIds.contains(imageNotification);

      if (hasRelevantUpdate) {
        // Check if any of the affected entries are linked to this task
        for (final id in affectedIds) {
          // Skip notification type strings
          if (id == textEntryNotification ||
              id == audioNotification ||
              id == imageNotification ||
              id.endsWith('_NOTIFICATION')) {
            continue;
          }

          // Check if this entry is linked to our task
          final links = await getIt<JournalDb>().linksFromId(id, [false]).get();
          final isLinkedToTask = links.any((link) => link.toId == taskId);

          if (isLinkedToTask) {
            // Get the entity to check text content
            final entity = await getIt<JournalDb>().journalEntityById(id);
            final hasText =
                entity?.entryText?.plainText.trim().isNotEmpty ?? false;
            if (hasText) {
              _scheduleRefresh();
              return;
            }
          }
        }
      }
    });
  }

  void _scheduleRefresh() {
    // If we're currently refreshing, just mark that we need another refresh
    if (_isRefreshing) {
      _hasPendingRefresh = true;
      return;
    }

    // Otherwise, debounce and trigger
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: 500), _triggerTaskSummaryRefresh);
  }

  Future<void> _triggerTaskSummaryRefresh() async {
    // Mark that we're refreshing
    _isRefreshing = true;
    _hasPendingRefresh = false;

    try {
      // Check if inference is already running
      final isRunning = ref.read(
        inferenceStatusControllerProvider(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ),
      );

      if (isRunning == InferenceStatus.running) {
        return;
      }

      // Get the latest summary to find the prompt ID
      final latestSummary = await ref.read(
        latestSummaryControllerProvider(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ).future,
      );

      final promptId = latestSummary?.data.promptId;
      if (promptId != null) {
        await ref.read(
          triggerNewInferenceProvider(
            entityId: taskId,
            promptId: promptId,
          ).future,
        );
      }
    } finally {
      _isRefreshing = false;

      // If we have a pending refresh, trigger it now
      if (_hasPendingRefresh) {
        _hasPendingRefresh = false;
        // Use a short delay to ensure the system has processed the update
        Timer(const Duration(milliseconds: 100), _triggerTaskSummaryRefresh);
      }
    }
  }
}
