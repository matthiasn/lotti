import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/helpers/profile_locality.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Drives end-to-end auto-trigger of local AI inference for synced audio.
///
/// One call to [maybeDispatch] runs the eligibility logic from the plan §4,
/// then — if every guard passes — invokes [SkillInferenceRunner.runTranscription]
/// directly (no `AutomaticPromptTrigger` reuse, no `ProfileAutomationService`
/// re-entry, no `_tryDirectTranscriptionFallback` route through cloud
/// providers) and finally nudges [WakeOrchestrator.enqueueManualWake] iff the
/// transcript actually grew.
///
/// Every skip is logged with enough context to debug a missing auto-trigger
/// from log triage alone. The dispatcher itself never throws — it logs and
/// returns.
class SyncedAudioInferenceDispatcher {
  SyncedAudioInferenceDispatcher({
    required this._journalDb,
    required this._vectorClockService,
    required this._profileAutomationResolver,
    required this._profileResolver,
    required this._aiConfigRepository,
    required this._skillInferenceRunner,
    required this._taskAgentService,
    required this._wakeOrchestrator,
    this._domainLogger,
  });

  final JournalDb _journalDb;
  final VectorClockService _vectorClockService;
  final ProfileAutomationResolver _profileAutomationResolver;
  final ProfileResolver _profileResolver;
  final AiConfigRepository _aiConfigRepository;
  final SkillInferenceRunner _skillInferenceRunner;
  final TaskAgentService _taskAgentService;
  final WakeOrchestrator _wakeOrchestrator;
  final DomainLogger? _domainLogger;

  static const String _subDomain = 'syncedAudioInferenceDispatcher';

