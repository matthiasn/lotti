import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';

/// Whether this wake's interactive reply already committed: the carrier
/// message at [replyMessageId] (a deterministic id per agent and run) exists,
/// belongs to [agentId], was written by run [runKey], and is a
/// `reply_to_user` action rather than some other message that happens to
/// share the id.
///
/// A failed interactive wake asks this before reporting failure, so a turn the
/// user already received an answer to is not answered twice on retry.
Future<bool> isInteractiveReplyCommitted({
  required AgentRepository repository,
  required String replyMessageId,
  required String agentId,
  required String runKey,
}) async {
  final entity = await repository.getEntity(replyMessageId);
  return entity is AgentMessageEntity &&
      entity.agentId == agentId &&
      entity.metadata.runKey == runKey &&
      entity.metadata.toolName == AgentConversationToolNames.replyToUser;
}

/// Re-arms an escalation wake that was consumed by a wake that then failed
/// before committing anything, so the failure does not orphan it.
///
/// The record is rewritten pending at [scheduledAt], which callers keep
/// strictly later than the consumed record's deadline: that rides the
/// resolver's reschedule-beats-consume path, whereas a twin at the consumed
/// deadline would lose to any peer's consumed echo. [updatedAt] is the
/// moment of the rewrite, kept apart from [scheduledAt] so a retry deferred
/// into the future does not stamp the record with a future edit time. The
/// original [triggerTokens] are forwarded verbatim, since they may carry state
/// a later re-derivation can no longer reconstruct.
///
/// Contained: a failed re-arm goes to [logError] and never masks the wake's
/// own failure.
Future<void> rearmConsumedEscalation({
  required AgentSyncService syncService,
  required String agentId,
  required String workspaceKey,
  required Set<String> triggerTokens,
  required DateTime scheduledAt,
  required DateTime updatedAt,
  required LogErrorCallback logError,
}) async {
  try {
    await syncService.upsertEntity(
      AgentDomainEntity.scheduledWake(
        id: scheduledWakeRecordId(agentId, workspaceKey: workspaceKey),
        agentId: agentId,
        scheduledAt: scheduledAt.toUtc(),
        status: ScheduledWakeStatus.pending,
        reason: WakeReason.scheduled.name,
        updatedAt: updatedAt,
        vectorClock: null,
        workspaceKey: workspaceKey,
        triggerTokens: [...triggerTokens],
      ),
    );
  } catch (error, stackTrace) {
    logError(
      'failed to re-arm escalation after wake failure',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
