import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Default template ID used across tests.
const kTestTemplateId = 'template-001';

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
  ) as AgentMessagePayloadEntity;
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

// ── Template entity factories ────────────────────────────────────────────────

AgentTemplateEntity makeTestTemplate({
  String id = kTestTemplateId,
  String agentId = kTestTemplateId,
  String displayName = 'Test Template',
  AgentTemplateKind kind = AgentTemplateKind.taskAgent,
  String modelId = 'models/gemini-3-flash-preview',
  Set<String> categoryIds = const {},
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agentTemplate(
    id: id,
    agentId: agentId,
    displayName: displayName,
    kind: kind,
    modelId: modelId,
    categoryIds: categoryIds,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
  ) as AgentTemplateEntity;
}

AgentTemplateVersionEntity makeTestTemplateVersion({
  String id = 'version-001',
  String agentId = kTestTemplateId,
  int version = 1,
  AgentTemplateVersionStatus status = AgentTemplateVersionStatus.active,
  String directives = 'You are a helpful agent.',
  String authoredBy = 'user',
  String? modelId,
  DateTime? createdAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agentTemplateVersion(
    id: id,
    agentId: agentId,
    version: version,
    status: status,
    directives: directives,
    authoredBy: authoredBy,
    modelId: modelId,
    createdAt: createdAt ?? kAgentTestDate,
    vectorClock: vectorClock,
  ) as AgentTemplateVersionEntity;
}

AgentTemplateHeadEntity makeTestTemplateHead({
  String id = 'template-head-001',
  String agentId = kTestTemplateId,
  String versionId = 'version-001',
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agentTemplateHead(
    id: id,
    agentId: agentId,
    versionId: versionId,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
  ) as AgentTemplateHeadEntity;
}

// ── Template link factory ────────────────────────────────────────────────────

model.AgentLink makeTestTemplateAssignmentLink({
  String id = 'link-ta-001',
  String fromId = kTestTemplateId,
  String toId = kTestAgentId,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return model.AgentLink.templateAssignment(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
  );
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
  String? templateId,
  String? templateVersionId,
  double? userRating,
  DateTime? ratedAt,
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
    templateId: templateId,
    templateVersionId: templateVersionId,
    userRating: userRating,
    ratedAt: ratedAt,
  );
}

SagaLogData makeTestSagaOp({
  String operationId = 'op-001',
  String agentId = 'agent-001',
  String runKey = 'run-key-001',
  String phase = 'execution',
  String status = 'pending',
  String toolName = 'create_entry',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return SagaLogData(
    operationId: operationId,
    agentId: agentId,
    runKey: runKey,
    phase: phase,
    status: status,
    toolName: toolName,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
  );
}

// ── Metrics factory ──────────────────────────────────────────────────────────

TemplatePerformanceMetrics makeTestMetrics({
  String templateId = kTestTemplateId,
  int totalWakes = 10,
  int successCount = 8,
  int failureCount = 2,
  double successRate = 0.8,
  Duration? averageDuration = const Duration(seconds: 5),
  DateTime? firstWakeAt,
  DateTime? lastWakeAt,
  int activeInstanceCount = 2,
}) {
  return TemplatePerformanceMetrics(
    templateId: templateId,
    totalWakes: totalWakes,
    successCount: successCount,
    failureCount: failureCount,
    successRate: successRate,
    averageDuration: averageDuration,
    firstWakeAt: firstWakeAt ?? kAgentTestDate,
    lastWakeAt: lastWakeAt ?? kAgentTestDate.add(const Duration(days: 7)),
    activeInstanceCount: activeInstanceCount,
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

// ── Evolution entity factories ────────────────────────────────────────────────

EvolutionSessionEntity makeTestEvolutionSession({
  String id = 'evo-session-001',
  String agentId = kTestTemplateId,
  String templateId = kTestTemplateId,
  int sessionNumber = 1,
  EvolutionSessionStatus status = EvolutionSessionStatus.active,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  String? proposedVersionId,
  String? feedbackSummary,
  double? userRating,
  DateTime? completedAt,
}) {
  return AgentDomainEntity.evolutionSession(
    id: id,
    agentId: agentId,
    templateId: templateId,
    sessionNumber: sessionNumber,
    status: status,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    proposedVersionId: proposedVersionId,
    feedbackSummary: feedbackSummary,
    userRating: userRating,
    completedAt: completedAt,
  ) as EvolutionSessionEntity;
}

EvolutionNoteEntity makeTestEvolutionNote({
  String id = 'evo-note-001',
  String agentId = kTestTemplateId,
  String sessionId = 'evo-session-001',
  EvolutionNoteKind kind = EvolutionNoteKind.reflection,
  DateTime? createdAt,
  VectorClock? vectorClock,
  String content = 'Test evolution note.',
}) {
  return AgentDomainEntity.evolutionNote(
    id: id,
    agentId: agentId,
    sessionId: sessionId,
    kind: kind,
    createdAt: createdAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    content: content,
  ) as EvolutionNoteEntity;
}

// ── Change set entity factories ──────────────────────────────────────────────

ChangeSetEntity makeTestChangeSet({
  String id = 'cs-001',
  String agentId = kTestAgentId,
  String taskId = 'task-001',
  String threadId = 'thread-001',
  String runKey = 'run-key-001',
  ChangeSetStatus status = ChangeSetStatus.pending,
  List<ChangeItem>? items,
  DateTime? createdAt,
  VectorClock? vectorClock,
  DateTime? resolvedAt,
}) {
  return AgentDomainEntity.changeSet(
    id: id,
    agentId: agentId,
    taskId: taskId,
    threadId: threadId,
    runKey: runKey,
    status: status,
    items: items ??
        const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
        ],
    createdAt: createdAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    resolvedAt: resolvedAt,
  ) as ChangeSetEntity;
}

ChangeDecisionEntity makeTestChangeDecision({
  String id = 'cd-001',
  String agentId = kTestAgentId,
  String changeSetId = 'cs-001',
  int itemIndex = 0,
  String toolName = 'update_task_estimate',
  ChangeDecisionVerdict verdict = ChangeDecisionVerdict.confirmed,
  DateTime? createdAt,
  VectorClock? vectorClock,
  String? taskId,
  String? rejectionReason,
}) {
  return AgentDomainEntity.changeDecision(
    id: id,
    agentId: agentId,
    changeSetId: changeSetId,
    itemIndex: itemIndex,
    toolName: toolName,
    verdict: verdict,
    createdAt: createdAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    taskId: taskId,
    rejectionReason: rejectionReason,
  ) as ChangeDecisionEntity;
}

// ── AI config factories (for inference provider resolution tests) ────────────

/// Creates a test [AiConfigInferenceProvider] for use in provider resolution
/// tests.
AiConfigInferenceProvider testInferenceProvider({
  String id = 'provider-1',
  String apiKey = 'test-key',
}) {
  return AiConfig.inferenceProvider(
    id: id,
    baseUrl: 'https://generativelanguage.googleapis.com',
    name: 'Gemini',
    inferenceProviderType: InferenceProviderType.gemini,
    apiKey: apiKey,
    createdAt: DateTime(2024),
  ) as AiConfigInferenceProvider;
}

/// Creates a test [AiConfigModel] for use in provider resolution tests.
AiConfigModel testAiModel({
  String id = 'model-1',
  String providerModelId = 'models/gemini-3-flash-preview',
  String inferenceProviderId = 'provider-1',
}) {
  return AiConfig.model(
    id: id,
    name: 'Test Model',
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: DateTime(2024),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  ) as AiConfigModel;
}