  /// Routes a single synced id through the eligibility logic.
  ///
  /// Safe to call with sentinels (`labelUsageNotification` etc.) and ids that
  /// turn out not to reference a `JournalAudio` — the method skips with a
  /// log and returns.
  Future<void> maybeDispatch(String id) async {
    try {
      await _maybeDispatch(id);
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomains.sync,
        'syncedAudioInferenceDispatcher threw on id=$id',
        error: error,
        stackTrace: stackTrace,
        subDomain: _subDomain,
      );
    }
  }

  Future<void> _maybeDispatch(String id) async {
    // 1. Sentinels & non-uuid tokens — drop fast. We accept anything Drift's
    // `journalEntityById` accepts; truly bogus ids will return null below.
    if (id.isEmpty || id.contains('CHANGED') || id.contains('NOTIFICATION')) {
      return;
    }

    // 2. Must be a JournalAudio.
    final audio = await _journalDb.journalEntityById(id);
    if (audio is! JournalAudio) {
      return;
    }
    final priorTranscriptCount = audio.data.transcripts?.length ?? 0;

    // 3. Skip if already transcribed somewhere.
    if (priorTranscriptCount > 0) {
      _log('skip', id, 'already transcribed (count=$priorTranscriptCount)');
      return;
    }

    // 4. Self-echo guard: skip only when the vector clock has the local host
    // as its **sole** entry. A merged remote update can legitimately include
    // this host's counter alongside other hosts — those entries are not
    // self-echoes and must pass through.
    final localHostId = await _vectorClockService.getHost();
    if (localHostId == null) {
      _log('skip', id, 'no local host id');
      return;
    }
    final vclock = audio.meta.vectorClock?.vclock;
    if (vclock != null &&
        vclock.length == 1 &&
        vclock.containsKey(localHostId)) {
      _log('skip', id, 'self-echo (VC has only $localHostId)');
      return;
    }

    // 5. Find the linked task (parent).
    final links = await _journalDb.linksForEntryIds({id});
    String? linkedTaskId;
    for (final link in links) {
      if (link.toId != id) continue;
      final parent = await _journalDb.journalEntityById(link.fromId);
      if (parent is Task) {
        linkedTaskId = parent.meta.id;
        break;
      }
    }
    if (linkedTaskId == null) {
      _log('skip', id, 'no linked task');
      return;
    }

    // 6. Resolve the task's profile id via the existing agent → version →
    // template → task.data.profileId chain. Do NOT read
    // category.defaultProfileId directly — that skips agent overrides and
    // lets later category edits silently re-route which device claims the
    // entry.
    final profileId = await _profileAutomationResolver.resolveProfileIdForTask(
      linkedTaskId,
    );
    if (profileId == null) {
      _log('skip', id, 'no profile id for task $linkedTaskId');
      return;
    }

    // 7. Load the raw profile config so we can read pinnedHostId and run
    // profileIsLocal against unresolved-but-referenced slots.
    final profileConfig = await _aiConfigRepository.getConfigById(profileId);
    if (profileConfig is! AiConfigInferenceProfile) {
      _log('skip', id, 'profile $profileId not found / wrong type');
      return;
    }

    // 8 & 9. Pin guards.
    if (profileConfig.pinnedHostId == null) {
      _log('skip', id, 'profile ${profileConfig.id} has no pin');
      return;
    }
    if (profileConfig.pinnedHostId != localHostId) {
      _log(
        'skip',
        id,
        'pinned to ${profileConfig.pinnedHostId} (not $localHostId)',
      );
      return;
    }

    // 10. Locality guard (fail-closed).
    final isLocal = await profileIsLocal(profileConfig, _aiConfigRepository);
    if (!isLocal) {
      _log('skip', id, 'profile ${profileConfig.id} is not local');
      return;
    }

    // 11. Transcription-slot guard. `SkillInferenceRunner.runTranscription`
    // early-returns when the resolved profile has no transcription model;
    // without this check the dispatcher would advance to step 16 and nudge a
    // wake against an unchanged entry.
    if (profileConfig.transcriptionModelId == null) {
      _log('skip', id, 'profile ${profileConfig.id} has no transcription slot');
      return;
    }

    // 12. Find the automated transcription skill on this profile. NO
    // fallback — if the profile doesn't own a `transcription` skill with
    // `automate: true`, skip. Synced audio never routes through
    // `_tryDirectTranscriptionFallback`'s rank-ordered model search.
    SkillAssignment? matchedAssignment;
    AiConfigSkill? matchedSkill;
    for (final assignment in profileConfig.skillAssignments) {
      if (!assignment.automate) continue;
      final skillConfig = await _aiConfigRepository.getConfigById(
        assignment.skillId,
      );
      if (skillConfig is! AiConfigSkill) continue;
      if (skillConfig.skillType != SkillType.transcription) continue;
      // Reject ambiguous profiles (multiple automated transcription skills):
      // their context policies could differ silently. Mirrors
      // ProfileAutomationService._tryAutomateSkillType.
      if (matchedAssignment != null) {
        _log(
          'skip',
          id,
          'profile ${profileConfig.id} has multiple automated transcription '
              'skills — ambiguous',
        );
        return;
      }
      matchedAssignment = assignment;
      matchedSkill = skillConfig;
    }
    if (matchedAssignment == null || matchedSkill == null) {
      _log(
        'skip',
        id,
        'profile ${profileConfig.id} has no automated transcription skill',
      );
      return;
    }

    // 13. Build a ResolvedProfile for the runner. resolveByProfileId loads
    // the profile from disk again (idempotent) and resolves providers — we
    // can't skip it because runTranscription needs the resolved
    // transcriptionProvider, not just the raw model id.
    final resolvedProfile = await _profileResolver.resolveByProfileId(
      profileConfig.id,
    );
    if (resolvedProfile == null ||
        resolvedProfile.transcriptionProvider == null) {
      _log(
        'skip',
        id,
        'profile ${profileConfig.id} did not resolve a transcription provider',
      );
      return;
    }

    final automationResult = AutomationResult(
      handled: true,
      resolvedProfile: resolvedProfile,
      skill: matchedSkill,
      skillAssignment: matchedAssignment,
    );

    // 14. Run transcription. Wrap so a runner throw doesn't crash the
    // dispatcher loop — the post-reload guard below will see no new
    // transcript and skip the wake.
    try {
      await _skillInferenceRunner.runTranscription(
        audioEntryId: id,
        automationResult: automationResult,
        linkedTaskId: linkedTaskId,
      );
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomains.sync,
        'runTranscription threw for $id; will skip wake nudge',
        error: error,
        stackTrace: stackTrace,
        subDomain: _subDomain,
      );
    }

    // 15 & 16. Reload the entity and only nudge the wake when the
    // transcript actually grew. Silent runner failures (return-early on
    // missing slot, swallowed errors inside status tracking) must not
    // produce a misleading wake.
    final after = await _journalDb.journalEntityById(id);
    final postCount =
        (after is JournalAudio ? after.data.transcripts?.length : null) ?? 0;
    if (postCount <= priorTranscriptCount) {
      _log(
        'skip wake',
        id,
        'transcript count did not grow (prior=$priorTranscriptCount '
            'post=$postCount)',
      );
      return;
    }

    // 17. Nudge the task's agent.
    final agent = await _taskAgentService.getTaskAgentForTask(linkedTaskId);
    if (agent == null) {
      _log('skip wake', id, 'no task agent for task $linkedTaskId');
      return;
    }
    _wakeOrchestrator.enqueueManualWake(
      agentId: agent.agentId,
      reason: WakeReason.transcriptionComplete.name,
      triggerTokens: {linkedTaskId, id},
    );
    _log(
      'dispatched',
      id,
      'profile=${profileConfig.id} task=$linkedTaskId '
          'agent=${agent.agentId} '
          'transcripts $priorTranscriptCount→$postCount',
    );
  }

  void _log(String decision, String id, String detail) {
    _domainLogger?.log(
      LogDomains.sync,
      'syncedAudio $decision id=$id $detail',
      subDomain: _subDomain,
    );
  }
}
