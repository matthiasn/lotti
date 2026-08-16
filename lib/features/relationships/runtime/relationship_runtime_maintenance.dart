import 'package:clock/clock.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Startup and pre-scan maintenance for relationship agents (the
/// [AgentRuntimeMaintenance] contract, the goal-runtime shape):
/// subscriptions are in-memory and must be rebuilt every launch; cadence
/// wakes are re-armed by each run but self-healed here in case the last
/// run died before re-arming.
///
/// Every per-agent repair is individually contained — one broken
/// relationship must never take the others (or another feature's
/// maintenance) down with it.
class RelationshipRuntimeMaintenance implements AgentRuntimeMaintenance {
  RelationshipRuntimeMaintenance({
    required this._agentService,
    required this._repository,
    required this._syncService,
    required this._relationshipAgentService,
    this._domainLogger,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final RelationshipAgentService _relationshipAgentService;
  final DomainLogger? _domainLogger;

  @override
  Future<void> restoreSubscriptions() async {
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeRelationshipAgents();
    } catch (error, stackTrace) {
      _log('restoreSubscriptions', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        await _relationshipAgentService.registerSubscription(identity.agentId);
      } catch (error, stackTrace) {
        _log('restoreSubscriptions', identity.agentId, error, stackTrace);
      }
    }
  }

  @override
  Future<void> beforeWakeScan() async {
    final now = clock.now();
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeRelationshipAgents();
    } catch (error, stackTrace) {
      _log('beforeWakeScan', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        final record = await _repository.getEntity(
          scheduledWakeRecordId(
            identity.agentId,
            workspaceKey: relationshipCadenceWorkspaceKey,
          ),
        );
        final needsHeal =
            record is! ScheduledWakeEntity ||
            (record.status == ScheduledWakeStatus.consumed &&
                record.scheduledAt.isBefore(now));
        if (needsHeal) {
          await _syncService.upsertEntity(
            relationshipCadenceWake(identity.agentId, now),
          );
        }
      } catch (error, stackTrace) {
        _log('beforeWakeScan', identity.agentId, error, stackTrace);
      }
    }
  }

  /// Mirrors a synced-in relationship-agent identity into the runtime
  /// mid-session: an active one subscribes to its relationship immediately,
  /// a paused or destroyed one is unsubscribed. Failures are contained: the
  /// sync apply loop must never stall on one agent.
  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    if (identity.kind != AgentKinds.relationshipAgent) return;
    try {
      if (identity.lifecycle != AgentLifecycle.active) {
        _relationshipAgentService.removeSubscription(identity.agentId);
        return;
      }
      await _relationshipAgentService.registerSubscription(identity.agentId);
    } catch (error, stackTrace) {
      _log('onIdentityReceived', identity.agentId, error, stackTrace);
    }
  }

  Future<List<AgentIdentityEntity>> _activeRelationshipAgents() async {
    final agents = await _agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );
    return agents
        .where((agent) => agent.kind == AgentKinds.relationshipAgent)
        .toList(growable: false);
  }

  void _log(
    String phase,
    String agentId,
    Object error,
    StackTrace stackTrace,
  ) {
    _domainLogger?.error(
      LogDomain.agentRuntime,
      error,
      message: 'relationship runtime maintenance $phase failed for one agent',
      stackTrace: stackTrace,
    );
  }
}
