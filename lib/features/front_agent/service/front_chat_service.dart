import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:uuid/uuid.dart';

/// Persists one user-authored front-agent turn, then hands routing to the
/// shared wake runtime (the `GoalChatService` / `RelationshipChatService`
/// pattern: the chat never owns an inference loop, and the source turn is
/// durable before inference can begin).
///
/// Slice 0 stops at the dispatch record. Walking the doors it names and
/// the lease-elected recovery record (ADR 0069) are slice 1 of
/// `docs/implementation_plans/2026-10-23_single_agent_entry_point.md`.
class FrontChatService {
  FrontChatService({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required WakeOrchestrator orchestrator,
    required UpdateNotifications notifications,
  }) : this._(repository, syncService, orchestrator, notifications);

  FrontChatService._(
    this._repository,
    this._syncService,
    this._orchestrator,
    this._notifications,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;
  final UpdateNotifications _notifications;

  static const _uuid = Uuid();

  /// Appends [text] as a durable user turn and runs the routing wake for
  /// it. Throws [FrontChatTurnException] when the agent cannot take a turn
  /// or the wake fails; the message is durable either way and
  /// [retryMessage] re-runs it.
  Future<void> sendMessage({required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

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

    await retryMessage(messageId: messageId);
  }

  /// Re-enqueues the already durable source turn and waits for its wake.
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
      runKey = _orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {frontChatMessageTriggerToken(messageId)},
        supersede: false,
        initiator: WakeInitiator.user,
      );
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
  }
}

class FrontChatTurnException implements Exception {
  const FrontChatTurnException(this.detail, {this.messageId});

  final String? detail;
  final String? messageId;

  @override
  String toString() => detail ?? 'The front-agent turn failed.';
}
