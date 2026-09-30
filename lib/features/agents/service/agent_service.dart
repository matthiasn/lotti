import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_sidecar_reclaimer.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// High-level agent lifecycle management.
///
/// Provides operations for creating, listing, pausing, resuming, and destroying
/// agents. Each mutation writes via [AgentSyncService] (which enqueues changes
/// for cross-device sync) and reads via [AgentRepository]. Where relevant, it
/// updates the [WakeOrchestrator]'s subscription state so that wake triggers
/// are registered or withdrawn immediately.
class AgentService {
  AgentService({
    required this.repository,
    required this.orchestrator,
    required this.syncService,
    this.onPersistedStateChanged,
    this.sidecarReclaimer,
  });

  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  /// Sync-aware write service. All entity/link writes go through this so
  /// they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Removes the JSON sidecars of hard-deleted rows. Optional so tests and
  /// headless contexts without a documents directory simply skip reclamation.
  final AgentSidecarReclaimer? sidecarReclaimer;
  final void Function(String agentId)? onPersistedStateChanged;

  static const _uuid = Uuid();

  /// Create a new agent with the given [kind], [displayName], and [config].
  ///
  /// This method:
  /// 1. Creates the [AgentIdentityEntity] with lifecycle = [AgentLifecycle.active].
  /// 2. Creates an initial [AgentStateEntity] with revision 0.
  /// 3. Links the agent to its state via an [AgentStateLink].
  ///
  /// When [agentId] is provided, the identity, state, and link ids are all
  /// derived deterministically from it. Singleton identities (e.g. the Daily
  /// OS planner, ADR 0022) use this so concurrent creation on different
  /// devices writes byte-identical entity ids and converges via LWW instead
  /// of producing duplicates. When omitted, fresh UUIDs are minted.
  ///
  /// Returns the [AgentIdentityEntity].
  Future<AgentIdentityEntity> createAgent({
    required String kind,
    required String displayName,
    required AgentConfig config,
    Set<String> allowedCategoryIds = const {},
    String? agentId,
  }) async {
    final resolvedAgentId = agentId ?? _uuid.v4();
    final stateId = agentId != null ? '$agentId:state' : _uuid.v4();
    final linkId = agentId != null ? '$agentId:state-link' : _uuid.v4();
    final now = clock.now();

    final identity =
        AgentDomainEntity.agent(
              id: resolvedAgentId,
              agentId: resolvedAgentId,
              kind: kind,
              displayName: displayName,
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: allowedCategoryIds,
              currentStateId: stateId,
              config: config,
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            )
            as AgentIdentityEntity;

    final state =
        AgentDomainEntity.agentState(
              id: stateId,
              agentId: resolvedAgentId,
              slots: const AgentSlots(),
              updatedAt: now,
              vectorClock: null,
            )
            as AgentStateEntity;

    final link = AgentLink.agentState(
      id: linkId,
      fromId: resolvedAgentId,
      toId: stateId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(identity);
      await syncService.upsertEntity(state);
      await syncService.upsertLink(link);
    });

    developer.log(
      'Created agent ${DomainLogger.sanitizeId(resolvedAgentId)} '
      '(kind: $kind)',
      name: 'AgentService',
    );

