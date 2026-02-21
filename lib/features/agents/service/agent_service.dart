import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:uuid/uuid.dart';

/// High-level agent lifecycle management.
///
/// Provides operations for creating, listing, pausing, resuming, and destroying
/// agents. Each mutation persists to [AgentRepository] and, where relevant,
/// updates the [WakeOrchestrator]'s subscription state so that wake triggers
/// are registered or withdrawn immediately.
class AgentService {
  AgentService({
    required this.repository,
    required this.orchestrator,
  });

  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  static const _uuid = Uuid();

  /// Create a new agent with the given [kind], [displayName], and [config].
  ///
  /// This method:
  /// 1. Creates the [AgentIdentityEntity] with lifecycle = [AgentLifecycle.active].
  /// 2. Creates an initial [AgentStateEntity] with revision 0.
  /// 3. Links the agent to its state via an [AgentStateLink].
  ///
  /// Returns the [AgentIdentityEntity].
  Future<AgentIdentityEntity> createAgent({
    required String kind,
    required String displayName,
    required AgentConfig config,
    Set<String> allowedCategoryIds = const {},
  }) async {
    final agentId = _uuid.v4();
    final stateId = _uuid.v4();
    final linkId = _uuid.v4();
    final now = clock.now();

    final identity = AgentDomainEntity.agent(
      id: agentId,
      agentId: agentId,
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
    ) as AgentIdentityEntity;

    final state = AgentDomainEntity.agentState(
      id: stateId,
      agentId: agentId,
      revision: 0,
      slots: const AgentSlots(),
      updatedAt: now,
      vectorClock: null,
    ) as AgentStateEntity;

    final link = AgentLink.agentState(
      id: linkId,
      fromId: agentId,
      toId: stateId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );

    await repository.runInTransaction(() async {
      await repository.upsertEntity(identity);
      await repository.upsertEntity(state);
      await repository.upsertLink(link);
    });

    developer.log(
      'Created agent $agentId (kind: $kind, name: $displayName)',
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
    final agents = await repository.getAllAgentIdentities();
    if (lifecycle != null) {
      return agents.where((a) => a.lifecycle == lifecycle).toList();
    }
    return agents;
  }

  /// Get the latest report for [agentId] in [scope] (defaults to 'current').
  Future<AgentReportEntity?> getAgentReport(
    String agentId, [
    String scope = 'current',
  ]) async {
    return repository.getLatestReport(agentId, scope);
  }

  /// Transition agent to [AgentLifecycle.dormant] and unregister
  /// wake subscriptions.
  Future<void> pauseAgent(String agentId) async {
    await _updateLifecycle(agentId, AgentLifecycle.dormant);
    orchestrator.removeSubscriptions(agentId);
    developer.log('Paused agent $agentId', name: 'AgentService');
  }

  /// Transition agent to [AgentLifecycle.active].
  ///
  /// The caller is responsible for re-registering subscriptions after this
  /// call (subscription details are agent-kind-specific).
  Future<void> resumeAgent(String agentId) async {
    await _updateLifecycle(agentId, AgentLifecycle.active);
    developer.log('Resumed agent $agentId', name: 'AgentService');
  }

  /// Transition agent to [AgentLifecycle.destroyed] and unregister
  /// wake subscriptions.
  ///
  /// Does not delete data — the agent's history is preserved for audit.
  /// To permanently remove all data, call [deleteAgent] afterwards.
  Future<void> destroyAgent(String agentId) async {
    await _updateLifecycle(agentId, AgentLifecycle.destroyed);
    orchestrator.removeSubscriptions(agentId);
    developer.log('Destroyed agent $agentId', name: 'AgentService');
  }

  /// Permanently delete all data for a **destroyed** agent.
  ///
  /// Destroys the agent first if it is not already destroyed, then hard-deletes
  /// all entities, links, wake runs, and saga ops from the database.
  Future<void> deleteAgent(String agentId) async {
    final identity = await getAgent(agentId);
    if (identity != null && identity.lifecycle != AgentLifecycle.destroyed) {
      await destroyAgent(agentId);
    } else {
      orchestrator.removeSubscriptions(agentId);
    }

    await repository.hardDeleteAgent(agentId);
    developer.log('Deleted all data for agent $agentId', name: 'AgentService');
  }

  Future<void> _updateLifecycle(
    String agentId,
    AgentLifecycle lifecycle,
  ) async {
    final identity = await getAgent(agentId);
    if (identity == null) {
      developer.log(
        'Cannot update lifecycle: agent $agentId not found',
        name: 'AgentService',
      );
      return;
    }

    final now = clock.now();
    final updated = identity.copyWith(
      lifecycle: lifecycle,
      updatedAt: now,
      destroyedAt: lifecycle == AgentLifecycle.destroyed ? now : null,
    );
    await repository.upsertEntity(updated);
  }
}
