import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:uuid/uuid.dart';

const _goalChatMessageTokenPrefix = 'goal-chat-message:';

/// How long the device a message was typed on has to answer it before its
/// recovery record falls due and the lease elects one device to answer it
/// instead (ADR 0069, `specs/tla/GoalChatReply.tla`).
///
/// Thirty minutes is three run caps: a healthy wake of the author's is long
/// settled, and its reply long synced, by the time any other device looks.
const goalChatRecoveryGrace = Duration(minutes: 30);

String goalChatMessageTriggerToken(String messageId) =>
    '$_goalChatMessageTokenPrefix$messageId';

String? goalChatMessageIdFromTriggerTokens(Iterable<String> tokens) {
  for (final token in tokens) {
    if (token.startsWith(_goalChatMessageTokenPrefix)) {
      final id = token.substring(_goalChatMessageTokenPrefix.length);
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

/// The id of [messageId]'s recovery record.
String goalChatRecoveryRecordId(String agentId, String messageId) =>
    scheduledWakeRecordId(
      agentId,
      workspaceKey: goalChatRecoveryWorkspaceKey(messageId),
    );

/// Persists one user-authored goal-agent turn, then hands inference to the
/// shared wake runtime. The conversation UI never owns an inference loop.
///
/// The device the turn was typed on answers it. Every turn also gets a
/// synced, lease-elected recovery record due [goalChatRecoveryGrace] later,
/// which the author's successful wake consumes; if that never happens — the
/// wake failed, the device died — the lease picks exactly one device to
/// answer instead. No device answers a turn it did not type on sight: that
/// is how two devices used to answer the same message.
class GoalChatService {
  GoalChatService({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required WakeOrchestrator orchestrator,
    required UpdateNotifications notifications,
    GoalChatHistoryService? historyService,
  }) : this._(
         repository,
         syncService,
         orchestrator,
         notifications,
         historyService ?? GoalChatHistoryService(repository),
       );

  GoalChatService._(
    this._repository,
    this._syncService,
    this._orchestrator,
    this._notifications,
    this._historyService,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;
  final UpdateNotifications _notifications;
  final GoalChatHistoryService _historyService;

  static const _uuid = Uuid();

  Future<void> sendMessage({
    required String agentId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final identity = await _repository.getEntity(agentId);
    if (identity is! AgentIdentityEntity ||
        identity.kind != AgentKinds.goalAgent ||
        identity.lifecycle != AgentLifecycle.active) {
      throw const GoalChatTurnException('goal agent is not active');
    }

    final now = clock.now();
    final payloadId = _uuid.v4();
    final messageId = _uuid.v4();

    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': trimmed},
      ),
    );
    final message =
        AgentDomainEntity.agentMessage(
              id: messageId,
              agentId: agentId,
              // The wake gets its own deterministic run/thread id. This source turn
              // is globally projected by agent and linked to the wake through its
              // trigger token, so it is durable before inference can begin.
              threadId: messageId,
              kind: AgentMessageKind.user,
              createdAt: now,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;
    try {
      await _syncService.upsertEntity(message);
    } on Object {
      // A message append can commit its database transaction and then fail
      // while flushing the sync outbox. Reconcile the deterministic id before
      // deciding whether this turn needs to be surfaced as a failed append;
      // otherwise Send would create a duplicate durable user turn.
      final persisted = await _repository.getEntity(messageId);
      if (persisted is! AgentMessageEntity ||
          persisted.agentId != agentId ||
          persisted.kind != AgentMessageKind.user ||
          persisted.contentEntryId != payloadId) {
        rethrow;
      }
    }
    // The turn is durable: show it now. The chat refreshes on the agent's
    // notifications, and the wake below only sends one once the reply is
    // written — waiting for it made the user's own words appear late.
    _notifications.notifyUiOnly({agentId, agentNotification});

    // Before the wake, so a process that dies while answering still leaves
    // the turn a way to be answered — by the lease, after the grace. A
    // failure here — a write that committed and then failed to flush the
    // sync outbox, or one that did not commit — must not cost the turn its
    // own answer: the record is only the fallback, and maintenance arms a
    // missing one for the oldest unanswered turn on its next pass.
    try {
      await _syncService.upsertEntity(
        _recoveryRecord(
          agentId: agentId,
          messageId: messageId,
          dueAt: now.toUtc().add(goalChatRecoveryGrace),
          now: now,
        ),
      );
    } on Object {
      // Deliberately swallowed; see above.
    }

    await retryMessage(agentId: agentId, messageId: messageId);
  }

  /// Re-enqueues the already durable source turn after a failed wake.
  ///
  /// A wake that completes consumes the turn's recovery record, so no other
  /// device answers it again.
  Future<void> retryMessage({
    required String agentId,
    required String messageId,
  }) async {
    String? runKey;
    final completion = Completer<WakeRunCompletion>();
    final subscription = _orchestrator.runCompletions.listen((event) {
      if (event.runKey == runKey && !completion.isCompleted) {
        completion.complete(event);
      }
    });
    try {
      runKey = _orchestrator.enqueueManualWake(
        agentId: agentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {goalChatMessageTriggerToken(messageId)},
        supersede: false,
        initiator: WakeInitiator.user,
      );
      final result = await completion.future;
      if (result.status != WakeRunStatus.completed) {
        throw GoalChatTurnException(
          result.error?.toString(),
          messageId: messageId,
        );
      }
    } finally {
      await subscription.cancel();
    }
    await _consumeRecovery(agentId, messageId);
  }

  /// Makes sure the oldest unanswered turn can still be answered: arms its
  /// recovery record when it has none, or the next window of it when the
  /// last recovery ran without answering. Enqueues nothing itself — the
  /// scheduled-wake manager's lease elects the one device that answers.
  ///
  /// Runtime maintenance calls this at startup, before every scheduled scan
  /// and when a goal identity syncs in, on every device. Returns whether it
  /// wrote a record.
  Future<bool> restoreOldestPendingMessage(String agentId) async {
    final messageId = await _historyService.oldestPendingMessageId(agentId);
    if (messageId == null) return false;
    var armed = false;
    await _syncService.runInTransaction(() async {
      final now = clock.now();
      final existing = await _repository.getEntity(
        goalChatRecoveryRecordId(agentId, messageId),
      );
      if (existing is! ScheduledWakeEntity || existing.deletedAt != null) {
        // A turn whose author died before arming it, or one sent before
        // recovery records existed: the grace runs from now. Over a
        // tombstone, the write carries its clock: built from a null clock
        // it would be concurrent with the tombstone, and the local write
        // path (ADR 0068) would keep the deleted row whenever its deadline
        // is the later one.
        await _syncService.upsertEntity(
          _recoveryRecord(
            agentId: agentId,
            messageId: messageId,
            dueAt: now.toUtc().add(goalChatRecoveryGrace),
            now: now,
          ).copyWith(
            vectorClock: existing is ScheduledWakeEntity
                ? existing.vectorClock
                : null,
          ),
        );
        armed = true;
        return;
      }
      if (existing.status != ScheduledWakeStatus.consumed) return;
      // The next window is due when the last one's lease lapses — the same
      // UTC instant on every replica, so every device re-arming it writes
      // one window, and a recovery run still in flight has had its time.
      // A window the author's own wake consumed carries no lease; it waits
      // a grace past its deadline instead.
      await _syncService.upsertEntity(
        existing.copyWith(
          status: ScheduledWakeStatus.pending,
          scheduledAt:
              existing.leaseUntil ??
              existing.scheduledAt.add(goalChatRecoveryGrace),
          consumedAt: null,
          leaseHostId: null,
          leaseUntil: null,
          updatedAt: now,
        ),
      );
      armed = true;
    });
    return armed;
  }

  /// Flips [messageId]'s recovery record to consumed if it is still pending.
  Future<void> _consumeRecovery(String agentId, String messageId) =>
      _syncService.runInTransaction(() async {
        final record = await _repository.getEntity(
          goalChatRecoveryRecordId(agentId, messageId),
        );
        if (record is! ScheduledWakeEntity ||
            record.status != ScheduledWakeStatus.pending) {
          return;
        }
        final now = clock.now();
        await _syncService.upsertEntity(
          record.copyWith(
            status: ScheduledWakeStatus.consumed,
            consumedAt: now,
            updatedAt: now,
          ),
        );
      });

  static ScheduledWakeEntity _recoveryRecord({
    required String agentId,
    required String messageId,
    required DateTime dueAt,
    required DateTime now,
  }) =>
      AgentDomainEntity.scheduledWake(
            id: goalChatRecoveryRecordId(agentId, messageId),
            agentId: agentId,
            scheduledAt: dueAt,
            status: ScheduledWakeStatus.pending,
            reason: WakeReason.userMessage.name,
            updatedAt: now,
            vectorClock: null,
            workspaceKey: goalChatRecoveryWorkspaceKey(messageId),
            triggerTokens: [goalChatMessageTriggerToken(messageId)],
          )
          as ScheduledWakeEntity;
}

class GoalChatTurnException implements Exception {
  const GoalChatTurnException(this.detail, {this.messageId});

  final String? detail;
  final String? messageId;

  @override
  String toString() => detail ?? 'The goal-agent turn failed.';
}
