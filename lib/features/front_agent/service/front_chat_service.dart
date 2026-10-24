import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:uuid/uuid.dart';

/// What runs after a front wake completed for a message: the doors of its
/// dispatch are walked here, outside the wake slot, never inside it.
typedef FrontTurnCompleted = Future<void> Function(String messageId);

/// Persists one user-authored front-agent turn, then hands routing to the
/// shared wake runtime (the `GoalChatService` pattern: the chat never owns
/// an inference loop, and the source turn is durable before inference can
/// begin).
///
/// The device the turn was typed on routes it. Every turn also gets a
/// synced, lease-elected recovery record due [frontChatRecoveryGrace] later,
/// which the author's successful wake consumes; if that never happens — the
/// wake failed, the device died — the lease picks exactly one device to
/// route it instead (ADR 0069). No device routes a turn it did not type on
/// sight.
class FrontChatService {
  FrontChatService({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required WakeOrchestrator orchestrator,
    required UpdateNotifications notifications,
    required FrontChatHistoryService historyService,
    FrontTurnCompleted? onTurnCompleted,
  }) : this._(
         repository,
         syncService,
         orchestrator,
         notifications,
         historyService,
         onTurnCompleted,
       );

  FrontChatService._(
    this._repository,
    this._syncService,
    this._orchestrator,
    this._notifications,
    this._historyService,
    this._onTurnCompleted,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;
  final UpdateNotifications _notifications;
  final FrontChatHistoryService _historyService;

  /// The door walker, when one is wired. Runs after the run completed and
  /// after the recovery record is consumed; its failures are its own.
  final FrontTurnCompleted? _onTurnCompleted;

  static const _uuid = Uuid();

  /// Appends [text] as a durable user turn, runs the routing wake for it
  /// and walks its doors. Throws [FrontChatTurnException] when the agent
  /// cannot take a turn or the wake fails; the message is durable either
  /// way and [retryMessage] re-runs it.
  Future<void> sendMessage({required String text}) async {
    final messageId = await appendMessage(text: text);
    if (messageId == null) return;
    await retryMessage(messageId: messageId);
  }

  /// Makes [text] a durable user turn and arms its recovery record, without
  /// running anything. Returns the message id, or null for a blank text.
  ///
  /// The turn is durable before the wake, so a process that dies while
  /// routing still leaves it a way to be routed — by the lease, after the
  /// grace. A failed recovery write is swallowed on purpose: the record is
  /// only the fallback, and maintenance arms a missing one for the oldest
  /// unanswered turn on its next pass.
  Future<String?> appendMessage({required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final identity = usableFrontAgent(
      await _repository.getEntity(frontAgentId),
    );
    if (identity == null) {
      throw const FrontChatTurnException('front agent is not active');
    }

    final now = clock.now();
    final payloadId = _uuid.v4();
    final messageId = _uuid.v4();

    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: frontAgentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': trimmed},
      ),
    );
    final message =
        AgentDomainEntity.agentMessage(
              id: messageId,
              agentId: frontAgentId,
              // The wake gets its own deterministic run/thread id; this
              // source turn is projected by agent and linked to the wake
              // through its trigger token.
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
      // The append can commit and then fail flushing the sync outbox.
      // Reconcile the deterministic id before surfacing a failed append —
      // a retry would otherwise duplicate the turn.
      final persisted = await _repository.getEntity(messageId);
      if (persisted is! AgentMessageEntity ||
          persisted.agentId != frontAgentId ||
          persisted.kind != AgentMessageKind.user ||
          persisted.contentEntryId != payloadId) {
        rethrow;
      }
    }
    // The turn is durable: show it now, before the wake's own notification.
    _notifications.notifyUiOnly({frontAgentId, agentNotification});

    try {
      await _syncService.upsertEntity(
        _recoveryRecord(
          messageId: messageId,
          dueAt: now.toUtc().add(frontChatRecoveryGrace),
          now: now,
        ),
      );
    } on Object {
      // Deliberately swallowed; see above.
    }
    return messageId;
  }

