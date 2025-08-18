import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_refresh_service.g.dart';

/// Service that handles task summary refresh operations for checklists
/// This centralizes the logic that was duplicated across repositories
@riverpod
TaskSummaryRefreshService taskSummaryRefreshService(Ref ref) {
  return TaskSummaryRefreshService(ref);
}

class TaskSummaryRefreshService {
  TaskSummaryRefreshService(this._ref);

  final Ref _ref;

  /// Triggers task summary refresh for all tasks linked to a checklist
  /// This is called after checklist modifications to update task summaries
  Future<void> triggerTaskSummaryRefreshForChecklist({
    required String checklistId,
    required String callingDomain,
  }) async {
    try {
      final checklistEntity = await _ref
          .read(journalRepositoryProvider)
          .getJournalEntityById(checklistId);

      if (checklistEntity is Checklist) {
        // Iterate through all linked tasks and trigger refresh for each
        for (final taskId in checklistEntity.data.linkedTasks) {
          await _ref
              .read(directTaskSummaryRefreshControllerProvider.notifier)
              .requestTaskSummaryRefresh(taskId);
        }
      }
    } catch (e, stackTrace) {
      // Log the error but don't fail the operation
      getIt<LoggingService>().captureException(
        e,
        domain: callingDomain,
        subDomain: 'triggerTaskSummaryRefreshForChecklist',
        stackTrace: stackTrace,
      );
    }
  }
}
