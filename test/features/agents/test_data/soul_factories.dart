import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

/// Default soul ID used across tests.
const kTestSoulId = 'soul-001';

// ── Soul document factories ─────────────────────────────────────────────────

SoulDocumentEntity makeTestSoulDocument({
  String id = kTestSoulId,
  String agentId = kTestSoulId,
  String displayName = 'Test Soul',
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.soulDocument(
        id: id,
        agentId: agentId,
        displayName: displayName,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as SoulDocumentEntity;
}

SoulDocumentVersionEntity makeTestSoulDocumentVersion({
  String id = 'soul-version-001',
  String agentId = kTestSoulId,
  int version = 1,
  SoulDocumentVersionStatus status = SoulDocumentVersionStatus.active,
  String authoredBy = 'user',
  String voiceDirective = 'Be warm and clear.',
  String toneBounds = '',
  String coachingStyle = '',
  String antiSycophancyPolicy = '',
  String? sourceSessionId,
  String? diffFromVersionId,
  DateTime? createdAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.soulDocumentVersion(
        id: id,
        agentId: agentId,
        version: version,
        status: status,
        authoredBy: authoredBy,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        voiceDirective: voiceDirective,
        toneBounds: toneBounds,
        coachingStyle: coachingStyle,
        antiSycophancyPolicy: antiSycophancyPolicy,
        sourceSessionId: sourceSessionId,
        diffFromVersionId: diffFromVersionId,
      )
      as SoulDocumentVersionEntity;
}

SoulDocumentHeadEntity makeTestSoulDocumentHead({
  String id = 'soul-head-001',
  String agentId = kTestSoulId,
  String versionId = 'soul-version-001',
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.soulDocumentHead(
        id: id,
        agentId: agentId,
        versionId: versionId,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as SoulDocumentHeadEntity;
}

SoulAssignmentLink makeTestSoulAssignmentLink({
  String id = 'soul-link-001',
  String fromId = kTestTemplateId,
  String toId = kTestSoulId,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) {
  return AgentLink.soulAssignment(
        id: id,
        fromId: fromId,
        toId: toId,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as SoulAssignmentLink;
}
