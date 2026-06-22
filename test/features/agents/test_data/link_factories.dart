import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

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

// ── Input-capture reference factory (agent → content-addressed payload) ───────
// Backs the active input frontier (ADR 0020): provenance (`contentEntryId`) and
// canonical ordering (`sourceCreatedAt`) live on the reference, not the payload.
// Defaults to the runtime topology (`fromId = agentId`), which `getLinksFrom`
// resolves the frontier from.

model.AgentLink makeTestMessagePayloadLink({
  String id = 'link-payload-001',
  String fromId = kTestAgentId,
  String toId = 'sha256-v1:payload',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  String? contentEntryId,
  DateTime? sourceCreatedAt,
  DateTime? deletedAt,
}) {
  return model.AgentLink.messagePayload(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    contentEntryId: contentEntryId,
    sourceCreatedAt: sourceCreatedAt,
    deletedAt: deletedAt,
  );
}

// ── Active-slot link factories (agent → target) ──────────────────────────────
// These back `slots.active{Task,Project,Day,Template}Id` in the projection fold.

model.AgentLink makeTestAgentTaskLink({
  String id = 'link-task-001',
  String fromId = kTestAgentId,
  String toId = 'task-001',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.agentTask(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}

model.AgentLink makeTestAgentProjectLink({
  String id = 'link-project-001',
  String fromId = kTestAgentId,
  String toId = 'project-001',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.agentProject(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}

model.AgentLink makeTestAgentEventLink({
  String id = 'link-event-001',
  String fromId = kTestAgentId,
  String toId = 'event-001',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.agentEvent(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}

model.AgentLink makeTestAgentDayLink({
  String id = 'link-day-001',
  String fromId = kTestAgentId,
  String toId = 'day-2024-03-15',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.agentDay(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}

model.AgentLink makeTestImproverTargetLink({
  String id = 'link-improver-001',
  String fromId = kTestAgentId,
  String toId = kTestTemplateId,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.improverTarget(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}

/// A `messagePrev` causal edge: child [fromId] → parent [toId].
model.AgentLink makeTestMessagePrevLink({
  required String fromId,
  required String toId,
  String? id,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  DateTime? deletedAt,
}) {
  return model.AgentLink.messagePrev(
    id: id ?? 'msgprev-$fromId',
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? kAgentTestDate,
    updatedAt: updatedAt ?? kAgentTestDate,
    vectorClock: vectorClock,
    deletedAt: deletedAt,
  );
}
