import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Runs the transcription a check-in recording exists to produce.
///
/// A check-in is an ordinary `JournalAudio` linked to the goal's journal
/// entry, which is exactly what made it fall out of the pipeline: the
/// post-recording automation in `features/speech` keys off a linked **task**
/// and gates on that task's category, and a goal is neither. Every check-in
/// therefore saved, played back, and was never transcribed — and with no
/// transcript there was nothing for the compactor to distill either, so the
/// whole `userVoice` chain sat idle behind one silent decline.
///
/// The consent signal here is the goal agent's own automatic-updates switch,
/// not a category's. A goal has no category to carry the answer, and the
/// switch the user actually sees on the goal is the one that should decide
/// whether recording into it spends tokens.
///
/// Nothing beyond that decision lives here: the run itself goes through the
/// shared skill trigger, so a check-in transcribes with the same skill, the
/// same model resolution and the same failure reporting as every other
/// recording in the app.
class GoalCheckInTranscriptionTrigger {
  GoalCheckInTranscriptionTrigger({
    required AgentService agentService,
    required Future<void> Function(String entryId) runTranscription,
    required Future<void> Function(String entryId, String reason) recordDecline,
    DomainLogger? domainLogger,
  }) : _agents = agentService,
       _run = runTranscription,
       _decline = recordDecline,
       _log = domainLogger;

  final AgentService _agents;
  final Future<void> Function(String entryId) _run;

  /// Marks a recording that will not be transcribed as needing the user.
  ///
  /// Declining silently is what made the original bug invisible: the timeline
  /// reads "no transcript, nothing running, no durable failure" as still
  /// transcribing, so a check-in nobody is working on claims progress forever
  /// and never offers the Retry that would transcribe it by hand.
  final Future<void> Function(String entryId, String reason) _decline;
  final DomainLogger? _log;

  /// Transcribes [entryId], the recording just captured for [agentId].
  ///
  /// Returns whether a run was started. Never throws: a check-in that could
  /// not be transcribed is still a check-in the user can play back, and the
  /// recorder must not fail because inference did.
  Future<bool> transcribe({
    required String agentId,
    required String entryId,
  }) async {
    try {
      final identity = await _agents.getAgent(agentId);
      if (identity == null) {
        _logLine(
          'no goal agent $agentId — not transcribing check-in $entryId',
        );
        await _decline(entryId, 'no goal agent $agentId');
        return false;
      }
      if (!GoalAgentService.automaticUpdatesEnabled(identity)) {
        _logLine(
          'automatic updates are off for goal $agentId — check-in $entryId '
          'stays untranscribed until it is triggered by hand',
        );
        // Switched off is a decision, not a failure — but on the rail the two
        // look identical unless it is recorded, and Retry is exactly the
        // affordance a user who wants this one transcribed needs.
        await _decline(
          entryId,
          'automatic updates are off for goal $agentId',
        );
        return false;
      }
      await _run(entryId);
      _logLine('transcribing check-in $entryId for goal $agentId');
      return true;
    } catch (error, stackTrace) {
      _log?.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'GoalCheckInTranscriptionTrigger',
      );
      return false;
    }
  }

  void _logLine(String message) => _log?.log(
    LogDomain.ai,
    message,
    subDomain: 'GoalCheckInTranscriptionTrigger',
  );
}
