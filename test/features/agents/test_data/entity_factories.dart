import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/sync/g_counter.dart';
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
  // Convenience: a plain int wraps into a single-host G-counter whose value is
  // that int, so existing call sites keep passing an int.
  int wakeCounter = 0,
  bool awaitingContent = false,
  int consecutiveFailureCount = 0,
  Map<String, int> toolCounterByKey = const {},
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
        wakeCounter: wakeCounter == 0
            ? const GCounter.empty()
            : GCounter({'test-host': wakeCounter}),
        awaitingContent: awaitingContent,
        consecutiveFailureCount: consecutiveFailureCount,
        toolCounterByKey: toolCounterByKey,
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

CaptureEntity makeTestCapture({
  String id = 'capture-001',
  String agentId = kTestAgentId,
  String transcript = 'Captured transcript',
  DateTime? capturedAt,
  DateTime? createdAt,
  VectorClock? vectorClock,
  String dayId = '',
  String? audioRef,
}) {
  return AgentDomainEntity.capture(
        id: id,
        agentId: agentId,
        transcript: transcript,
        capturedAt: capturedAt ?? kAgentTestDate,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        dayId: dayId,
        audioRef: audioRef,
      )
      as CaptureEntity;
}

ParsedItemEntity makeTestParsedItem({
  String id = 'parsed-001',
  String agentId = kTestAgentId,
  String captureId = 'capture-001',
  ParsedItemKind kind = ParsedItemKind.newTask,
  String title = 'Parsed item',
  String categoryId = 'category-001',
  ParsedItemConfidence confidence = ParsedItemConfidence.high,
  double confidenceScore = 0.9,
  DateTime? createdAt,
  VectorClock? vectorClock,
  bool lowConfidence = false,
  String? spokenPhrase,
  String? matchedTaskId,
  int? estimateMinutes,
}) {
  return AgentDomainEntity.parsedItem(
        id: id,
        agentId: agentId,
        captureId: captureId,
        kind: kind,
        title: title,
        categoryId: categoryId,
        confidence: confidence,
        confidenceScore: confidenceScore,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        lowConfidence: lowConfidence,
        spokenPhrase: spokenPhrase,
        matchedTaskId: matchedTaskId,
        estimateMinutes: estimateMinutes,
      )
      as ParsedItemEntity;
}

DayPlanEntity makeTestDayPlan({
  String? id,
  String agentId = kTestAgentId,
  String dayId = 'dayplan-2026-05-25',
  DateTime? planDate,
  DayPlanData? data,
  List<DayAgentEnergyBand> energyBands = const [],
  int capacityMinutes = 480,
  int scheduledMinutes = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  final resolvedPlanDate = planDate ?? kAgentTestDate;
  return AgentDomainEntity.dayPlan(
        id: id ?? 'day_agent_plan:$dayId',
        agentId: agentId,
        dayId: dayId,
        planDate: resolvedPlanDate,
        data:
            data ??
            DayPlanData(
              planDate: resolvedPlanDate,
              status: const DayPlanStatus.draft(),
            ),
        energyBands: energyBands,
        capacityMinutes: capacityMinutes,
        scheduledMinutes: scheduledMinutes,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as DayPlanEntity;
}
