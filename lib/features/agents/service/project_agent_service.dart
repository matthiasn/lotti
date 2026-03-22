import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show AgentLifecycle, AgentTemplateKind, WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Project-agent-specific lifecycle management.
///
/// Mirrors `TaskAgentService` but manages project-scoped agents that monitor
/// linked tasks and produce project-level reports and recommendations.
class ProjectAgentService {
  ProjectAgentService({
    required this.agentService,
    required this.repository,
    required this.orchestrator,
    required this.syncService,
    this.domainLogger,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  /// Sync-aware write service. All entity/link writes go through this so
  /// they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  static const _uuid = Uuid();
  static const String _agentKind = AgentKinds.projectAgent;

  /// Create a new Project Agent for [projectId].
  ///
  /// Steps:
  /// 1. Create the agent via [AgentService.createAgent] with kind
  ///    `'project_agent'`.
  /// 2. Update the agent's state with `activeProjectId = projectId`.
  /// 3. Create an [AgentProjectLink] from agentId → projectId.
  /// 4. If [templateId] is provided, create a `templateAssignment` link.
  /// 5. Enqueue a creation wake.
  ///
  /// Returns the created [AgentIdentityEntity].
  ///
  /// Throws [StateError] if a Project Agent already exists for [projectId].
  Future<AgentIdentityEntity> createProjectAgent({
    required String projectId,
    required String templateId,
    required String displayName,
    required Set<String> allowedCategoryIds,
    String? profileId,
  }) async {
    final identity = await syncService.runInTransaction(() async {
      // Definitive duplicate check inside the transaction to prevent
      // concurrent createProjectAgent calls from both committing.
      final linksForProject = await repository.getLinksTo(
        projectId,
        type: AgentLinkTypes.agentProject,
      );
      if (linksForProject.isNotEmpty) {
        final primaryLink = linksForProject.selectPrimary();
        throw StateError(
          'A project agent already exists for project $projectId '
          '(agent ${primaryLink.fromId})',
        );
      }

      // Validate the template.
      final templateEntity = await repository.getEntity(templateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null ||
          templateEntity.kind != AgentTemplateKind.projectAgent) {
        throw StateError(
          'Template $templateId is not an active project-agent template.',
        );
      }

      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName,
        config: AgentConfig(profileId: profileId),
        allowedCategoryIds: allowedCategoryIds,
      );

      // Update state with activeProjectId.
      final state = await repository.getAgentState(identity.agentId);
      if (state == null) {
        throw StateError(
          'Agent ${identity.agentId} was just created but has no state entity',
        );
      }

      final now = clock.now();
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(activeProjectId: projectId),
        scheduledWakeAt: nextLocalDayAtTime(
          now,
          hour: AgentSchedules.projectDailyDigestHour,
        ),
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedState);

      // Create agent_project link: agent → project.
      final projectLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.agentProject(
          id: projectLinkId,
          fromId: identity.agentId,
          toId: projectId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      // Create template_assignment link.
      final templateLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: templateLinkId,
          fromId: templateId,
          toId: identity.agentId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      return identity;
    });

    // Enqueue the creation wake.
    orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: WakeReason.creation.name,
      triggerTokens: {projectId},
    );

    domainLogger?.log(
      LogDomains.agentRuntime,
      'created project agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for project ${DomainLogger.sanitizeId(projectId)}',
      subDomain: 'lifecycle',
    );

    return identity;
  }

  /// Find the Project Agent for [projectId], or `null` if none exists.
  ///
  /// Looks up `AgentProjectLink`s pointing to [projectId] and resolves the
  /// agent identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getProjectAgentForProject(
    String projectId,
  ) async {
    final links = await repository.getLinksTo(
      projectId,
      type: AgentLinkTypes.agentProject,
    );
    if (links.isEmpty) return null;

    final agentId = links.selectPrimary().fromId;
    return agentService.getAgent(agentId);
  }

  /// Trigger a manual re-analysis wake for [agentId].
  void triggerReanalysis(String agentId) {
    domainLogger?.log(
      LogDomains.agentRuntime,
      'manual reanalysis triggered for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: WakeReason.reanalysis.name,
    );
  }

  /// Restore project-agent runtime state after app startup.
  ///
  /// Project agents are schedule-driven: local task/project edits only mark
  /// the summary as stale, and the actual report runs on the next scheduled
  /// wake. There are therefore no per-project subscriptions to restore here.
  Future<void> restoreSubscriptions() async {
    domainLogger?.log(
      LogDomains.agentRuntime,
      'restoring project agent runtime state...',
      subDomain: 'restore',
    );

    final activeAgents = await agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );

    var count = 0;
    for (final agent in activeAgents) {
      if (agent.kind != _agentKind) continue;

      try {
        count++;
      } catch (e, s) {
        final msg =
            'failed to restore runtime state '
            'for ${DomainLogger.sanitizeId(agent.agentId)}';
        if (domainLogger != null) {
          domainLogger!.error(
            LogDomains.agentRuntime,
            msg,
            error: e,
            stackTrace: s,
          );
        } else {
          developer.log(
            '$msg: $e',
            name: 'ProjectAgentService',
            error: e,
            stackTrace: s,
          );
        }
      }
    }

    domainLogger?.log(
      LogDomains.agentRuntime,
      'restored $count project agent(s)',
      subDomain: 'restore',
    );
  }
}
