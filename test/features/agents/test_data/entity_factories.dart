import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

// ── Entity factories ──────────────────────────────────────────────────────────

AgentIdentityEntity makeTestIdentity({
  String id = kTestAgentId,
  String agentId = kTestAgentId,
  String kind = 'task_agent',
  String displayName = 'Test Agent',
  AgentLifecycle lifecycle = AgentLifecycle.active,
  AgentInteractionMode mode = AgentInteractionMode.autonomous,
  Set<String> allowedCategoryIds = const {},
  String currentStateId = 'state-001',
  AgentConfig config = const AgentConfig(),
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agent(
        id: id,
        agentId: agentId,
        kind: kind,
        displayName: displayName,
        lifecycle: lifecycle,
        mode: mode,
        allowedCategoryIds: allowedCategoryIds,
        currentStateId: currentStateId,
        config: config,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as AgentIdentityEntity;
}

AgentStateEntity makeTestState({
  String id = 'state-001',
  String agentId = kTestAgentId,
  int revision = 1,
  AgentSlots slots = const AgentSlots(),
  DateTime? updatedAt,
  VectorClock? vectorClock,
  int wakeCounter = 0,
  bool awaitingContent = false,
  int consecutiveFailureCount = 0,
  DateTime? lastWakeAt,
  DateTime? nextWakeAt,
  DateTime? sleepUntil,
  DateTime? scheduledWakeAt,
}) {
  return AgentDomainEntity.agentState(
        id: id,
        agentId: agentId,
        revision: revision,
        slots: slots,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        wakeCounter: wakeCounter,
        awaitingContent: awaitingContent,
        consecutiveFailureCount: consecutiveFailureCount,
        lastWakeAt: lastWakeAt,
        nextWakeAt: nextWakeAt,
        sleepUntil: sleepUntil,
        scheduledWakeAt: scheduledWakeAt,
      )
      as AgentStateEntity;
}

AgentMessageEntity makeTestMessage({
  String id = 'msg-001',
  String agentId = kTestAgentId,
  String threadId = 'thread-001',
  AgentMessageKind kind = AgentMessageKind.thought,
  DateTime? createdAt,
  VectorClock? vectorClock,
  AgentMessageMetadata? metadata,
  String? contentEntryId,
  // Convenience shortcuts — used when [metadata] is not provided.
  String? toolName,
  String? errorMessage,
  String? runKey,
}) {
  return AgentDomainEntity.agentMessage(
        id: id,
        agentId: agentId,
        threadId: threadId,
        kind: kind,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        metadata:
            metadata ??
            AgentMessageMetadata(
              toolName: toolName,
              errorMessage: errorMessage,
              runKey: runKey,
            ),
        contentEntryId: contentEntryId,
      )
      as AgentMessageEntity;
}

AgentMessagePayloadEntity makeTestMessagePayload({
  String id = 'payload-001',
  String agentId = kTestAgentId,
  DateTime? createdAt,
  VectorClock? vectorClock,
  Map<String, Object?> content = const {'text': 'Payload content'},
}) {
  return AgentDomainEntity.agentMessagePayload(
        id: id,
        agentId: agentId,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        content: content,
      )
      as AgentMessagePayloadEntity;
}

AgentReportEntity makeTestReport({
  String id = 'report-001',
  String agentId = kTestAgentId,
  String scope = 'current',
  DateTime? createdAt,
  VectorClock? vectorClock,
  String content = '# Test Report\n\nEverything is fine.',
  String? tldr,
  String? oneLiner,
  double? confidence,
  Map<String, Object?> provenance = const {},
}) {
  return AgentDomainEntity.agentReport(
        id: id,
        agentId: agentId,
        scope: scope,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        content: content,
        tldr: tldr,
        oneLiner: oneLiner,
        confidence: confidence,
        provenance: provenance,
      )
      as AgentReportEntity;
}

AgentReportHeadEntity makeTestReportHead({
  String id = 'head-001',
  String agentId = kTestAgentId,
  String scope = 'current',
  String reportId = 'report-001',
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agentReportHead(
        id: id,
        agentId: agentId,
        scope: scope,
        reportId: reportId,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as AgentReportHeadEntity;
}
