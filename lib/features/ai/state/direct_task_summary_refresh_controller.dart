import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/task_summary_refresh_status_listener.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'direct_task_summary_refresh_controller.g.dart';

/// Duration before a scheduled task summary refresh fires.
/// This gives the user time to make multiple changes before triggering an API call.
const scheduledRefreshDelay = Duration(minutes: 5);

/// Data class to track a scheduled refresh
class ScheduledRefreshData {
  ScheduledRefreshData({
    required this.scheduledTime,
    required this.timer,
  });

  final DateTime scheduledTime;
  final Timer timer;
}

/// State class that holds the map of scheduled refreshes
/// This allows watchers to be notified when the map changes
class ScheduledRefreshState {
  ScheduledRefreshState(this.scheduledTimes);

  final Map<String, DateTime> scheduledTimes;

  DateTime? getScheduledTime(String taskId) => scheduledTimes[taskId];
  bool hasScheduledRefresh(String taskId) => scheduledTimes.containsKey(taskId);
}

/// Manages direct task summary refresh requests from checklist actions
/// This bypasses the notification system to avoid circular dependencies and infinite loops
@Riverpod(keepAlive: true)
class DirectTaskSummaryRefreshController
    extends _$DirectTaskSummaryRefreshController {
  final Map<String, ScheduledRefreshData> _scheduledRefreshes = {};
  late final TaskSummaryRefreshStatusListener _statusListener;

  @override
  ScheduledRefreshState build() {
    _statusListener = TaskSummaryRefreshStatusListener(ref);

    ref.onDispose(() {
      // Cancel all timers
      for (final data in _scheduledRefreshes.values) {
        data.timer.cancel();
      }
      _scheduledRefreshes.clear();

      // Clean up all status listeners
      _statusListener.dispose();
    });

    return ScheduledRefreshState(_getScheduledTimes());
  }

  Map<String, DateTime> _getScheduledTimes() {
    return Map.fromEntries(
      _scheduledRefreshes.entries.map(
        (e) => MapEntry(e.key, e.value.scheduledTime),
      ),
    );
  }

  void _updateState() {
    state = ScheduledRefreshState(_getScheduledTimes());
  }

  /// Get the scheduled refresh time for a task, or null if not scheduled
  DateTime? getScheduledTime(String taskId) {
    return _scheduledRefreshes[taskId]?.scheduledTime;
  }

  /// Check if a task has a scheduled refresh
  bool hasScheduledRefresh(String taskId) {
    return _scheduledRefreshes.containsKey(taskId);
  }

  /// Cancel a scheduled refresh for the given task ID
  void cancelScheduledRefresh(String taskId) {
    final data = _scheduledRefreshes.remove(taskId);
    if (data != null) {
      data.timer.cancel();
      developer.log(
        'Cancelled scheduled refresh',
        name: 'DirectTaskSummaryRefresh',
        error: {'taskId': taskId},
      );
      _updateState();
    }
  }

  /// Trigger a refresh immediately, bypassing the countdown
  Future<void> triggerImmediately(String taskId) async {
    developer.log(
      'Triggering immediate refresh',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Cancel any existing scheduled refresh
    final data = _scheduledRefreshes.remove(taskId);
    if (data != null) {
      data.timer.cancel();
      _updateState();
    }

    // Trigger the refresh now
    await _triggerTaskSummaryRefresh(taskId);
  }

  /// Request a task summary refresh for the given task ID
  /// This method is called directly from checklist action handlers
  Future<void> requestTaskSummaryRefresh(String taskId) async {
    developer.log(
      'Direct refresh request received',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Check if inference is already running
    final isRunning = ref.read(
      inferenceStatusControllerProvider(
        id: taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    if (isRunning == InferenceStatus.running) {
      developer.log(
        'Inference already running, setting up listener',
        name: 'DirectTaskSummaryRefresh',
        error: {'taskId': taskId},
      );

      // Cancel any existing scheduled refresh to prevent it from firing
      // while inference is active
      final existingData = _scheduledRefreshes.remove(taskId);
      if (existingData != null) {
        existingData.timer.cancel();
        _updateState();
      }

      _statusListener.setupListener(
        taskId: taskId,
        onInferenceComplete: requestTaskSummaryRefresh,
      );
      return;
    }

    // If already scheduled, don't reset the timer (batch into existing countdown)
    if (_scheduledRefreshes.containsKey(taskId)) {
      developer.log(
        'Refresh already scheduled, batching request',
        name: 'DirectTaskSummaryRefresh',
        error: {
          'taskId': taskId,
          'scheduledTime':
              _scheduledRefreshes[taskId]!.scheduledTime.toIso8601String(),
        },
      );
      return;
    }

    // Schedule new refresh
    developer.log(
      'Scheduling refresh with ${scheduledRefreshDelay.inMinutes} minute delay',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    final scheduledTime = DateTime.now().add(scheduledRefreshDelay);
    final timer = Timer(
      scheduledRefreshDelay,
      () => _onTimerFired(taskId),
    );

    _scheduledRefreshes[taskId] = ScheduledRefreshData(
      scheduledTime: scheduledTime,
      timer: timer,
    );

    _updateState();
  }

  void _onTimerFired(String taskId) {
    developer.log(
      'Scheduled refresh timer fired',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Remove from scheduled map
    _scheduledRefreshes.remove(taskId);
    _updateState();

    // Trigger the refresh
    _triggerTaskSummaryRefresh(taskId);
  }

  Future<void> _triggerTaskSummaryRefresh(String taskId) async {
    developer.log(
      'Starting direct refresh trigger',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    try {
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
    }
  }
}

/// Provider that exposes the scheduled refresh time for a specific task
@riverpod
DateTime? scheduledTaskSummaryRefresh(
  Ref ref, {
  required String taskId,
}) {
  // Watch the main controller's state to get updates
  final state = ref.watch(directTaskSummaryRefreshControllerProvider);
  return state.getScheduledTime(taskId);
}
