import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/template_factories.dart';
import '../test_data/wake_factories.dart';

// ── Multi-entity setup helpers ──────────────────────────────────────────────

/// Seeds a template entity, one or more agent instances, and
/// [model.AgentLink.templateAssignment] links connecting them.
///
/// Returns the template's agentId so callers can reference it.
Future<String> seedTemplateWithInstances(
  AgentRepository repo, {
  required String templateId,
  required List<String> instanceAgentIds,
  DateTime? testDate,
}) async {
  await repo.upsertEntity(
    makeTestTemplate(
      id: templateId,
      agentId: templateId,
      createdAt: testDate,
      updatedAt: testDate,
    ),
  );

  for (final agentId in instanceAgentIds) {
    await repo.upsertEntity(
      makeTestIdentity(id: agentId, agentId: agentId),
    );
    await repo.upsertLink(
      makeTestTemplateAssignmentLink(
        id: 'link-ta-$agentId',
        fromId: templateId,
        toId: agentId,
        createdAt: testDate,
        updatedAt: testDate,
      ),
    );
  }

  return templateId;
}

/// Inserts a report entity and its matching report head in one call.
///
/// Useful for tests that need a "latest report" to be resolvable via the
/// head pointer.
Future<({AgentReportEntity report, AgentReportHeadEntity head})>
setupReportWithHead(
  AgentRepository repo, {
  required String reportId,
  required String headId,
  required String agentId,
  String scope = AgentReportScopes.current,
  DateTime? createdAt,
  DateTime? updatedAt,
  String content = 'Test report content',
  String? oneLiner,
  String? tldr,
}) async {
  final report = makeTestReport(
    id: reportId,
    agentId: agentId,
    scope: scope,
    createdAt: createdAt,
    content: content,
    oneLiner: oneLiner,
    tldr: tldr,
  );
  final head = makeTestReportHead(
    id: headId,
    agentId: agentId,
    scope: scope,
    reportId: reportId,
    updatedAt: updatedAt ?? createdAt,
  );

  await repo.upsertEntity(report);
  await repo.upsertEntity(head);

  return (report: report, head: head);
}

/// Seeds a project-agent link (agentProject type) pointing from
/// [agentId] to [projectId].
Future<void> seedProjectAgentLink(
  AgentRepository repo, {
  required String linkId,
  required String agentId,
  required String projectId,
  DateTime? createdAt,
}) async {
  final timestamp = createdAt;
  await repo.upsertLink(
    model.AgentLink.agentProject(
      id: linkId,
      fromId: agentId,
      toId: projectId,
      createdAt: timestamp ?? DateTime(2026, 2, 20),
      updatedAt: timestamp ?? DateTime(2026, 2, 20),
      vectorClock: null,
    ),
  );
}

/// Seeds a task-agent link (agentTask type).
Future<void> seedTaskAgentLink(
  AgentRepository repo, {
  required String linkId,
  required String agentId,
  required String taskId,
  DateTime? createdAt,
}) async {
  final timestamp = createdAt;
  await repo.upsertLink(
    model.AgentLink.agentTask(
      id: linkId,
      fromId: agentId,
      toId: taskId,
      createdAt: timestamp ?? DateTime(2026, 2, 20),
      updatedAt: timestamp ?? DateTime(2026, 2, 20),
      vectorClock: null,
    ),
  );
}

/// Inserts a wake run log entry with template columns pre-filled.
Future<void> insertTemplateWakeRun(
  AgentRepository repo, {
  required String runKey,
  required String templateId,
  String agentId = 'agent-001',
  String status = 'completed',
  DateTime? createdAt,
  String templateVersionId = 'ver-001',
}) async {
  await repo.insertWakeRun(
    entry: makeTestWakeRun(
      runKey: runKey,
      agentId: agentId,
      status: status,
      createdAt: createdAt,
      templateId: templateId,
      templateVersionId: templateVersionId,
    ),
  );
}
