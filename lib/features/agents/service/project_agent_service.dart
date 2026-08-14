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
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/db_notification.dart';
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
    this.onPersistedStateChanged,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

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
  /// 1. Create the agent via [AgentService.createAgent] with kind
  ///    `'project_agent'`.
  /// 2. Update the agent's state with `activeProjectId = projectId`.
  /// 3. Create an [AgentProjectLink] from agentId → projectId.
  /// 4. If [templateId] is provided, create a `templateAssignment` link.
  /// 5. Enqueue a creation wake with a one-shot persisted fallback.
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
  /// Deletes both persisted deadline fields in one state write before clearing
  /// the throttle timer and queued subscription jobs.
  ///
  /// Persistence is intentionally first: if that write fails, the runtime
  /// work remains available and the UI can report that cancellation did not
  /// complete instead of displaying state that disagrees with storage.
  /// Mirrors `TaskAgentService.cancelScheduledWake` so the project AI Report
  /// header's cancel × has the same semantics as the task AI summary one.
  Future<void> cancelScheduledWake(String agentId) async {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'scheduled wake cancelled for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    final state = await repository.getAgentState(agentId);
    if (state != null &&
        (state.nextWakeAt != null || state.scheduledWakeAt != null)) {
      await syncService.upsertEntity(
        state.copyWith(
          nextWakeAt: null,
          scheduledWakeAt: null,
          updatedAt: clock.now(),
        ),
      );
      onPersistedStateChanged?.call(agentId);
    }

    orchestrator
      ..clearThrottle(agentId)
      ..cancelPendingWakes(agentId, allWorkspaces: true);
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
        if (projectAgentAutomaticWakesAllowed(
          config: agent.config,
          lifecycle: agent.lifecycle,
        )) {
          state = await _armPendingActivityFallback(state);
          orchestrator.enableAutomaticUpdatesRuntime(agent.agentId);
          _hydrateThrottleDeadlineFromState(agent.agentId, state);
        } else {
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

  /// Restores a missing local fallback for already-pending project activity.
  ///
  /// The startup snapshot is only a hint. Re-read immediately before writing
  /// so a cancellation, completion, or manual schedule that lands during
  /// restoration wins instead of being overwritten by the stale snapshot.
  Future<AgentStateEntity?> _armPendingActivityFallback(
    AgentStateEntity? snapshot,
  ) async {
    if (snapshot == null ||
        snapshot.slots.pendingProjectActivityAt == null ||
        snapshot.scheduledWakeAt != null) {
      return snapshot;
    }

    final current = await repository.getAgentState(snapshot.agentId);
    if (current == null ||
        current.deletedAt != null ||
        current.slots.pendingProjectActivityAt == null ||
        current.scheduledWakeAt != null) {
      return current;
    }

    final now = clock.now();
    final updated = current.copyWith(
      scheduledWakeAt: nextOccurrenceOf(
        now,
        hour: AgentSchedules.projectDailyDigestHour,
      ),
      updatedAt: now,
    );
    await syncService.upsertEntity(updated);
    onPersistedStateChanged?.call(current.agentId);
    return updated;
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

    // The monitor or a user can write after the bulk snapshot above. Re-read
    // before a whole-row upsert, and only migrate the exact snapshot we
    // inspected, so cleanup cannot erase newer activity or a manual schedule.
    final currentState = await repository.getAgentState(state.agentId);
    final snapshotChanged =
        currentState?.updatedAt != state.updatedAt ||
        currentState?.vectorClock != state.vectorClock;
    if (snapshotChanged) return currentState;
    if (currentState == null ||
        currentState.scheduledWakeAt == null ||
        currentState.lastWakeAt == null ||
        currentState.slots.pendingProjectActivityAt != null) {
      return currentState;
    }

    final updatedState = currentState.copyWith(
      scheduledWakeAt: null,
      updatedAt: clock.now(),
    );
    await syncService.upsertEntity(updatedState);
    onPersistedStateChanged?.call(currentState.agentId);
    domainLogger?.log(
      LogDomain.agentRuntime,
      'retired dormant daily schedule for '
      '${DomainLogger.sanitizeId(currentState.agentId)}',
      subDomain: 'restore',
    );
    return updatedState;
  }

  void _hydrateThrottleDeadlineFromState(
    String agentId,
    AgentStateEntity? state,
  ) {
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
  }
}
