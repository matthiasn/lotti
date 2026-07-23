import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Helper class to handle automatic image analysis after image import.
///
/// Uses the profile-driven automation path exclusively. When a task has an
/// agent with a profile that includes an image analysis skill, the skill is
/// invoked via [SkillInferenceRunner]. Otherwise, nothing happens.
class AutomaticImageAnalysisTrigger {
  AutomaticImageAnalysisTrigger({
    required this.ref,
    required this.loggingService,
  });

  final Ref ref;
  final DomainLogger loggingService;

  /// Triggers automatic image analysis via profile-driven automation.
  ///
  /// Requires a [linkedTaskId] whose agent has a profile with an image
  /// analysis skill assigned. If no profile handles it, logs and returns
  /// silently.
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
  }) async {
    try {
      if (linkedTaskId == null) {
        loggingService.log(
          LogDomain.ai,
          'No linked task for image $imageEntryId — skipping automatic '
          'image analysis',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryAnalyzeImage(
        taskId: linkedTaskId,
      );

      if (!result.handled) {
        loggingService.log(
          LogDomain.ai,
          'Profile automation did not handle image analysis for '
          'task $linkedTaskId',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      loggingService.log(
        LogDomain.ai,
        'Profile-driven image analysis for task $linkedTaskId '
        'using skill "${result.skill!.id}"',
        subDomain: 'triggerAutomaticImageAnalysis',
      );

      final runner = ref.read(skillInferenceRunnerProvider);
      await runner.runImageAnalysis(
        imageEntryId: imageEntryId,
        automationResult: result,
        linkedTaskId: linkedTaskId,
      );

      // The analysis is stored as an AiResponseEntry linked from the IMAGE,
      // so the task never receives a change notification for it. Nudge the
      // task agent explicitly — mirroring the post-transcription nudge — so
      // it processes the freshly extracted image content (summary/OCR)
      // without waiting for an unrelated wake.
      await _nudgeTaskAgent(
        imageEntryId: imageEntryId,
        linkedTaskId: linkedTaskId,
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'triggerAutomaticImageAnalysis',
      );
    }
  }

  /// Nudge the task's agent so a freshly-completed image analysis is
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
    required String imageEntryId,
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
            reason: WakeReason.imageAnalysisComplete.name,
            triggerTokens: {linkedTaskId, imageEntryId},
          );
      loggingService.log(
        LogDomain.ai,
        '${woken ? 'Nudged' : 'Marked report stale for'} task agent '
        '${agent.agentId} after image analysis completion '
        '(task $linkedTaskId, image $imageEntryId)',
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

/// Provider for the automatic image analysis trigger helper.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.
final automaticImageAnalysisTriggerProvider =
    Provider<AutomaticImageAnalysisTrigger>(
      automaticImageAnalysisTrigger,
      name: 'automaticImageAnalysisTriggerProvider',
    );
AutomaticImageAnalysisTrigger automaticImageAnalysisTrigger(Ref ref) {
  return AutomaticImageAnalysisTrigger(
    ref: ref,
    loggingService: getIt<DomainLogger>(),
  );
}
