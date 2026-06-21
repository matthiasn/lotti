import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Persists the per-wake conversation messages (assistant thought, tool action,
/// tool result) to `agent.sqlite`.
///
/// Mixed into the conversation strategies whose message-recording is identical
/// (event + project). Persistence failures are swallowed and logged so a
/// storage hiccup never aborts the wake; the log name is the concrete
/// strategy's runtime type.
mixin AgentMessageRecording {
  AgentSyncService get syncService;
  String get agentId;
  String get threadId;
  String get runKey;

  static const _uuid = Uuid();

  /// Records the assistant turn that requested tool calls.
  Future<void> recordAssistantMessage() => _persist(
    kind: AgentMessageKind.thought,
    metadata: AgentMessageMetadata(runKey: runKey),
    label: 'assistant',
  );

  /// Records that [toolName] was invoked.
  Future<void> recordActionMessage({required String toolName}) => _persist(
    kind: AgentMessageKind.action,
    metadata: AgentMessageMetadata(runKey: runKey, toolName: toolName),
    label: 'action',
  );

  /// Records the result (or [errorMessage]) returned for [toolName].
  Future<void> recordToolResultMessage({
    required String toolName,
    String? errorMessage,
  }) => _persist(
    kind: AgentMessageKind.toolResult,
    metadata: AgentMessageMetadata(
      runKey: runKey,
      toolName: toolName,
      errorMessage: errorMessage,
    ),
    label: 'tool result',
  );

  Future<void> _persist({
    required AgentMessageKind kind,
    required AgentMessageMetadata metadata,
    required String label,
  }) async {
    try {
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: kind,
          createdAt: clock.now(),
          vectorClock: null,
          metadata: metadata,
        ),
      );
    } catch (e) {
      developer.log(
        'Failed to persist $label message (errorType=${e.runtimeType})',
        name: '$runtimeType',
      );
    }
  }
}
