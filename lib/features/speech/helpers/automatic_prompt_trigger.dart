import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
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
  Future<void> triggerAutomaticPrompts(
    String entryId,
    String categoryId,
    AudioRecorderState state, {
    required bool isLinkedToTask,
    String? linkedTaskId,
    bool realtimeTranscriptProvided = false,
  }) async {
    try {
      // Profile-driven path: check if task's agent profile handles
      // transcription. When handled, skip the entire legacy path.
      if (linkedTaskId != null) {
        try {
          final automationService = ref.read(profileAutomationServiceProvider);
          final result = await automationService.tryTranscribe(
            taskId: linkedTaskId,
            enableSpeechRecognition: state.enableSpeechRecognition,
          );
          if (result.handled && !realtimeTranscriptProvided) {
            loggingService.captureEvent(
              'Profile-driven transcription for task $linkedTaskId '
              'using skill "${result.skill!.id}"',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
            final runner = ref.read(skillInferenceRunnerProvider);
            await runner.runTranscription(
              audioEntryId: entryId,
              automationResult: result,
              linkedTaskId: linkedTaskId,
            );
            return; // Skip legacy path entirely
          }
        } catch (profileException, profileStackTrace) {
          loggingService.captureException(
            profileException,
            domain: 'automatic_prompt_trigger',
            subDomain: 'profilePreflight',
            stackTrace: profileStackTrace,
          );
          // Fall through to legacy path.
        }
      }

      // Legacy path: use category-configured automatic prompts.
      final category = await categoryRepository.getCategoryById(categoryId);

      if (category?.automaticPrompts != null) {
        // Determine if speech recognition should be triggered
        final hasAutomaticTranscription =
            category!.automaticPrompts!.containsKey(
              AiResponseType.audioTranscription,
            ) &&
            category
                .automaticPrompts![AiResponseType.audioTranscription]!
                .isNotEmpty;
        final shouldTriggerTranscription =
            state.enableSpeechRecognition ?? hasAutomaticTranscription;

        // Trigger audio transcription if enabled (skip if realtime already
        // produced a transcript, e.g. from live transcription mode)
        if (shouldTriggerTranscription &&
            hasAutomaticTranscription &&
            !realtimeTranscriptProvided) {
          final transcriptionPromptIds =
              category.automaticPrompts![AiResponseType.audioTranscription]!;

          // Get the first available prompt for the current platform
          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt = await capabilityFilter
              .getFirstAvailablePrompt(
                transcriptionPromptIds,
              );

          if (availablePrompt == null) {
            loggingService.captureEvent(
              'No available audio transcription prompts for current platform',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );
          } else {
            final promptId = availablePrompt.id;

            loggingService.captureEvent(
              'Triggering audio transcription (user preference: ${state.enableSpeechRecognition})',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            );

            unawaited(
              ref
                  .read(
                    triggerNewInferenceProvider((
                      entityId: entryId,
                      promptId: promptId,
                      linkedEntityId: linkedTaskId,
                    )).future,
                  )
                  .catchError((Object error, StackTrace stackTrace) {
                    loggingService.captureException(
                      error,
                      domain: 'automatic_prompt_trigger',
                      subDomain: 'triggerAutomaticPrompts',
                      stackTrace: stackTrace,
                    );
                  }),
            );
          }
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
