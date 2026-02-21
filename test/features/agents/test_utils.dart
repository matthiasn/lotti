import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Shared test date for agent tests. Do NOT use DateTime.now().
final kAgentTestDate = DateTime(2024, 3, 15, 10, 30);

/// Default agent ID used across tests.
const kTestAgentId = 'agent-001';

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
  ) as AgentIdentityEntity;
}

AgentStateEntity makeTestState({
  String id = 'state-001',
  String agentId = kTestAgentId,
  int revision = 1,
  AgentSlots slots = const AgentSlots(),
  DateTime? updatedAt,
  VectorClock? vectorClock,
  int wakeCounter = 0,
  int consecutiveFailureCount = 0,
  DateTime? lastWakeAt,
  DateTime? nextWakeAt,
  DateTime? sleepUntil,
}) {
  return AgentDomainEntity.agentState(
    id: id,
    agentId: agentId,
    revision: revision,
    slots: slots,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    wakeCounter: wakeCounter,
    consecutiveFailureCount: consecutiveFailureCount,
    lastWakeAt: lastWakeAt,
    nextWakeAt: nextWakeAt,
    sleepUntil: sleepUntil,
  ) as AgentStateEntity;
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
    metadata: metadata ??
        AgentMessageMetadata(
          toolName: toolName,
          errorMessage: errorMessage,
          runKey: runKey,
        ),
    contentEntryId: contentEntryId,
  ) as AgentMessageEntity;
}

AgentReportEntity makeTestReport({
  String id = 'report-001',
  String agentId = kTestAgentId,
  String scope = 'current',
  DateTime? createdAt,
  VectorClock? vectorClock,
  String content = '# Test Report\n\nEverything is fine.',
  double? confidence,
}) {
  return AgentDomainEntity.agentReport(
    id: id,
    agentId: agentId,
    scope: scope,
    createdAt: createdAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    content: content,
    confidence: confidence,
  ) as AgentReportEntity;
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
  ) as AgentReportHeadEntity;
}

// ── Link factory ──────────────────────────────────────────────────────────────

model.AgentLink makeTestBasicLink({
  String id = 'link-001',
  String fromId = kTestAgentId,
  String toId = 'state-001',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return model.AgentLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
  );
}

// ── Wake infrastructure factories ─────────────────────────────────────────────

WakeRunLogData makeTestWakeRun({
  String runKey = 'run-key-001',
  String agentId = kTestAgentId,
  String reason = 'subscription',
  String threadId = 'thread-001',
  String status = 'pending',
  DateTime? createdAt,
  DateTime? startedAt,
  DateTime? completedAt,
  String? errorMessage,
}) {
  return WakeRunLogData(
    runKey: runKey,
    agentId: agentId,
    reason: reason,
    threadId: threadId,
    status: status,
    createdAt: createdAt ?? kAgentTestDate,
    startedAt: startedAt,
    completedAt: completedAt,
    errorMessage: errorMessage,
  );
}

SagaLogData makeTestSagaOp({
  String operationId = 'op-001',
  String runKey = 'run-key-001',
  String phase = 'execution',
  String status = 'pending',
  String toolName = 'create_entry',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return SagaLogData(
    operationId: operationId,
    runKey: runKey,
    phase: phase,
    status: status,
    toolName: toolName,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
  );
}

WakeJob makeTestWakeJob({
  String runKey = 'run-key-001',
  String agentId = kTestAgentId,
  String reason = 'subscription',
  Set<String>? triggerTokens,
  String? reasonId,
  DateTime? createdAt,
}) {
  return WakeJob(
    runKey: runKey,
    agentId: agentId,
    reason: reason,
    triggerTokens: triggerTokens ?? {'tok-a'},
    reasonId: reasonId,
    createdAt: createdAt ?? kAgentTestDate,
  );
}
