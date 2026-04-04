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