  /// Enqueues the routing wake for an already durable turn and returns its
  /// run key, without waiting for it.
  String enqueueMessage({required String messageId}) =>
      _orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {frontChatMessageTriggerToken(messageId)},
        supersede: false,
        initiator: WakeInitiator.user,
      );

  /// Re-enqueues the already durable source turn, waits for its wake,
  /// consumes its recovery record and walks its doors.
  ///
  /// Throws [FrontChatTurnException] when the wake fails — including when
  /// the orchestrator shuts down first, which ends the completion stream
  /// without an event for this run, so the future always completes.
  Future<void> retryMessage({required String messageId}) async {
    String? runKey;
    final completion = Completer<WakeRunCompletion>();
    final subscription = _orchestrator.runCompletions.listen(
      (event) {
        if (event.runKey == runKey && !completion.isCompleted) {
          completion.complete(event);
        }
      },
      onDone: () {
        if (!completion.isCompleted) {
          completion.completeError(
            FrontChatTurnException(
              'the agent runtime stopped before the turn completed',
              messageId: messageId,
            ),
          );
        }
      },
    );
    try {
      runKey = enqueueMessage(messageId: messageId);
      final result = await completion.future;
      if (result.status != WakeRunStatus.completed) {
        throw FrontChatTurnException(
          result.error?.toString(),
          messageId: messageId,
        );
      }
    } finally {
      await subscription.cancel();
    }
    await _consumeRecovery(messageId);
    await _onTurnCompleted?.call(messageId);
  }

  /// Makes sure the oldest unanswered turn can still be routed: arms its
  /// recovery record when it has none, or the next window of it when the
  /// last recovery ran without answering. Enqueues nothing itself — the
  /// scheduled-wake manager's lease elects the one device that routes.
  ///
  /// Runtime maintenance calls this at startup and before every scheduled
  /// scan, on every device. Returns whether it wrote a record.
  Future<bool> restoreOldestPendingMessage() async {
    final messageId = await _historyService.oldestPendingMessageId();
    if (messageId == null) return false;
    var armed = false;
    await _syncService.runInTransaction(() async {
      final now = clock.now();
      final existing = await _repository.getEntity(
        frontChatRecoveryRecordId(frontAgentId, messageId),
      );
      if (existing is! ScheduledWakeEntity || existing.deletedAt != null) {
        // A turn whose author died before arming it: the grace runs from
        // now. Over a tombstone, the write carries its clock — built from
        // a null clock it would be concurrent with the tombstone, and the
        // local write path (ADR 0068) would keep the deleted row whenever
        // its deadline is the later one.
        await _syncService.upsertEntity(
          _recoveryRecord(
            messageId: messageId,
            dueAt: now.toUtc().add(frontChatRecoveryGrace),
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
      // UTC instant on every replica. A window the author's own wake
      // consumed carries no lease; it waits a grace past its deadline.
      await _syncService.upsertEntity(
        existing.copyWith(
          status: ScheduledWakeStatus.pending,
          scheduledAt:
              existing.leaseUntil ??
              existing.scheduledAt.add(frontChatRecoveryGrace),
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
  Future<void> _consumeRecovery(String messageId) =>
      _syncService.runInTransaction(() async {
        final record = await _repository.getEntity(
          frontChatRecoveryRecordId(frontAgentId, messageId),
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
    required String messageId,
    required DateTime dueAt,
    required DateTime now,
  }) =>
      AgentDomainEntity.scheduledWake(
            id: frontChatRecoveryRecordId(frontAgentId, messageId),
            agentId: frontAgentId,
            scheduledAt: dueAt,
            status: ScheduledWakeStatus.pending,
            reason: WakeReason.userMessage.name,
            updatedAt: now,
            vectorClock: null,
            workspaceKey: frontChatRecoveryWorkspaceKey(messageId),
            triggerTokens: [frontChatMessageTriggerToken(messageId)],
          )
          as ScheduledWakeEntity;
}

class FrontChatTurnException implements Exception {
  const FrontChatTurnException(this.detail, {this.messageId});

  final String? detail;
  final String? messageId;

  @override
  String toString() => detail ?? 'The front-agent turn failed.';
}
