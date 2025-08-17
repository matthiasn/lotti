import 'dart:async';

import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/task_relevance_checker.dart';
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
  late final TaskRelevanceChecker _relevanceChecker;

  @override
  void build({
    required String taskId,
  }) {
    _relevanceChecker = TaskRelevanceChecker(taskId: taskId);

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
        // Skip only if the update is solely an AI response notification
        if (_relevanceChecker.shouldSkipNotification(affectedIds)) {
          return;
        }

        // Check if any of the affected IDs are relevant to this task
        final isRelevant =
            await _relevanceChecker.isUpdateRelevantToTask(affectedIds);
        if (isRelevant) {
          _scheduleRefresh();
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
        // Ensure we attempt again after the current run settles
        _hasPendingRefresh = true;
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
