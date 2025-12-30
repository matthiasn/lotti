import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
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
  /// For checklist updates:
  /// - Only triggers if linked to a task
  /// - Waits for transcription to complete first (if transcription is triggered)
  /// - Triggered if category has automatic checklist updates configured
  ///
  /// For task summary:
  /// - Only triggers if linked to a task
  /// - Waits for transcription and checklist updates to complete first
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

        // Determine if checklist updates should be triggered
        final hasAutomaticChecklistUpdates = category.automaticPrompts!
                .containsKey(AiResponseType.checklistUpdates) &&
            category
                .automaticPrompts![AiResponseType.checklistUpdates]!.isNotEmpty;
        final shouldTriggerChecklistUpdates = isLinkedToTask &&
            (state.enableChecklistUpdates ?? hasAutomaticChecklistUpdates);

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

          // Get the first available prompt for the current platform
          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt =
              await capabilityFilter.getFirstAvailablePrompt(
            transcriptionPromptIds,
          );

          if (availablePrompt == null) {
            loggingService.captureEvent(
              'No available audio transcription prompts for current platform',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            // Continue with other prompts instead of returning early
          } else {
            final promptId = availablePrompt.id;

            loggingService.captureEvent(
              'Triggering audio transcription (user preference: ${state.enableSpeechRecognition})',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );

            // Store the transcription future so we can wait for it if needed
            transcriptionFuture = ref.read(
              triggerNewInferenceProvider((
                entityId: entryId,
                promptId: promptId,
                linkedEntityId: linkedTaskId,
              )).future,
            );

            final shouldAwaitTranscriptionImmediately = linkedTaskId == null ||
                (!shouldTriggerChecklistUpdates && !shouldTriggerTaskSummary);
            // If no follow-up prompts require the transcript, await it now to
            // keep recorder state consistent. Otherwise subsequent steps will
            // await before firing.
            if (shouldAwaitTranscriptionImmediately) {
              await transcriptionFuture;
            }
          }
        }

        // Trigger checklist updates if enabled and linked to task
        Future<void>? checklistUpdatesFuture;
        if (shouldTriggerChecklistUpdates &&
            linkedTaskId != null &&
            hasAutomaticChecklistUpdates) {
          final checklistUpdatesPromptIds =
              category.automaticPrompts![AiResponseType.checklistUpdates]!;

          // Get the first available prompt for the current platform
          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt =
              await capabilityFilter.getFirstAvailablePrompt(
            checklistUpdatesPromptIds,
          );

          if (availablePrompt == null) {
            loggingService.captureEvent(
              'No available checklist update prompts for current platform',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            // Continue with other prompts
          } else {
            final promptId = availablePrompt.id;

            loggingService.captureEvent(
              'Triggering checklist updates for task $linkedTaskId (transcription pending: ${transcriptionFuture != null})',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );

            // If transcription was triggered, wait for it to complete
            if (transcriptionFuture != null) {
              loggingService.captureEvent(
                'Waiting for transcription to complete before checklist updates',
                domain: 'automatic_prompt_trigger',
                subDomain: 'triggerAutomaticPrompts',
              );
              await transcriptionFuture;
              loggingService.captureEvent(
                'Transcription completed, now triggering checklist updates',
                domain: 'automatic_prompt_trigger',
                subDomain: 'triggerAutomaticPrompts',
              );
            }

            // Trigger checklist updates on the task entity, but pass the audio entry as linkedEntityId
            checklistUpdatesFuture = ref.read(
              triggerNewInferenceProvider((
                entityId: linkedTaskId,
                promptId: promptId,
                linkedEntityId: entryId,
              )).future,
            );

            // If task summary is not needed, await checklist updates
            if (!shouldTriggerTaskSummary) {
              await checklistUpdatesFuture;
            }
          }
        }

        // Trigger task summary if enabled and linked to task
        if (shouldTriggerTaskSummary &&
            linkedTaskId != null &&
            hasAutomaticTaskSummary) {
          final taskSummaryPromptIds =
              category.automaticPrompts![AiResponseType.taskSummary]!;

          // Get the first available prompt for the current platform
          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt =
              await capabilityFilter.getFirstAvailablePrompt(
            taskSummaryPromptIds,
          );

          if (availablePrompt == null) {
            loggingService.captureEvent(
              'No available task summary prompts for current platform',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            return;
          }

          final promptId = availablePrompt.id;

          loggingService.captureEvent(
            'Triggering task summary for task $linkedTaskId (user preference: ${state.enableTaskSummary}, transcription pending: ${transcriptionFuture != null}, checklist updates pending: ${checklistUpdatesFuture != null})',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          );

          // Wait for any pending operations to complete
          // This ensures the task summary includes all updates
          if (transcriptionFuture != null && checklistUpdatesFuture == null) {
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
          } else if (checklistUpdatesFuture != null) {
            loggingService.captureEvent(
              'Waiting for checklist updates to complete before task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            await checklistUpdatesFuture;
            loggingService.captureEvent(
              'Checklist updates completed, now triggering task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
          }

          // Trigger task summary on the task entity, not the audio entry
          await ref.read(
            triggerNewInferenceProvider((
              entityId: linkedTaskId,
              promptId: promptId,
              linkedEntityId: null,
            )).future,
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
