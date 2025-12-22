import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';

/// Manages status listeners for task summary refresh operations
/// This class handles the lifecycle of listeners that monitor inference status changes
class TaskSummaryRefreshStatusListener {
  TaskSummaryRefreshStatusListener(this._ref);

  final Ref _ref;
  final Map<String, ProviderSubscription<InferenceStatus>>
      _statusListenerCleanups = {};

  /// Sets up a listener for when inference status changes from running to idle/error
  /// Returns true if a listener was set up, false if it already existed
  bool setupListener({
    required String taskId,
    required void Function(String taskId) onInferenceComplete,
  }) {
    developer.log(
      'Setting up status listener',
      name: 'TaskSummaryRefreshStatusListener',
      error: {'taskId': taskId},
    );

    // Check if listener already exists
    if (_statusListenerCleanups.containsKey(taskId)) {
      developer.log(
        'Listener already exists for task',
        name: 'TaskSummaryRefreshStatusListener',
        error: {'taskId': taskId},
      );
      return false;
    }

    // Create a new listener
    final cleanup = _ref.listen(
      inferenceStatusControllerProvider(
        id: taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
      (previous, next) {
        developer.log(
          'Inference status changed',
          name: 'TaskSummaryRefreshStatusListener',
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
            'Inference completed, triggering callback',
            name: 'TaskSummaryRefreshStatusListener',
            error: {'taskId': taskId},
          );

          // Clean up the listener
          removeListener(taskId);

          // Trigger the callback
          onInferenceComplete(taskId);
        }
      },
      fireImmediately: false,
    );

    _statusListenerCleanups[taskId] = cleanup;
    return true;
  }

  /// Removes a specific listener for a task
  /// Returns true if a listener was removed, false if none existed
  bool removeListener(String taskId) {
    final cleanup = _statusListenerCleanups.remove(taskId);
    if (cleanup != null) {
      developer.log(
        'Removing listener for task',
        name: 'TaskSummaryRefreshStatusListener',
        error: {'taskId': taskId},
      );
      cleanup.close();
      return true;
    }
    return false;
  }

  /// Removes all listeners and cleans up resources
  void dispose() {
    developer.log(
      'Disposing all listeners',
      name: 'TaskSummaryRefreshStatusListener',
      error: {'count': _statusListenerCleanups.length},
    );

    for (final subscription in _statusListenerCleanups.values) {
      subscription.close();
    }
    _statusListenerCleanups.clear();
  }
}
