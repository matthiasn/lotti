import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:uuid/uuid.dart';

const _relationshipChatMessageTokenPrefix = 'relationship-chat-message:';

String relationshipChatMessageTriggerToken(String messageId) =>
    '$_relationshipChatMessageTokenPrefix$messageId';

String? relationshipChatMessageIdFromTriggerTokens(Iterable<String> tokens) {
  for (final token in tokens) {
    if (token.startsWith(_relationshipChatMessageTokenPrefix)) {
      final id = token.substring(_relationshipChatMessageTokenPrefix.length);
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

/// Persists one user-authored relationship-agent turn, then hands
/// inference to the shared wake runtime (the `GoalChatService` pattern:
/// the conversation UI never owns an inference loop, and the source turn
/// is durable before inference can begin).
class RelationshipChatService {
  RelationshipChatService({
    required this._repository,
    required this._syncService,
    required this._orchestrator,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;

  static const _uuid = Uuid();

  Future<void> sendMessage({
    required String agentId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final identity = await _repository.getEntity(agentId);
    if (identity is! AgentIdentityEntity ||
        identity.kind != AgentKinds.relationshipAgent ||
        identity.lifecycle != AgentLifecycle.active) {
      throw const RelationshipChatTurnException(
        'relationship agent is not active',
      );
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
              // The wake gets its own deterministic run/thread id; this
              // source turn is globally projected by agent and linked to
              // the wake through its trigger token.
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
      // The append can commit its transaction and then fail flushing the
      // sync outbox. Reconcile the deterministic id before surfacing a
      // failed append — a retry would otherwise duplicate the turn.
      final persisted = await _repository.getEntity(messageId);
      if (persisted is! AgentMessageEntity ||
          persisted.agentId != agentId ||
          persisted.kind != AgentMessageKind.user ||
          persisted.contentEntryId != payloadId) {
        rethrow;
      }
    }

    await retryMessage(agentId: agentId, messageId: messageId);
  }

  /// Re-enqueues the already durable source turn after a failed wake.
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
        triggerTokens: {relationshipChatMessageTriggerToken(messageId)},
        supersede: false,
        initiator: WakeInitiator.user,
      );
      final result = await completion.future;
      if (result.status != WakeRunStatus.completed) {
        throw RelationshipChatTurnException(
          result.error?.toString(),
          messageId: messageId,
        );
      }
    } finally {
      await subscription.cancel();
    }
  }
}

class RelationshipChatTurnException implements Exception {
  const RelationshipChatTurnException(this.detail, {this.messageId});

  final String? detail;
  final String? messageId;

  @override
  String toString() => detail ?? 'The relationship-agent turn failed.';
}
