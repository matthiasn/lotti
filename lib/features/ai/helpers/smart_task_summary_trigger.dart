import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'smart_task_summary_trigger.g.dart';

/// Smart task summary trigger with simplified UX.
///
/// This helper encapsulates the logic for when to create or update task summaries:
///
/// - If task **already has a summary**: schedule 5-min update (existing countdown mechanism)
/// - If task **has NO summary** AND category has auto-summary enabled: create immediately
///
/// Call this when meaningful content is added to a task:
/// - Image analysis completion
/// - Audio transcription completion
/// - Manual text save (non-empty content)
class SmartTaskSummaryTrigger {
  SmartTaskSummaryTrigger({
    required this.ref,
    required this.loggingService,
    required this.categoryRepository,
  });

  final Ref ref;
  final LoggingService loggingService;
  final CategoryRepository categoryRepository;

  /// Triggers task summary creation/update based on simplified logic.
  ///
  /// Parameters:
  /// - [taskId]: The task to update summary for
  /// - [categoryId]: The category to check for automatic summary configuration
  ///
  /// Logic:
  /// 1. Check if task already has a summary
  /// 2. If yes: schedule 5-min countdown update (batches with existing)
  /// 3. If no: check if category has auto-summary enabled
  /// 4. If auto-summary enabled: create first summary immediately
  Future<void> triggerTaskSummary({
    required String taskId,
    required String? categoryId,
  }) async {
    if (categoryId == null) return;

    try {
      // Check if task already has a summary
      final latestSummary = await ref.read(
        latestSummaryControllerProvider(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ).future,
      );

      final hasSummary = latestSummary != null;

      if (hasSummary) {
        // Existing summary: use 5-minute countdown mechanism
        loggingService.captureEvent(
          'Task $taskId has existing summary, scheduling 5-min update',
          domain: 'smart_task_summary_trigger',
          subDomain: 'triggerTaskSummary',
        );
        await ref
            .read(directTaskSummaryRefreshControllerProvider.notifier)
            .requestTaskSummaryRefresh(taskId);
      } else {
        // No summary yet: check if category has auto-summary enabled
        final category = await categoryRepository.getCategoryById(categoryId);
        final hasAutoSummary = category?.automaticPrompts != null &&
            category!.automaticPrompts!
                .containsKey(AiResponseType.taskSummary) &&
            category.automaticPrompts![AiResponseType.taskSummary]!.isNotEmpty;

        if (hasAutoSummary) {
          // Create first summary immediately
          loggingService.captureEvent(
            'No summary exists for task $taskId, creating first summary immediately',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          );

          final summaryPromptIds =
              category.automaticPrompts![AiResponseType.taskSummary]!;

          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt =
              await capabilityFilter.getFirstAvailablePrompt(
            summaryPromptIds,
          );

          if (availablePrompt != null) {
            await ref.read(
              triggerNewInferenceProvider(
                entityId: taskId,
                promptId: availablePrompt.id,
              ).future,
            );
          } else {
            loggingService.captureEvent(
              'No available task summary prompts for current platform',
              domain: 'smart_task_summary_trigger',
              subDomain: 'triggerTaskSummary',
            );
          }
        } else {
          loggingService.captureEvent(
            'No summary and no auto-summary configured for task $taskId, skipping',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          );
        }
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'smart_task_summary_trigger',
        subDomain: 'triggerTaskSummary',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider for the smart task summary trigger.
@riverpod
SmartTaskSummaryTrigger smartTaskSummaryTrigger(Ref ref) {
  return SmartTaskSummaryTrigger(
    ref: ref,
    loggingService: getIt<LoggingService>(),
    categoryRepository: ref.read(categoryRepositoryProvider),
  );
}
