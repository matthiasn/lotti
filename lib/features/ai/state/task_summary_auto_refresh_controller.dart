import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
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
      try {
        // Skip if this update includes AI response notification
        if (affectedIds.contains(aiResponseNotification)) {
          return;
        }

        // Process all affected IDs in a single loop
        for (final id in affectedIds) {
          // Skip notification constants and AI response notifications
          if (id.endsWith('_NOTIFICATION') || id == aiResponseNotification) {
            continue;
          }

          // Skip processing the task ID itself - we're interested in linked entities
          if (id == taskId) {
            continue;
          }

          // Get the entity to determine its type and relationship to the task
          final entity = await getIt<JournalDb>().journalEntityById(id);
          if (entity == null) continue;

          // Check if this is a checklist item or checklist update
          if (entity is ChecklistItem) {
            // If task ID is in affected IDs, this item is already linked to our task
            if (affectedIds.contains(taskId)) {
              _scheduleRefresh();
              return;
            }

            // Otherwise, check if this item is linked through its checklists
            for (final checklistId in entity.data.linkedChecklists) {
              final checklist =
                  await getIt<JournalDb>().journalEntityById(checklistId);
              if (checklist is Checklist &&
                  checklist.data.linkedTasks.contains(taskId)) {
                _scheduleRefresh();
                return;
              }
            }
          } else if (entity is Checklist) {
            // Handle checklist updates (e.g., when items are removed)
            if (entity.data.linkedTasks.contains(taskId)) {
              _scheduleRefresh();
              return;
            }
          } else if (entity is JournalEntry) {
            // For other entries (text/audio/image), check if they're linked to this task
            final hasText =
                entity.entryText?.plainText.trim().isNotEmpty ?? false;

            if (hasText) {
              // Check if this entry is linked to our task
              final links =
                  await getIt<JournalDb>().linksFromId(id, [false]).get();
              final isLinkedToTask = links.any((link) => link.toId == taskId);

              if (isLinkedToTask) {
                _scheduleRefresh();
                return;
              }
            }
          }
        }
      } catch (e, stackTrace) {
        // Log the error but don't break the stream subscription
        getIt<LoggingService>().captureException(
          e,
          domain: 'AI',
          subDomain: 'TaskSummaryAutoRefresh',
          stackTrace: stackTrace,
        );
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

      // If we have a pending refresh, re-schedule with debounce
      if (_hasPendingRefresh) {
        _hasPendingRefresh = false;
        // Re-schedule with debounce to handle bursts of updates gracefully
        _scheduleRefresh();
      }
    }
  }
}
