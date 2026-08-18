import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:lotti/features/goals/service/goal_mirror_service.dart';
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
    required this._goalChatService,
    this._goalMirrorService,
    this._checkInNotifier,
    this._domainLogger,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalAgentService _goalAgentService;
  final GoalChatService _goalChatService;

  /// Repairs the journal-side goal on every launch. Optional so the runtime
  /// keeps working without it.
  final GoalMirrorService? _goalMirrorService;

  /// Marks a goal's report stale when the user checks in. Optional for the
  /// same reason the mirror is.
  final GoalCheckInNotifier? _checkInNotifier;
  final DomainLogger? _domainLogger;

  @override
  Future<void> restoreSubscriptions() async {
    // The backfill runs over EVERY goal, including paused and archived ones:
    // subscriptions are only for active goals, but the durable journal row is
    // for all of them. Repairing only what is subscribed would permanently
    // strand the goals a restore is most likely to lose.
    await _backfillJournalGoals();

    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeGoalAgents();
    } catch (error, stackTrace) {
      _log('restoreSubscriptions', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        // Recovery is independent of the goal specification. A damaged or
        // temporarily unavailable head must not leave a durable user message
        // unanswered until some unrelated future wake happens to arrive.
        await _goalChatService.restoreOldestPendingMessage(identity.agentId);
        final criteria = await _headCriteria(identity.agentId);
        if (criteria == null) continue;
        _goalAgentService
          ..registerSignalSubscription(
            identity.agentId,
            criteria,
          )
          ..restorePendingReportRefresh(
            identity: identity,
            state: await _repository.getAgentState(identity.agentId),
          );
      } catch (error, stackTrace) {
        _log('restoreSubscriptions', identity.agentId, error, stackTrace);
      }
    }
    // One subscription for every active goal, resolved once rather than
    // re-queried per journal notification.
    _checkInNotifier?.start(agents.map((identity) => identity.agentId));
  }

  @override
  Future<void> beforeWakeScan() async {
    final now = clock.now();
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeGoalAgents();
    } catch (error, stackTrace) {
      _log('beforeWakeScan', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
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
        await _goalChatService.restoreOldestPendingMessage(identity.agentId);
      } catch (error, stackTrace) {
        _log('beforeWakeScan', identity.agentId, error, stackTrace);
      }
    }
  }

  /// Gives every goal — whatever its lifecycle — its journal-side row.
  ///
  /// Goals that predate the entity get one, and any goal whose mirror failed
  /// to write is repaired. The ids are derived, so several devices running
  /// this against the same synced goal converge on one row rather than each
  /// minting their own.
  Future<void> _backfillJournalGoals() async {
    final mirror = _goalMirrorService;
    if (mirror == null) return;
    final List<AgentIdentityEntity> agents;
    try {
      agents = (await _agentService.listAgents())
          .where((agent) => agent.kind == AgentKinds.goalAgent)
          .toList(growable: false);
    } catch (error, stackTrace) {
      _log('backfillJournalGoals', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        await mirror.mirrorHead(identity.agentId);
      } catch (error, stackTrace) {
        _log('backfillJournalGoals', identity.agentId, error, stackTrace);
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

  /// Mirrors a synced-in goal identity into the runtime mid-session: an
  /// active goal subscribes to its signals immediately (previously it was
  /// deaf until restart — the documented PR 2 limitation), a paused or
  /// archived one is unsubscribed. Failures are contained: the sync apply
  /// loop must never stall on one goal's bad spec.
  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    if (identity.kind != AgentKinds.goalAgent) return;
    try {
      // Mirroring comes FIRST, before the lifecycle gate. A paused or
      // archived goal is still a goal the user wrote, and it is exactly the
      // one a restore without the agent database would lose — gating the
      // mirror on "should this be subscribed" would leave those goals with no
      // durable row until someone happened to reactivate them.
      await _goalMirrorService?.mirrorHead(identity.agentId);

      if (identity.lifecycle != AgentLifecycle.active) {
        _goalAgentService.removeSignalSubscriptions(identity.agentId);
        _checkInNotifier?.unwatch(identity.agentId);
        return;
      }
      // Before the criteria gate: a synced identity can arrive ahead of its
      // spec head, and returning for want of criteria left the goal unwatched
      // until a restart — reintroducing the startup-snapshot bug by placement
      // rather than by logic. Watching needs only the agent id.
      _checkInNotifier?.watch(identity.agentId);
      await _goalChatService.restoreOldestPendingMessage(identity.agentId);

      final criteria = await _headCriteria(identity.agentId);
      if (criteria == null) return;
      _goalAgentService.registerSignalSubscription(
        identity.agentId,
        criteria,
      );
    } catch (error, stackTrace) {
      _log('onIdentityReceived', identity.agentId, error, stackTrace);
    }
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
