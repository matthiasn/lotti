import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';

/// Creates and wires goal agents (ADR 0053: one durable identity per goal).
///
/// Creation is the only write path for a v1 goal spec: the criteria tree is
/// validated before anything is persisted, the initial `goalSpecVersion` +
/// `goalSpecHead` land in one transaction with the identity, and the agent
/// leaves this method live — subscribed to its signals and armed with its
/// first cadence tick.
class GoalAgentService {
  GoalAgentService({
    required this._agentService,
    required this._syncService,
    required this._orchestrator,
  });

  final AgentService _agentService;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;

  /// Creates a goal agent with its v1 spec.
  ///
  /// Throws [ArgumentError] when [criteria] fails structural validation —
  /// an unsatisfiable or corrupt goal must not exist even for a moment.
  Future<AgentIdentityEntity> createGoalAgent({
    required String title,
    required String statement,
    required GoalCriterion criteria,
    DateTime? startDate,
    DateTime? targetDate,
    String? rationale,
    String? agentId,
  }) async {
    final issues = GoalSpecValidator.criterionIssues(criteria);
    if (issues.isNotEmpty) {
      throw ArgumentError('Invalid goal criteria: ${issues.join('; ')}');
    }

    final identity = await _agentService.createAgent(
      kind: AgentKinds.goalAgent,
      displayName: title,
      config: const AgentConfig(),
      agentId: agentId,
    );
    final now = clock.now();
    final versionId = '${identity.agentId}:spec-v1';

    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        AgentDomainEntity.goalSpecVersion(
          id: versionId,
          agentId: identity.agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: title,
          statement: statement,
          criteria: criteria,
          createdAt: now,
          vectorClock: null,
          startDate: startDate,
          targetDate: targetDate,
          rationale: rationale,
        ),
      );
      await _syncService.upsertEntity(
        AgentDomainEntity.goalSpecHead(
          id: goalSpecHeadId(identity.agentId),
          agentId: identity.agentId,
          versionId: versionId,
          updatedAt: now,
          vectorClock: null,
        ),
      );
      // First cadence tick — recurrence by re-arm starts here.
      await _syncService.upsertEntity(
        goalCadenceWake(identity.agentId, now),
      );
    });

    registerSignalSubscription(identity.agentId, criteria);
    return identity;
  }

  /// Evidence-triggered wakes: the goal agent listens to exactly the
  /// signals its criteria reference — leaf dataTypes, habitIds and
  /// measurable ids — never a global sentinel.
  void registerSignalSubscription(String agentId, GoalCriterion criteria) {
    _orchestrator.addSubscription(
      AgentSubscription(
        id: goalSignalSubscriptionId(agentId),
        agentId: agentId,
        matchEntityIds: goalSignalTriggerTokens(criteria),
        deferPropagatedMatches: false,
      ),
    );
  }
}

/// Stable subscription id, so repeated `restoreSubscriptions` replace
/// instead of accumulate.
String goalSignalSubscriptionId(String agentId) => '${agentId}_goal_signals';
