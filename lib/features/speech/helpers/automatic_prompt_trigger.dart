import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Helper class to handle automatic prompt triggering after audio recording
class AutomaticPromptTrigger {
  AutomaticPromptTrigger({
    required this.ref,
    required this.loggingService,
    required this.categoryRepository,
  });

  final Ref ref;
  final LoggingService loggingService;
  final CategoryRepository categoryRepository;

  /// Triggers automatic prompts based on category configuration
  ///
  /// This method checks the category's automatic prompt settings and the user's
  /// preferences (from recorder state) to determine which prompts to trigger.
  ///
  /// For audio transcription:
  /// - Triggers if user preference is true, OR
  /// - Triggers if user preference is null AND category has automatic transcription configured
  ///
  /// For task summary:
  /// - Only triggers if linked to a task
  /// - Waits for transcription to complete first (if transcription is triggered)
  /// - Uses same preference logic as transcription
  Future<void> triggerAutomaticPrompts(
    String entryId,
    String categoryId,
    AudioRecorderState state, {
    required bool isLinkedToTask,
    String? linkedTaskId,
  }) async {
    try {
      final category = await categoryRepository.getCategoryById(categoryId);

      if (category?.automaticPrompts != null) {
        // Determine if speech recognition should be triggered
        final hasAutomaticTranscription = category!.automaticPrompts!
                .containsKey(AiResponseType.audioTranscription) &&
            category.automaticPrompts![AiResponseType.audioTranscription]!
                .isNotEmpty;
        final shouldTriggerTranscription =
            state.enableSpeechRecognition ?? hasAutomaticTranscription;

        // Determine if task summary should be triggered
        final hasAutomaticTaskSummary = category.automaticPrompts!
                .containsKey(AiResponseType.taskSummary) &&
            category.automaticPrompts![AiResponseType.taskSummary]!.isNotEmpty;
        final shouldTriggerTaskSummary = isLinkedToTask &&
            (state.enableTaskSummary ?? hasAutomaticTaskSummary);

        // Trigger audio transcription if enabled
        Future<void>? transcriptionFuture;
        if (shouldTriggerTranscription && hasAutomaticTranscription) {
          final transcriptionPromptIds =
              category.automaticPrompts![AiResponseType.audioTranscription]!;
          final promptId = transcriptionPromptIds.first;

          loggingService.captureEvent(
            'Triggering audio transcription (user preference: ${state.enableSpeechRecognition})',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          );

          // Store the transcription future so we can wait for it if needed
          transcriptionFuture = ref.read(
            triggerNewInferenceProvider(
              entityId: entryId,
              promptId: promptId,
              linkedEntityId: linkedTaskId,
            ).future,
          );

          // If task summary is not needed, we can await the transcription here
          // Otherwise, we'll wait for it before triggering task summary
          if (!shouldTriggerTaskSummary || linkedTaskId == null) {
            await transcriptionFuture;
          }
        }

        // Trigger task summary if enabled and linked to task
        if (shouldTriggerTaskSummary &&
            linkedTaskId != null &&
            hasAutomaticTaskSummary) {
          final taskSummaryPromptIds =
              category.automaticPrompts![AiResponseType.taskSummary]!;
          final promptId = taskSummaryPromptIds.first;

          loggingService.captureEvent(
            'Triggering task summary for task $linkedTaskId (user preference: ${state.enableTaskSummary}, transcription pending: ${transcriptionFuture != null})',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          );

          // If transcription was triggered, wait for it to complete
          // This ensures the task summary includes the transcribed content
          if (transcriptionFuture != null) {
            loggingService.captureEvent(
              'Waiting for transcription to complete before task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            await transcriptionFuture;
            loggingService.captureEvent(
              'Transcription completed, now triggering task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
          }

          // Trigger task summary on the task entity, not the audio entry
          await ref.read(
            triggerNewInferenceProvider(
              entityId: linkedTaskId,
              promptId: promptId,
            ).future,
          );
        }
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'automatic_prompt_trigger',
        subDomain: 'triggerAutomaticPrompts',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider for the automatic prompt trigger helper
final automaticPromptTriggerProvider = Provider<AutomaticPromptTrigger>((ref) {
  return AutomaticPromptTrigger(
    ref: ref,
    loggingService: getIt<LoggingService>(),
    categoryRepository: ref.read(categoryRepositoryProvider),
  );
});
