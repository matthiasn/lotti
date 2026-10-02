import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show
        AgentInferenceSetupMode,
        AgentInferenceSetupOrigin,
        AgentLifecycle,
        AgentTemplateKind,
        WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/project_agent_mutation_coordinator.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/service/project_agent_mutation_coordinator.dart'
    show ProjectAgentMutationCoordinator;

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
    required this.projectScopeIsCurrent,
    required this.mutationCoordinator,
    this.domainLogger,
    this.onPersistedStateChanged,
    this.armProjectUpdate,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;
  final Future<bool> Function(
    String projectId,
    Set<String> allowedCategoryIds,
  )
  projectScopeIsCurrent;
  final ProjectAgentMutationCoordinator mutationCoordinator;

  /// Arms the agent's next update slot when its report is stale and
  /// automatic updates are on (`ProjectUpdateCadence.arm`).
  final Future<void> Function(String agentId)? armProjectUpdate;

  /// Sync-aware write service. All entity/link writes go through this so
  /// they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;
  final void Function(String agentId)? onPersistedStateChanged;

  static const _uuid = Uuid();
  static const String _agentKind = AgentKinds.projectAgent;

  /// Create a new Project Agent for [projectId].
  ///
  /// Steps:
  /// 1. Serialize with project deletion and verify the project still exists.
  /// 2. Create the agent via [AgentService.createAgent] with kind
  ///    `'project_agent'`.
  /// 3. Update the agent's state with `activeProjectId = projectId`.
  /// 4. Create an [AgentProjectLink] from agentId → projectId.
  /// 5. If [templateId] is provided, create a `templateAssignment` link.
  /// 6. Compensate a concurrent sync tombstone before announcing the agent.
  /// 7. Enqueue the creation wake. The new agent's report counts as stale
  ///    until that wake writes one, so a failed creation wake is retried by
  ///    the agent's next update slot when automatic updates are on.
  ///
  /// A non-empty [profileId] is stored as a typed, authoritative inference
  /// setup, so the agent runs on exactly that profile and never falls through
  /// to the template's built-in model. [setupOrigin] and [setupOriginEntityId]
  /// record where it came from — the category whose default was copied, or
  /// the user who picked it (the default origin). Without a [profileId] the
  /// agent keeps the legacy resolution chain (template profile, template
  /// model, device default).
  ///
  /// Returns the created [AgentIdentityEntity].
  ///
  /// Throws [StateError] if the project no longer exists, its current category
  /// differs from [allowedCategoryIds], or a Project Agent already exists for
  /// [projectId].
  Future<AgentIdentityEntity> createProjectAgent({
    required String projectId,
    required String templateId,
    required String displayName,
    required Set<String> allowedCategoryIds,
    String? profileId,
    AgentInferenceSetupOrigin setupOrigin = AgentInferenceSetupOrigin.user,
    String? setupOriginEntityId,
  }) => mutationCoordinator.run(projectId, () async {
    if (!await projectScopeIsCurrent(projectId, allowedCategoryIds)) {
      throw StateError('Project $projectId no longer has the requested scope.');
    }
    // An empty id names no profile; stored as a configured setup it could
    // never resolve and would block the legacy fallbacks.
    final assignedProfileId = profileId == null || profileId.isEmpty
        ? null
        : profileId;

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
          templateEntity.kind != AgentTemplateKind.projectAgent ||
          !_templateAppliesToScope(templateEntity, allowedCategoryIds)) {
        throw StateError(
          'Template $templateId is not an active project-agent template for '
          'the requested project scope.',
        );
      }

      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName,
        config: AgentConfig(
          profileId: assignedProfileId,
          inferenceSetup: assignedProfileId == null
              ? null
              : AgentInferenceSetup(
                  mode: AgentInferenceSetupMode.configured,
                  origin: setupOrigin,
                  baseProfileId: assignedProfileId,
                  originEntityId: setupOriginEntityId,
                ),
        ),
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
        slots: state.slots.copyWith(
          activeProjectId: projectId,
          pendingProjectActivityAt: now,
        ),
        // No report yet: stale until the creation wake writes one. The wake
        // itself is durable through its wake intent.
        reportStaleAt: now,
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

    // Sync can tombstone the journal project while the independent agent-store
    // transaction is committing. Compensate before announcing, subscribing, or
    // waking the new identity so no orphan project agent escapes this method.
    if (!await projectScopeIsCurrent(projectId, allowedCategoryIds)) {
      await agentService.deleteAgent(identity.agentId);
      throw StateError('Project $projectId no longer has the requested scope.');
    }

    onPersistedStateChanged
      ?..call(identity.agentId)
      // `projectAgentProvider` refreshes on the *project* id, and nothing in
      // the agent write path emits it — identity, state and links all go
      // through `AgentSyncService`, which does not notify. Without this the
      // agent stays invisible until something unrelated happens to ping the
      // project. Both ids coalesce into one `notifyUiOnly` batch.
      ..call(projectId);

    _registerProjectSubscription(identity.agentId, projectId);

    // Enqueue the creation wake.
    orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: WakeReason.creation.name,
      triggerTokens: {projectId},
    );

    domainLogger?.log(
      LogDomain.agentRuntime,
      'created project agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for project ${DomainLogger.sanitizeId(projectId)}',
      subDomain: 'lifecycle',
    );

    return identity;
  });

  static bool _templateAppliesToScope(
    AgentTemplateEntity template,
    Set<String> allowedCategoryIds,
  ) {
    if (template.categoryIds.isEmpty) return true;
    return allowedCategoryIds.length == 1 &&
        template.categoryIds.contains(allowedCategoryIds.single);
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

  /// Finds every live project agent linked to [projectId].
  ///
  /// Concurrent provisioning can temporarily leave multiple active links for
  /// one project. Destructive project operations must retire all of them, not
  /// only the primary identity used for ordinary report presentation.
  Future<List<AgentIdentityEntity>> getProjectAgentsForProject(
    String projectId,
  ) async {
    final links = (await repository.getLinksTo(
      projectId,
      type: AgentLinkTypes.agentProject,
    )).orderedPrimaryFirst();
    final agentIds = <String>[];
    final seenAgentIds = <String>{};
    for (final link in links) {
      if (seenAgentIds.add(link.fromId)) agentIds.add(link.fromId);
    }
    if (agentIds.isEmpty) return const [];

    final entitiesById = await repository.getEntitiesByIds(agentIds);
    return [
      for (final agentId in agentIds)
        if (entitiesById[agentId] case final AgentIdentityEntity identity)
          if (identity.kind == _agentKind &&
              identity.lifecycle != AgentLifecycle.destroyed)
            identity,
    ];
  }

  /// Re-scopes every live project agent to [allowedCategoryIds].
  ///
  /// Synced project edits share the coordinator used by provisioning and
  /// deletion. Stale scope requests are ignored; identities are re-read inside
  /// the agent transaction so unrelated preference changes are preserved.
  /// Agents with missing, deleted, or category-incompatible templates are
  /// retired without ever granting access to the new category.
  Future<void> updateProjectAgentScopes({
    required String projectId,
    required Set<String> allowedCategoryIds,
  }) => mutationCoordinator.run(projectId, () async {
    if (!await projectScopeIsCurrent(projectId, allowedCategoryIds)) return;
    final updatedIds = <String>[];
    final incompatibleIds = <String>[];
    await syncService.runInTransaction(() async {
      final identities = await getProjectAgentsForProject(projectId);
      for (final identity in identities) {
        final assignments = await repository.getLinksTo(
          identity.agentId,
          type: AgentLinkTypes.templateAssignment,
        );
        final template = assignments.isEmpty
            ? null
            : await repository.getEntity(assignments.selectPrimary().fromId);
        if (template is! AgentTemplateEntity ||
            template.deletedAt != null ||
            template.kind != AgentTemplateKind.projectAgent ||
            !_templateAppliesToScope(template, allowedCategoryIds)) {
          incompatibleIds.add(identity.agentId);
          continue;
        }
        if (identity.allowedCategoryIds.length == allowedCategoryIds.length &&
            identity.allowedCategoryIds.containsAll(allowedCategoryIds)) {
          continue;
        }
        await syncService.upsertEntity(
          identity.copyWith(
            allowedCategoryIds: Set<String>.unmodifiable(allowedCategoryIds),
            updatedAt: clock.now(),
          ),
        );
        updatedIds.add(identity.agentId);
      }
    });
    // Keep incompatible agents on their old scope until retirement commits.
    // Lifecycle writes own their transaction and runtime cleanup; never detach
    // subscriptions from inside an enclosing transaction that could roll back.
    for (final agentId in incompatibleIds) {
      agentService
        ..abortRunningWake(agentId)
        ..cancelPendingWake(agentId);
      await agentService.destroyAgent(agentId);
      updatedIds.add(agentId);
    }
    if (updatedIds.isNotEmpty) {
      onPersistedStateChanged?.call(projectId);
      final notify = onPersistedStateChanged;
      if (notify != null) updatedIds.forEach(notify);
    }
  });

  /// Trigger a manual re-analysis wake for [agentId].
  void triggerReanalysis(String agentId) {
    domainLogger?.log(
      LogDomain.agentRuntime,
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
  /// Registers each active project agent's stale-marking subscription, sets
  /// its automation runtime, retires the device-local deadlines older builds
  /// scheduled project wakes with, and arms its next update slot if its report
  /// is stale — the repair for an arm lost to a process death. States and
  /// `agent_project` links are loaded in bulk before the per-agent loop so a
  /// database failure aborts this restoration pass once.
  Future<void> restoreSubscriptions() async {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'restoring project agent runtime state...',
      subDomain: 'restore',
    );

    final activeAgents = await agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );
    final projectAgents = activeAgents
        .where((agent) => agent.kind == _agentKind)
        .toList(growable: false);
    final agentIds = [for (final agent in projectAgents) agent.agentId];
    final statesByAgentId = projectAgents.isEmpty
        ? const <String, AgentStateEntity>{}
        : await repository.getAgentStatesByAgentIds(agentIds);
    final linksByAgentId = projectAgents.isEmpty
        ? const <String, List<AgentLink>>{}
        : await repository.getLinksFromMultiple(
            agentIds,
            type: AgentLinkTypes.agentProject,
          );

    var count = 0;
    for (final agent in projectAgents) {
      try {
        final links = linksByAgentId[agent.agentId] ?? const <AgentLink>[];
        await _retireLegacyDeadlines(statesByAgentId[agent.agentId]);
        for (final link in links) {
          _registerProjectSubscription(agent.agentId, link.toId);
        }
        // The bulk listing is only a hint: re-read the identity so a
        // concurrent pause or opt-out controls the runtime restored here.
        final current = await repository.getEntity(agent.agentId);
        final identity = current is AgentIdentityEntity ? current : null;
        if (identity != null &&
            projectAgentAutomaticWakesAllowed(
              config: identity.config,
              lifecycle: identity.lifecycle,
            )) {
          orchestrator.enableAutomaticUpdatesRuntime(agent.agentId);
          await armProjectUpdate?.call(agent.agentId);
        } else {
          if (identity?.lifecycle != AgentLifecycle.active) {
            orchestrator.removeSubscriptions(agent.agentId);
          }
          orchestrator.disableAutomaticUpdatesRuntime(agent.agentId);
        }
        count++;
      } catch (e, s) {
        final msg =
            'failed to restore runtime state '
            'for ${DomainLogger.sanitizeId(agent.agentId)}';
        if (domainLogger != null) {
          domainLogger!.error(
            LogDomain.agentRuntime,
            e,
            message: msg,
            stackTrace: s,
          );
        } else {
          developer.log(
            '$msg (errorType=${e.runtimeType})',
            name: 'ProjectAgentService',
            error: e.runtimeType,
            stackTrace: s,
          );
        }
      }
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'restored $count project agent(s)',
      subDomain: 'restore',
    );
  }

  /// Marks the report stale on a direct project edit. It never queues a
  /// wake: project work runs only in update slots (`ProjectUpdateCadence`).
  void _registerProjectSubscription(String agentId, String projectId) {
    orchestrator.addSubscription(
      AgentSubscription(
        id: '${agentId}_project_direct_$projectId',
        agentId: agentId,
        matchEntityIds: {projectEntityUpdateNotification(projectId)},
        reportStaleOnly: true,
      ),
    );
  }

  /// Clears the device-local deadlines — a 06:00 `scheduledWakeAt` fallback,
  /// a throttle `nextWakeAt` — that older builds scheduled project wakes with.
  /// Update slots replace both; a leftover would fire one wake the cadence
  /// knows nothing about. Local maintenance only: the synced timestamp and
  /// vector clock are kept, so it cannot win a peer merge.
  Future<void> _retireLegacyDeadlines(AgentStateEntity? snapshot) async {
    if (snapshot == null ||
        (snapshot.scheduledWakeAt == null && snapshot.nextWakeAt == null)) {
      return;
    }
    orchestrator.clearThrottle(snapshot.agentId);
    await repository.runInTransaction(() async {
      final current = await repository.getAgentState(snapshot.agentId);
      if (current == null ||
          (current.scheduledWakeAt == null && current.nextWakeAt == null)) {
        return;
      }
      await repository.upsertEntity(
        current.copyWith(scheduledWakeAt: null, nextWakeAt: null),
      );
    });
    onPersistedStateChanged?.call(snapshot.agentId);
    domainLogger?.log(
      LogDomain.agentRuntime,
      'retired legacy project deadlines for '
      '${DomainLogger.sanitizeId(snapshot.agentId)}',
      subDomain: 'restore',
    );
  }
}
