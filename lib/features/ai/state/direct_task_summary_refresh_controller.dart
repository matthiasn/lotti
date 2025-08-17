import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'direct_task_summary_refresh_controller.g.dart';

/// Manages direct task summary refresh requests from checklist actions
/// This bypasses the notification system to avoid circular dependencies and infinite loops
@Riverpod(keepAlive: true)
class DirectTaskSummaryRefreshController
    extends _$DirectTaskSummaryRefreshController {
  final Map<String, Timer> _debounceTimers = {};
  final Set<String> _refreshingTasks = {};
  final Set<String> _pendingRefreshTasks = {};

  @override
  void build() {
    ref.onDispose(() {
      for (final timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();
    });
  }

  /// Request a task summary refresh for the given task ID
  /// This method is called directly from checklist action handlers
  Future<void> requestTaskSummaryRefresh(String taskId) async {
    developer.log(
      'Direct refresh request received',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // If we're currently refreshing this task, just mark that we need another refresh
    if (_refreshingTasks.contains(taskId)) {
      developer.log(
        'Already refreshing, marking pending refresh',
        name: 'DirectTaskSummaryRefresh',
        error: {'taskId': taskId},
      );
      _pendingRefreshTasks.add(taskId);
      return;
    }

    // Otherwise, debounce and trigger
    developer.log(
      'Scheduling refresh with debounce',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Cancel existing timer for this task if any
    _debounceTimers[taskId]?.cancel();

    // Create new timer for this task
    _debounceTimers[taskId] = Timer(
      const Duration(milliseconds: 500),
      () => _triggerTaskSummaryRefresh(taskId),
    );
  }

  Future<void> _triggerTaskSummaryRefresh(String taskId) async {
    developer.log(
      'Starting direct refresh trigger',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Mark that we're refreshing this task
    _refreshingTasks.add(taskId);
    _pendingRefreshTasks.remove(taskId);

    // Remove the timer since it fired
    _debounceTimers.remove(taskId);

    try {
      // Check if inference is already running
      final isRunning = ref.read(
        inferenceStatusControllerProvider(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ),
      );

      developer.log(
        'Checking inference status',
        name: 'DirectTaskSummaryRefresh',
        error: {
          'taskId': taskId,
          'status': isRunning.toString(),
        },
      );

      if (isRunning == InferenceStatus.running) {
        // Ensure we attempt again after the current run settles
        developer.log(
          'Inference already running, marking pending refresh',
          name: 'DirectTaskSummaryRefresh',
          error: {'taskId': taskId},
        );
        _pendingRefreshTasks.add(taskId);
        _refreshingTasks.remove(taskId); // Clean up before returning
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
      developer.log(
        'Retrieved prompt ID',
        name: 'DirectTaskSummaryRefresh',
        error: {
          'taskId': taskId,
          'promptId': promptId ?? 'null',
        },
      );

      if (promptId != null) {
        developer.log(
          'Triggering new inference',
          name: 'DirectTaskSummaryRefresh',
          error: {
            'taskId': taskId,
            'promptId': promptId,
          },
        );

        await ref.read(
          triggerNewInferenceProvider(
            entityId: taskId,
            promptId: promptId,
          ).future,
        );

        developer.log(
          'Inference triggered successfully',
          name: 'DirectTaskSummaryRefresh',
          error: {'taskId': taskId},
        );
      } else {
        developer.log(
          'No prompt ID found, cannot trigger refresh',
          name: 'DirectTaskSummaryRefresh',
          error: {'taskId': taskId},
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error triggering direct refresh',
        name: 'DirectTaskSummaryRefresh',
        error: e,
        stackTrace: stackTrace,
      );

      // Log the error but don't break the refresh cycle
      getIt<LoggingService>().captureException(
        e,
        domain: 'AI',
        subDomain: 'DirectTaskSummaryRefresh',
        stackTrace: stackTrace,
      );
    } finally {
      _refreshingTasks.remove(taskId);

      // If we have a pending refresh for this task, re-schedule with debounce
      if (_pendingRefreshTasks.contains(taskId)) {
        developer.log(
          'Has pending refresh, re-scheduling',
          name: 'DirectTaskSummaryRefresh',
          error: {'taskId': taskId},
        );
        _pendingRefreshTasks.remove(taskId);
        // Re-schedule with debounce to handle bursts of updates gracefully
        await requestTaskSummaryRefresh(taskId);
      }
    }
  }
}
