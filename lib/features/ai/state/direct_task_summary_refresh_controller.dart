import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final Map<String, ProviderSubscription<InferenceStatus>>
      _statusListenerCleanups = {};

  @override
  void build() {
    ref.onDispose(() {
      // Cancel all timers
      for (final timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();

      // Clean up all status listeners
      for (final subscription in _statusListenerCleanups.values) {
        subscription.close();
      }
      _statusListenerCleanups.clear();
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
      _setupStatusListener(taskId);
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

  /// Sets up a listener for when inference status changes from running to idle/error
  void _setupStatusListener(String taskId) {
    // Clean up any existing listener for this task
    _statusListenerCleanups[taskId]?.close();

    // Create a new listener
    final cleanup = ref.listen(
      inferenceStatusControllerProvider(
        id: taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
      (previous, next) {
        developer.log(
          'Inference status changed',
          name: 'DirectTaskSummaryRefresh',
          error: {
            'taskId': taskId,
            'previous': previous?.toString(),
            'next': next.toString(),
          },
        );

        // If status changed from running to idle or error, trigger refresh
        if (previous == InferenceStatus.running &&
            (next == InferenceStatus.idle || next == InferenceStatus.error)) {
          developer.log(
            'Inference completed, triggering pending refresh',
            name: 'DirectTaskSummaryRefresh',
            error: {'taskId': taskId},
          );

          // Clean up the listener
          _statusListenerCleanups.remove(taskId)?.close();

          // Trigger the refresh
          requestTaskSummaryRefresh(taskId);
        }
      },
      fireImmediately: false,
    );

    _statusListenerCleanups[taskId] = cleanup;
  }

  Future<void> _triggerTaskSummaryRefresh(String taskId) async {
    developer.log(
      'Starting direct refresh trigger',
      name: 'DirectTaskSummaryRefresh',
      error: {'taskId': taskId},
    );

    // Remove the timer since it fired
    _debounceTimers.remove(taskId);

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
