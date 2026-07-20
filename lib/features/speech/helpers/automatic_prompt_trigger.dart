import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

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
  final DomainLogger loggingService;

  /// Triggers automatic transcription via profile-driven automation.
  ///
  /// Requires a [linkedTaskId] whose agent has a profile with a transcription
  /// skill assigned. If no profile handles it, logs and returns silently.
  Future<void> triggerAutomaticPrompts(
    String entryId,
    AudioRecorderState state, {
    String? linkedTaskId,
  }) async {
    try {
      if (linkedTaskId == null) {
        loggingService.log(
          LogDomain.ai,
          'No linked task for entry $entryId — skipping automatic '
          'transcription',
          subDomain: 'triggerAutomaticPrompts',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryTranscribe(
        taskId: linkedTaskId,
        enableSpeechRecognition: state.enableSpeechRecognition,
      );

      if (!result.handled) {
        loggingService.log(
          LogDomain.ai,
          'Profile automation did not handle transcription for '
          'task $linkedTaskId (handled=${result.handled})',
          subDomain: 'triggerAutomaticPrompts',
        );
        return;
      }

      loggingService.log(
        LogDomain.ai,
        'Profile-driven transcription for task $linkedTaskId '
        'using skill "${result.skill!.id}"',
        subDomain: 'triggerAutomaticPrompts',
      );

      final runner = ref.read(skillInferenceRunnerProvider);
      await runner.runTranscription(
        audioEntryId: entryId,
        automationResult: result,
        linkedTaskId: linkedTaskId,
      );

      // Transcription added real content to the task — nudge the task agent
      // immediately so it processes the new transcript without waiting out
      // the standard 2-minute throttle. The manual wake clears any pending
      // throttle deadline (and its UI countdown) and supersedes any queued
      // subscription job.
      await _nudgeTaskAgent(
        entryId: entryId,
        linkedTaskId: linkedTaskId,
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'triggerAutomaticPrompts',
      );
    }
  }

  /// Nudge the task's agent so a freshly-completed transcription is
  /// processed immediately, bypassing the 2-minute subscription throttle.
  ///
  /// Honors the automatic-updates opt-in: when the user has switched
  /// automatic updates off, the report is only marked stale (surfacing the
  /// manual "Wake agent" CTA) and no inference is enqueued.
  ///
  /// No-op when no task agent is registered for [linkedTaskId]. Failures
  /// are logged but never propagate — a missed nudge is recoverable via
  /// the standard subscription path; throwing here would abort the caller.
  Future<void> _nudgeTaskAgent({
    required String entryId,
    required String linkedTaskId,
  }) async {
    try {
      final taskAgentService = ref.read(taskAgentServiceProvider);
      final agent = await taskAgentService.getTaskAgentForTask(linkedTaskId);
      if (agent == null) return;
      final woken = ref
          .read(wakeOrchestratorProvider)
          .requestContentWake(
            agentId: agent.agentId,
            reason: WakeReason.transcriptionComplete.name,
            triggerTokens: {linkedTaskId, entryId},
          );
      loggingService.log(
        LogDomain.ai,
        '${woken ? 'Nudged' : 'Marked report stale for'} task agent '
        '${agent.agentId} after transcription completion '
        '(task $linkedTaskId, entry $entryId)',
        subDomain: 'nudgeTaskAgent',
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'nudgeTaskAgent',
      );
    }
  }
}

/// Provider for the automatic prompt trigger helper
final automaticPromptTriggerProvider = Provider<AutomaticPromptTrigger>((ref) {
  return AutomaticPromptTrigger(
    ref: ref,
    loggingService: getIt<DomainLogger>(),
  );
});
