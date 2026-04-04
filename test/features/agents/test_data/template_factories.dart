import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';

// ── Template entity factories ────────────────────────────────────────────────

AgentTemplateEntity makeTestTemplate({
  String id = kTestTemplateId,
  String agentId = kTestTemplateId,
  String displayName = 'Test Template',
  AgentTemplateKind kind = AgentTemplateKind.taskAgent,
  String modelId = 'models/gemini-3-flash-preview',
  Set<String> categoryIds = const {},
  String? profileId,
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
        profileId: profileId,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as AgentTemplateEntity;
}

AgentTemplateVersionEntity makeTestTemplateVersion({
  String id = 'version-001',
  String agentId = kTestTemplateId,
  int version = 1,
  AgentTemplateVersionStatus status = AgentTemplateVersionStatus.active,
  String directives = 'You are a helpful agent.',
  String generalDirective = '',
  String reportDirective = '',
  String authoredBy = 'user',
  String? modelId,
  String? profileId,
  DateTime? createdAt,
  VectorClock? vectorClock,
}) {
  return AgentDomainEntity.agentTemplateVersion(
        id: id,
        agentId: agentId,
        version: version,
        status: status,
        directives: directives,
        generalDirective: generalDirective,
        reportDirective: reportDirective,
        authoredBy: authoredBy,
        modelId: modelId,
        profileId: profileId,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
      )
      as AgentTemplateVersionEntity;
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
      )
      as AgentTemplateHeadEntity;
}
