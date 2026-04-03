import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

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
  String? resolvedModelId,
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
    resolvedModelId: resolvedModelId,
    userRating: userRating,
    ratedAt: ratedAt,
  );
}

WakeTokenUsageEntity makeTestWakeTokenUsage({
  String id = 'token-usage-001',
  String agentId = kTestAgentId,
  String runKey = 'run-key-001',
  String threadId = 'thread-001',
  String modelId = 'models/gemini-3-flash-preview',
  DateTime? createdAt,
  VectorClock? vectorClock,
  String? templateId = kTestTemplateId,
  String? templateVersionId,
  int? inputTokens = 100,
  int? outputTokens = 60,
  int? thoughtsTokens = 40,
  int? cachedInputTokens,
}) {
  return AgentDomainEntity.wakeTokenUsage(
        id: id,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        templateId: templateId,
        templateVersionId: templateVersionId,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        thoughtsTokens: thoughtsTokens,
        cachedInputTokens: cachedInputTokens,
      )
      as WakeTokenUsageEntity;
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
