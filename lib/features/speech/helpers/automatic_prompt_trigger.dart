import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Helper class to handle automatic prompt triggering after audio recording.
///
/// Uses the profile-driven automation path exclusively. When a task has an
/// agent with a profile that includes a transcription skill, the skill is
/// invoked via [SkillInferenceRunner]. Otherwise, nothing happens.
class AutomaticPromptTrigger {
  AutomaticPromptTrigger({
    required this.ref,
    required this.loggingService,
  });

  final Ref ref;
  final LoggingService loggingService;

  /// Triggers automatic transcription via profile-driven automation.
  ///
  /// Requires a [linkedTaskId] whose agent has a profile with a transcription
  /// skill assigned. If no profile handles it, logs and returns silently.
  Future<void> triggerAutomaticPrompts(
    String entryId,
    String categoryId,
    AudioRecorderState state, {
    required bool isLinkedToTask,
    String? linkedTaskId,
    bool realtimeTranscriptProvided = false,
  }) async {
    try {
      if (linkedTaskId == null) {
        loggingService.captureEvent(
          'No linked task for entry $entryId — skipping automatic '
          'transcription',
          domain: 'automatic_prompt_trigger',
          subDomain: 'triggerAutomaticPrompts',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryTranscribe(
        taskId: linkedTaskId,
        enableSpeechRecognition: state.enableSpeechRecognition,
      );

      if (!result.handled || realtimeTranscriptProvided) {
        loggingService.captureEvent(
          'Profile automation did not handle transcription for '
          'task $linkedTaskId (handled=${result.handled}, '
          'realtimeProvided=$realtimeTranscriptProvided)',
          domain: 'automatic_prompt_trigger',
          subDomain: 'triggerAutomaticPrompts',
        );
        return;
      }

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
  );
});
