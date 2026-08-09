import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Startup and pre-scan maintenance for goal agents (the
/// [AgentRuntimeMaintenance] contract): subscriptions are in-memory and
/// must be rebuilt every launch; cadence wakes are re-armed by each run
/// but self-healed here in case the last run died before re-arming.
///
/// Every per-agent repair is individually contained — one broken goal must
/// never take the others (or another feature's maintenance) down with it.
class GoalRuntimeMaintenance implements AgentRuntimeMaintenance {
  GoalRuntimeMaintenance({
    required this._agentService,
    required this._repository,
    required this._syncService,
    required this._goalAgentService,
    this._domainLogger,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalAgentService _goalAgentService;
  final DomainLogger? _domainLogger;

  @override
  Future<void> restoreSubscriptions() async {
    for (final identity in await _activeGoalAgents()) {
      try {
        final criteria = await _headCriteria(identity.agentId);
        if (criteria == null) continue;
        _goalAgentService.registerSignalSubscription(
          identity.agentId,
          criteria,
        );
      } catch (error, stackTrace) {
        _log('restoreSubscriptions', identity.agentId, error, stackTrace);
      }
    }
  }

  @override
  Future<void> beforeWakeScan() async {
    final now = clock.now();
    for (final identity in await _activeGoalAgents()) {
      try {
        final record = await _repository.getEntity(
          scheduledWakeRecordId(
            identity.agentId,
            workspaceKey: goalCadenceWorkspaceKey,
          ),
        );
        final needsHeal =
            record is! ScheduledWakeEntity ||
            (record.status == ScheduledWakeStatus.consumed &&
                record.scheduledAt.isBefore(now));
        if (needsHeal) {
          await _syncService.upsertEntity(
            goalCadenceWake(identity.agentId, now),
          );
        }
      } catch (error, stackTrace) {
        _log('beforeWakeScan', identity.agentId, error, stackTrace);
      }
    }
  }

  Future<List<AgentIdentityEntity>> _activeGoalAgents() async {
    final agents = await _agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );
    return agents
        .where((agent) => agent.kind == AgentKinds.goalAgent)
        .toList(growable: false);
  }

  Future<GoalCriterion?> _headCriteria(String agentId) async {
    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) return null;
    final version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) return null;
    return version.criteria;
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
      message: 'goal runtime maintenance $phase failed for one agent',
      stackTrace: stackTrace,
    );
  }
}
