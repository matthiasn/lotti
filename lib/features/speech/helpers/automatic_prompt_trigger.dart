import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/subject_agent_lookup.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/domain_logging.dart';

/// Helper class to handle automatic prompt triggering after audio recording.
///
/// Uses the profile-driven automation path exclusively. When the recording's
/// subject entity has an agent whose profile includes a transcription skill,
/// the skill is invoked via [SkillInferenceRunner]. Otherwise, nothing
/// happens.
///
/// The subject is whatever the recording was linked to — a task, a project, an
/// event, a person, or a goal. Everything here is kind-agnostic except the
/// task context handed to the transcription prompt, which only a task can
/// supply, and the consent question for a goal: a goal has no category to
/// answer it, so its agent's automatic-updates switch decides instead.
class AutomaticPromptTrigger {
  AutomaticPromptTrigger({
    required this.ref,
    required this.loggingService,
  });

  final Ref ref;
  final DomainLogger loggingService;

  /// Triggers automatic transcription via profile-driven automation.
  ///
  /// Requires a [linkedSubjectId] whose agent has a profile with a
  /// transcription skill assigned. If no profile handles it, logs and returns
  /// silently.
  Future<void> triggerAutomaticPrompts(
    String entryId,
    AudioRecorderState state, {
    String? linkedSubjectId,
  }) async {
    try {
      if (linkedSubjectId == null) {
        loggingService.log(
          LogDomain.ai,
          'No linked subject for entry $entryId — skipping automatic '
          'transcription',
          subDomain: 'triggerAutomaticPrompts',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryTranscribe(
        subjectId: linkedSubjectId,
        enableSpeechRecognition: state.enableSpeechRecognition,
      );

      if (!result.handled) {
        loggingService.log(
          LogDomain.ai,
          'Profile automation did not handle transcription for '
          'subject $linkedSubjectId (handled=${result.handled})',
          subDomain: 'triggerAutomaticPrompts',
        );
        await _transcribeGoalCheckIn(
          entryId: entryId,
          linkedSubjectId: linkedSubjectId,
        );
        return;
      }

      loggingService.log(
        LogDomain.ai,
        'Profile-driven transcription for subject $linkedSubjectId '
        'using skill "${result.skill!.id}"',
        subDomain: 'triggerAutomaticPrompts',
      );

      final runner = ref.read(skillInferenceRunnerProvider);
      await runner.runTranscription(
        audioEntryId: entryId,
        automationResult: result,
        linkedTaskId: await _taskIdIfTask(linkedSubjectId),
      );

      // Transcription added real content to the subject — nudge its agent
      // immediately so it processes the new transcript without waiting out
      // the standard 2-minute throttle. The manual wake clears any pending
      // throttle deadline (and its UI countdown) and supersedes any queued
      // subscription job.
      await _nudgeSubjectAgent(
        entryId: entryId,
        linkedSubjectId: linkedSubjectId,
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

  /// Transcribes a goal check-in that the category gate just declined.
  ///
  /// A check-in is an ordinary `JournalAudio` linked to a goal's journal
  /// entry, which belongs to no task and no category — so the profile
  /// automation above always declines it, and for a long time that decline was
  /// a log line: every check-in saved, played back, and was never transcribed.
  ///
  /// This runs here, on the controller's stop path, rather than in the goal
  /// composer that opened the recorder, because the composer only learns of a
  /// recording it awaited. A recording stopped from the sidebar's Stop button
  /// or the floating indicator after the sheet was dismissed reaches
  /// `AudioRecorderController.stop` — and therefore this method — without the
  /// composer ever hearing back. Handling it once, here, covers every way a
  /// recording ends.
  ///
  /// The consent signal is the goal agent's own automatic-updates switch, the
  /// one the user sees on the goal. Switched off is a decision, not a failure,
  /// but on the check-ins rail the two look identical unless it is recorded —
  /// so the decline is written as a visible failed state, and Retry is the
  /// affordance for transcribing this one by hand.
  Future<void> _transcribeGoalCheckIn({
    required String entryId,
    required String linkedSubjectId,
  }) async {
    final agent = await ref.read(subjectAgentResolverProvider)(
      linkedSubjectId,
    );
    if (agent == null || agent.kind != AgentKinds.goalAgent) return;

    // Null reads as on, as `GoalAgentService.automaticUpdatesEnabled` reads
    // it: goals created before the switch existed shipped with updates on, and
    // the task-agent default of off would silently stop transcribing every
    // check-in on them.
    final automaticUpdatesEnabled =
        agent.config.automaticUpdatesEnabled ?? true;
    if (!automaticUpdatesEnabled) {
      loggingService.log(
        LogDomain.ai,
        'automatic updates are off for goal ${agent.agentId} — check-in '
        '$entryId stays untranscribed until it is triggered by hand',
        subDomain: 'triggerAutomaticPrompts',
      );
      await recordTranscriptionDecline(
        ref,
        entityId: entryId,
        reason: 'automatic updates are off for goal ${agent.agentId}',
        message: deviceMessages().goalCheckInTranscriptionOff,
      );
      return;
    }

    loggingService.log(
      LogDomain.ai,
      'transcribing check-in $entryId for goal ${agent.agentId}',
      subDomain: 'triggerAutomaticPrompts',
    );
    // The shared skill trigger — the same entry point the AI popup and the
    // timeline's Retry use — so a check-in transcribes with the same skill,
    // the same model resolution (including the category-less direct
    // fallback) and the same failure reporting as every other recording.
    await ref.read(
      triggerSkillProvider((
        entityId: entryId,
        skillId: skillTranscribeContextId,
        linkedTaskId: null,
        referenceImages: null,
        overrideModelId: null,
        geminiThinkingMode: null,
      )).future,
    );
  }

  /// [subjectId] when it names a task, `null` for every other subject kind.
  ///
  /// `runTranscription`'s `linkedTaskId` feeds `buildTaskDetailsJson` *and*
  /// the consumption record's `taskId` field. Passing a person's id there
  /// files the spend under a task that does not exist, so the task context is
  /// withheld rather than faked for non-task subjects.
  Future<String?> _taskIdIfTask(String subjectId) async {
    final entity = await ref
        .read(journalDbProvider)
        .journalEntityById(subjectId);
    return entity is Task ? subjectId : null;
  }

  /// Nudge the subject's agent so a freshly-completed transcription is
  /// processed immediately, bypassing the 2-minute subscription throttle.
  ///
  /// Honors the automatic-updates opt-in: when the user has switched
  /// automatic updates off, the report is only marked stale (surfacing the
  /// manual "Wake agent" CTA) and no inference is enqueued.
  ///
  /// No-op when no agent is registered for [linkedSubjectId]. Failures
  /// are logged but never propagate — a missed nudge is recoverable via
  /// the standard subscription path; throwing here would abort the caller.
  Future<void> _nudgeSubjectAgent({
    required String entryId,
    required String linkedSubjectId,
  }) async {
    try {
      final agent = await ref.read(subjectAgentResolverProvider)(
        linkedSubjectId,
      );
      if (agent == null) return;
      final woken = ref
          .read(wakeOrchestratorProvider)
          .requestContentWake(
            agentId: agent.agentId,
            reason: WakeReason.transcriptionComplete.name,
            triggerTokens: {linkedSubjectId, entryId},
          );
      loggingService.log(
        LogDomain.ai,
        '${woken ? 'Nudged' : 'Marked report stale for'} agent '
        '${agent.agentId} after transcription completion '
        '(subject $linkedSubjectId, entry $entryId)',
        subDomain: 'nudgeSubjectAgent',
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'nudgeSubjectAgent',
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
