import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show AgentLifecycle, AgentTemplateKind, WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
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
    ProjectActivityCancellationCoordinator? cancellationCoordinator,
  }) : _cancellationCoordinator =
           cancellationCoordinator ?? ProjectActivityCancellationCoordinator();

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;
  final Future<bool> Function(
    String projectId,
    Set<String> allowedCategoryIds,
  )
  projectScopeIsCurrent;
  final ProjectAgentMutationCoordinator mutationCoordinator;
  final ProjectActivityCancellationCoordinator _cancellationCoordinator;

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
  /// 7. Enqueue a creation wake with a one-shot persisted fallback.
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
  }) => mutationCoordinator.run(projectId, () async {
    if (!await projectScopeIsCurrent(projectId, allowedCategoryIds)) {
      throw StateError('Project $projectId no longer has the requested scope.');
    }

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
        slots: state.slots.copyWith(
          activeProjectId: projectId,
          pendingProjectActivityAt: now,
        ),
        // The creation wake is queued in memory for immediate execution. This
        // one-shot fallback makes that explicit work durable across a process
        // exit and is cleared by the first successful wake; it never recurs.
        scheduledWakeAt: nextOccurrenceOf(
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

  /// Cancel a scheduled wake for [agentId].
  ///
  /// Deletes both persisted deadline fields and the pending activity marker in
  /// one state write before clearing the throttle timer and queued jobs.
  ///
  /// Persistence is intentionally first: if the transaction rolls back, the
  /// runtime work remains available and the UI can report that cancellation
  /// did not complete instead of displaying state that disagrees with storage.
  /// If only the post-commit sync flush fails, runtime cleanup still follows
  /// the committed state before the sync error is surfaced to the caller.
  /// Mirrors `TaskAgentService.cancelScheduledWake` so the project AI Report
  /// header's cancel × has the same semantics as the task AI summary one.
  Future<void> cancelScheduledWake(String agentId) async {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'scheduled wake cancelled for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    final cancelledAt = clock.now();
    await _cancellationCoordinator.runCancellation(
      agentId: agentId,
      action: (confirmCancellationCommit) async {
        void clearRuntimeWake() {
          orchestrator
            ..clearThrottle(agentId)
            ..cancelPendingWakes(agentId, allWorkspaces: true);
        }

        var persistedCancellation = false;
        try {
          await syncService.runInTransaction(() async {
            final state = await repository.getAgentState(agentId);
            if (state == null ||
                (state.nextWakeAt == null &&
                    state.scheduledWakeAt == null &&
                    state.slots.pendingProjectActivityAt == null)) {
              return;
            }
            await syncService.upsertEntity(
              state.copyWith(
                slots: state.slots.copyWith(pendingProjectActivityAt: null),
                nextWakeAt: null,
                scheduledWakeAt: null,
                updatedAt: cancelledAt,
              ),
            );
            persistedCancellation = true;
          });
        } catch (error, stackTrace) {
          var cancellationCommitted = false;
          if (persistedCancellation) {
            try {
              final current = await repository.getAgentState(agentId);
              cancellationCommitted =
                  current == null ||
                  (current.nextWakeAt == null &&
                      current.scheduledWakeAt == null &&
                      current.slots.pendingProjectActivityAt == null);
            } catch (_) {
              // Preserve the original transaction/sync failure. If the state
              // cannot be confirmed, leaving runtime work intact is the safe
              // side.
            }
          }
          if (cancellationCommitted) {
            confirmCancellationCommit();
            onPersistedStateChanged?.call(agentId);
            clearRuntimeWake();
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (persistedCancellation) onPersistedStateChanged?.call(agentId);

        clearRuntimeWake();
      },
    );
  }

  /// Restore project-agent runtime state after app startup.
  ///
  /// Project agents restore short-delay subscriptions for direct project edits
  /// and rehydrate any persisted deferred wake jobs, while task-driven
  /// activity remains schedule-driven via pending-project-activity markers.
  /// States and `agent_project` links are loaded in bulk before the per-agent
  /// loop so a database failure aborts this restoration pass once.
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
        var state = await _retireDormantDailySchedule(
          statesByAgentId[agent.agentId],
        );
        for (final link in links) {
          _registerProjectSubscription(agent.agentId, link.toId);
        }
        final reconciliation = await _reconcilePendingActivityFallback(
          agentId: agent.agentId,
        );
        state = reconciliation.state;
        if (reconciliation.automaticWakesAllowed) {
          orchestrator.enableAutomaticUpdatesRuntime(agent.agentId);
          _hydrateThrottleDeadlineFromState(agent.agentId, state);
        } else {
          if (!reconciliation.active) {
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

  void _registerProjectSubscription(String agentId, String projectId) {
    orchestrator.addSubscription(
      AgentSubscription(
        id: '${agentId}_project_direct_$projectId',
        agentId: agentId,
        matchEntityIds: {projectEntityUpdateNotification(projectId)},
      ),
    );
  }

  /// Reconciles a project agent's device-local fallback with current policy.
  ///
  /// The bulk startup snapshots are only hints. Identity policy is re-read in
  /// the same transaction that may arm or clear a fallback so a concurrent
  /// opt-out or lifecycle change controls both persistence and runtime state.
  Future<
    ({
      AgentStateEntity? state,
      bool active,
      bool automaticWakesAllowed,
    })
  >
  _reconcilePendingActivityFallback({
    required String agentId,
  }) async {
    AgentStateEntity? result;
    var active = false;
    var automaticWakesAllowed = false;
    var changed = false;
    await repository.runInTransaction(() async {
      final currentIdentity = await repository.getEntity(agentId);
      if (currentIdentity is AgentIdentityEntity) {
        active = currentIdentity.lifecycle == AgentLifecycle.active;
        automaticWakesAllowed = projectAgentAutomaticWakesAllowed(
          config: currentIdentity.config,
          lifecycle: currentIdentity.lifecycle,
        );
      }
      final current = await repository.getAgentState(agentId);
      result = current;
      if (current == null || current.deletedAt != null) {
        return;
      }

      final DateTime? scheduledWakeAt;
      if (automaticWakesAllowed) {
        if (current.slots.pendingProjectActivityAt == null ||
            current.scheduledWakeAt != null) {
          result = current;
          return;
        }
        scheduledWakeAt = nextOccurrenceOf(
          clock.now(),
          hour: AgentSchedules.projectDailyDigestHour,
        );
      } else {
        if (current.scheduledWakeAt == null) {
          result = current;
          return;
        }
        scheduledWakeAt = null;
      }

      // This deadline exists only on this device. Do not advance the synced
      // vector clock or LWW timestamp: doing so could make an obsolete pending
      // marker beat another device's successful completion during merge.
      final updated = current.copyWith(scheduledWakeAt: scheduledWakeAt);
      await repository.upsertEntity(updated);
      result = updated;
      changed = true;
    });
    if (changed) onPersistedStateChanged?.call(agentId);
    return (
      state: result,
      active: active,
      automaticWakesAllowed: automaticWakesAllowed,
    );
  }

  /// Removes the legacy always-on daily digest from an idle project agent.
  ///
  /// Project updates persist an event-driven wake only while work is pending.
  /// Retaining `scheduledWakeAt` after a completed wake when there is no
  /// pending project activity only keeps a meaningless 06:00 row alive in the
  /// Wake tab. Never-woken agents and schedules with pending activity remain
  /// one-shot durability fallbacks and are retired by a successful wake.
  Future<AgentStateEntity?> _retireDormantDailySchedule(
    AgentStateEntity? state,
  ) async {
    if (state == null ||
        state.scheduledWakeAt == null ||
        state.lastWakeAt == null ||
        state.slots.pendingProjectActivityAt != null) {
      return state;
    }

    AgentStateEntity? result;
    var changed = false;
    await repository.runInTransaction(() async {
      // The monitor or a user can write after the bulk snapshot above. Re-read
      // and validate inside the same local transaction as the write so
      // cleanup cannot erase newer activity or a manual schedule.
      final currentState = await repository.getAgentState(state.agentId);
      final snapshotChanged =
          currentState?.updatedAt != state.updatedAt ||
          currentState?.vectorClock != state.vectorClock;
      if (snapshotChanged ||
          currentState == null ||
          currentState.scheduledWakeAt == null ||
          currentState.lastWakeAt == null ||
          currentState.slots.pendingProjectActivityAt != null) {
        result = currentState;
        return;
      }

      // This retirement is device-local scheduling maintenance. Preserve the
      // synced LWW timestamp and vector clock so a stale device cannot publish
      // cleanup as a newer whole-row state version.
      final updatedState = currentState.copyWith(scheduledWakeAt: null);
      await repository.upsertEntity(updatedState);
      result = updatedState;
      changed = true;
    });
    if (!changed) return result;
    onPersistedStateChanged?.call(state.agentId);
    domainLogger?.log(
      LogDomain.agentRuntime,
      'retired dormant daily schedule for '
      '${DomainLogger.sanitizeId(state.agentId)}',
      subDomain: 'restore',
    );
    return result;
  }

  void _hydrateThrottleDeadlineFromState(
    String agentId,
    AgentStateEntity? state,
  ) {
    final deadline = state?.nextWakeAt;
    final hasPendingActivity = state?.slots.pendingProjectActivityAt != null;
    final hasPendingCreation =
        state != null &&
        state.lastWakeAt == null &&
        state.scheduledWakeAt != null;
    if (deadline != null && (hasPendingActivity || hasPendingCreation)) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
  }
}
