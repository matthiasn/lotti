import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

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
        items:
            items ??
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
      )
      as ChangeSetEntity;
}

ChangeDecisionEntity makeTestChangeDecision({
  String id = 'cd-001',
  String agentId = kTestAgentId,
  String changeSetId = 'cs-001',
  int itemIndex = 0,
  String toolName = 'update_task_estimate',
  ChangeDecisionVerdict verdict = ChangeDecisionVerdict.confirmed,
  DecisionActor actor = DecisionActor.user,
  DateTime? createdAt,
  VectorClock? vectorClock,
  String? taskId,
  String? rejectionReason,
  String? retractionReason,
  String? humanSummary,
  Map<String, dynamic>? args,
}) {
  return AgentDomainEntity.changeDecision(
        id: id,
        agentId: agentId,
        changeSetId: changeSetId,
        itemIndex: itemIndex,
        toolName: toolName,
        verdict: verdict,
        actor: actor,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        taskId: taskId,
        rejectionReason: rejectionReason,
        retractionReason: retractionReason,
        humanSummary: humanSummary,
        args: args,
      )
      as ChangeDecisionEntity;
}

ProjectRecommendationEntity makeTestProjectRecommendation({
  String id = 'pr-001',
  String agentId = kTestAgentId,
  String projectId = 'project-001',
  String title = 'Confirm rollout',
  int position = 0,
  ProjectRecommendationStatus status = ProjectRecommendationStatus.active,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  String? sourceChangeSetId,
  String? sourceDecisionId,
  String? rationale = 'Keep an eye on the final handoff.',
  String? priority = 'HIGH',
  DateTime? resolvedAt,
  DateTime? dismissedAt,
  DateTime? supersededAt,
}) {
  final timestamp = createdAt ?? kAgentTestDate;
  return AgentDomainEntity.projectRecommendation(
        id: id,
        agentId: agentId,
        projectId: projectId,
        title: title,
        position: position,
        status: status,
        createdAt: timestamp,
        updatedAt: updatedAt ?? timestamp,
        vectorClock: vectorClock,
        sourceChangeSetId: sourceChangeSetId,
        sourceDecisionId: sourceDecisionId,
        rationale: rationale,
        priority: priority,
        resolvedAt: resolvedAt,
        dismissedAt: dismissedAt,
        supersededAt: supersededAt,
      )
      as ProjectRecommendationEntity;
}