    return identity;
  }

  /// Fetch a single agent identity by [agentId], or `null` if not found.
  Future<AgentIdentityEntity?> getAgent(String agentId) async {
    final entity = await repository.getEntity(agentId);
    return entity?.mapOrNull(agent: (e) => e);
  }

  /// List all agents, optionally filtered by [lifecycle] state.
  Future<List<AgentIdentityEntity>> listAgents({
    AgentLifecycle? lifecycle,
  }) async {
    if (lifecycle != null) {
      return repository.getAgentIdentitiesByLifecycle(lifecycle);
    }
    return repository.getAllAgentIdentities();
  }

  /// Get the latest report for [agentId] in [scope]
  /// (defaults to [AgentReportScopes.current]).
  Future<AgentReportEntity?> getAgentReport(
    String agentId, [
    String scope = AgentReportScopes.current,
  ]) async {
    return repository.getLatestReport(agentId, scope);
  }

  /// Clear a pending deferred wake for [agentId].
  ///
  /// Removes any persisted/local throttle deadline and drops queued wake jobs
  /// for the same agent from the in-memory wake queue.
  void cancelPendingWake(String agentId) {
    orchestrator
      ..clearThrottle(agentId)
      // Cancel-all: drop every queued job for the agent across all workspaces.
      ..cancelPendingWakes(agentId, allWorkspaces: true);
  }

  /// Abort the in-flight wake for [agentId], if any.
  ///
  /// Returns `true` when an active run was signalled to abort. The runner
  /// lock is released by the orchestrator after the abort is observed and
  /// the wake-run row is marked `aborted`.
  bool abortRunningWake(String agentId) =>
      orchestrator.abortRunningWake(agentId);

  /// Waits for executor work that may outlive an abort signal.
  Future<void> waitForAgentExecutors(String agentId) =>
      orchestrator.waitForAgentExecutors(agentId);

  /// Marks the standing report stale without scheduling inference.
  Future<void> markReportStale(String agentId) =>
      orchestrator.markReportStale(agentId);

  /// Remove a persisted scheduled wake from the agent state.
  Future<void> clearScheduledWake(String agentId) async {
    final state = await repository.getAgentState(agentId);
    if (state == null || state.scheduledWakeAt == null) {
      return;
    }

    await syncService.upsertEntity(
      state.copyWith(
        scheduledWakeAt: null,
        updatedAt: clock.now(),
      ),
    );
    onPersistedStateChanged?.call(agentId);
  }

  /// Dismiss a workspace-scoped scheduled-wake record so it neither fires nor
  /// re-surfaces in the pending list.
  ///
  /// [clearScheduledWake] cannot remove these: a planner day pre-warm lives as
  /// its own [ScheduledWakeEntity], not on `AgentState.scheduledWakeAt`. So the
  /// cancel button on such a row must both (a) drop any job already queued for
  /// the record's workspace and (b) consume the record — otherwise the
  /// scheduled-wake manager re-fires it from the still-pending row on the next
  /// scan, which is exactly why the button appeared to do nothing.
  ///
  /// The record is flipped to [ScheduledWakeStatus.consumed] rather than
  /// hard-deleted so a peer's concurrent write converges via LWW instead of
  /// resurrecting the row. A record already consumed (or raced away) needs only
  /// the queue drop.
  Future<void> dismissScheduledWakeRecord({
    required String recordId,
    required String agentId,
    String? workspaceKey,
  }) async {
    // Drop the job already dequeued for this workspace so an in-flight burst
    // stops now, not only on future scans.
    orchestrator.cancelPendingWakes(agentId, workspaceKey: workspaceKey);

    final entity = await repository.getEntity(recordId);
    if (entity is ScheduledWakeEntity &&
        entity.status == ScheduledWakeStatus.pending) {
      final now = clock.now();
      await syncService.upsertEntity(
        entity.copyWith(
          status: ScheduledWakeStatus.consumed,
          consumedAt: now,
          updatedAt: now,
        ),
      );
    }
    onPersistedStateChanged?.call(agentId);
  }

  /// Transition agent to [AgentLifecycle.dormant], unregister wake
  /// subscriptions, and remove any device-local project fallback.
  ///
  /// [byUser] marks the pause as the user's own stop (the agent controls):
  /// it is recorded on the identity and synced, so no other device's write
  /// undoes it (ADR 0111).
  ///
  /// Returns `true` if the agent was found and paused, `false` if the agent
  /// does not exist.
  Future<bool> pauseAgent(String agentId, {bool byUser = false}) async {
    final updated = await _updateLifecycle(
      agentId,
      AgentLifecycle.dormant,
      decision: byUser ? _UserDecision.stop : null,
    );
    if (!updated) return false;
    orchestrator.removeSubscriptions(agentId);
    developer.log(
      'Paused agent ${DomainLogger.sanitizeId(agentId)}',
      name: 'AgentService',
    );
    return true;
  }

  /// Transition agent to [AgentLifecycle.active].
  ///
  /// The caller is responsible for re-registering subscriptions after this
  /// call (subscription details are agent-kind-specific); the agent controls
  /// do so through the task service and the runtime-maintenance contributors.
  ///
  /// [byUser] marks the resume as the user's own (the agent controls): it
  /// is recorded on the identity and outranks an older stop (ADR 0111).
  ///
  /// Returns `true` if the agent was found and resumed, `false` if the agent
  /// does not exist.
  Future<bool> resumeAgent(String agentId, {bool byUser = false}) async {
    final updated = await _updateLifecycle(
      agentId,
      AgentLifecycle.active,
      decision: byUser ? _UserDecision.resume : null,
    );
    if (!updated) return false;
    developer.log(
      'Resumed agent ${DomainLogger.sanitizeId(agentId)}',
      name: 'AgentService',
    );
    return true;
  }

  /// Restores an agent to an exact lifecycle captured before a reversible
  /// operation.
  ///
  /// This is deliberately separate from [resumeAgent]: rollback must not turn
  /// a previously dormant or not-yet-activated agent into an active one. The
  /// caller remains responsible for re-registering subscriptions when
  /// [lifecycle] is [AgentLifecycle.active]. Non-active states remove any
  /// subscriptions left by the interrupted operation.
  Future<bool> restoreAgentLifecycle(
    String agentId,
    AgentLifecycle lifecycle,
  ) async {
    final updated = await _updateLifecycle(agentId, lifecycle);
    if (!updated) return false;
    if (lifecycle != AgentLifecycle.active) {
      orchestrator.removeSubscriptions(agentId);
    }
    developer.log(
      'Restored agent ${DomainLogger.sanitizeId(agentId)} to ${lifecycle.name}',
      name: 'AgentService',
    );
    return true;
  }

  /// Transition agent to [AgentLifecycle.destroyed] and unregister
  /// wake subscriptions.
  ///
  /// Does not delete data — the agent's history is preserved for audit.
  /// To permanently remove all data, call [deleteAgent] afterwards.
  ///
  /// [byUser] marks the destroy as the user's own stop (the agent controls),
  /// as opposed to a teardown the app decided — a deleted person, a retired
  /// task agent. Only the user's stop keeps an agent the user still asks for
  /// destroyed (ADR 0111).
  ///
  /// Returns `true` if the agent was found and destroyed, `false` if the
  /// agent does not exist.
  Future<bool> destroyAgent(String agentId, {bool byUser = false}) async {
    final updated = await _updateLifecycle(
      agentId,
      AgentLifecycle.destroyed,
      decision: byUser ? _UserDecision.stop : null,
    );
    if (!updated) return false;
    orchestrator.removeSubscriptions(agentId);
    developer.log(
      'Destroyed agent ${DomainLogger.sanitizeId(agentId)}',
      name: 'AgentService',
    );
    return true;
  }

  /// Permanently delete all data for a **destroyed** agent.
  ///
  /// Hard-delete is local-only and is NOT propagated via sync.
  /// Cross-device deletion is achieved via the [destroyAgent] lifecycle
  /// transition, which syncs the `destroyed` lifecycle to all devices.
  ///
  /// Destroys the agent first if it is not already destroyed, then hard-deletes
  /// all entities, links, wake runs, and saga ops from the database. Linked
  /// project IDs are captured first so project detail/list providers can drop
  /// agent-authored summaries after the link rows disappear.
  ///
  /// [byUser] marks the delete as the user's stop. It is written and synced
  /// before the rows go, even over an agent already destroyed: the delete
  /// itself stays on this device, and without the stop another device could
  /// bring the agent back (ADR 0111).
  Future<void> deleteAgent(String agentId, {bool byUser = false}) async {
    final identity = await getAgent(agentId);
    final projectIds = identity?.kind == AgentKinds.projectAgent
        ? (await repository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentProject,
          )).map((link) => link.toId).toSet()
        : const <String>{};
    if (identity != null &&
        (byUser || identity.lifecycle != AgentLifecycle.destroyed)) {
      await destroyAgent(agentId, byUser: byUser);
    } else {
      orchestrator.removeSubscriptions(agentId);
    }

    final removed = await repository.hardDeleteAgent(agentId);
    // The rows are only half of what a synced agent leaves behind: its JSON
    // sidecars stay readable on disk otherwise, outliving the delete the user
    // just asked for.
    await sidecarReclaimer?.reclaim(
      entityIds: removed.entityIds,
      linkIds: removed.linkIds,
    );
    final notifyPersistedStateChanged = onPersistedStateChanged;
    if (projectIds.isNotEmpty && notifyPersistedStateChanged != null) {
      notifyPersistedStateChanged(AgentNotificationScopes.projectOverview);
      projectIds.forEach(notifyPersistedStateChanged);
    }
    developer.log(
      'Deleted all data for agent ${DomainLogger.sanitizeId(agentId)}',
      name: 'AgentService',
    );
  }

  /// Returns `true` when the agent was found and its lifecycle was updated,
  /// `false` when the agent does not exist.
  ///
  /// The write stamps `lifecycleUpdatedAt`, so this decision outranks any
  /// earlier one in the identity merge; a [decision] also records the
  /// user's stop or resume (ADR 0111).
  Future<bool> _updateLifecycle(
    String agentId,
    AgentLifecycle lifecycle, {
    _UserDecision? decision,
  }) async {
    final updated = await syncService.runInTransaction(() async {
      final identity = await getAgent(agentId);
      if (identity == null) {
        developer.log(
          'Cannot update lifecycle: agent '
          '${DomainLogger.sanitizeId(agentId)} not found',
          name: 'AgentService',
        );
        return false;
      }

      final now = clock.now();
      final stops = decision == _UserDecision.stop;
      final updated = identity.copyWith(
        lifecycle: lifecycle,
        updatedAt: now,
        lifecycleUpdatedAt: now,
        destroyedAt: lifecycle != AgentLifecycle.destroyed
            ? null
            : identity.lifecycle == AgentLifecycle.destroyed
            ? identity.destroyedAt ?? now
            : now,
        userStoppedAt: stops ? now : identity.userStoppedAt,
        userStopLifecycle: stops ? lifecycle : identity.userStopLifecycle,
        userResumedAt: decision == _UserDecision.resume
            ? now
            : identity.userResumedAt,
      );
      await syncService.upsertEntity(updated);
      if (identity.kind == AgentKinds.projectAgent &&
          lifecycle != AgentLifecycle.active) {
        final state = await repository.getAgentState(agentId);
        if (state != null && state.scheduledWakeAt != null) {
          // Project fallback deadlines are device-local. Clear them in the
          // same database transaction without advancing synced LWW metadata.
          await repository.upsertEntity(
            state.copyWith(scheduledWakeAt: null),
          );
        }
      }
      return true;
    });
    // Pause/resume/destroy must reach every agent surface: the goal
    // overview and banner providers watch the agent notification, and a
    // sync-service write alone emits nothing.
    if (updated) onPersistedStateChanged?.call(agentId);
    return updated;
  }
}

/// A lifecycle change the user made in the agent controls, as opposed to one
/// the app made on its own.
enum _UserDecision { stop, resume }
