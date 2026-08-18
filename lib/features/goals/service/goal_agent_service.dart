import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:lotti/features/goals/service/goal_mirror_service.dart';
import 'package:lotti/services/db_notification.dart';

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
    required this._repository,
    required this._syncService,
    required this._orchestrator,
    this.updateNotifications,
    this.goalMirrorService,
    this.checkInNotifier,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;

  /// Post-commit UI ping. Identity writes reach the database through the sync
  /// service, which does not notify on its own — the wake path pings
  /// separately — so a user-initiated config change would otherwise leave
  /// every mounted watcher of `agentIdentityProvider` rendering the old value
  /// until the page is rebuilt from scratch.
  final UpdateNotifications? updateNotifications;

  /// Mirrors the goal into the journal. Optional so the agent tier keeps
  /// working — and stays testable — without it; a goal whose mirror is missing
  /// is repaired by the startup backfill.
  final GoalMirrorService? goalMirrorService;

  /// Watches a new goal for check-ins. Optional for the same reason.
  final GoalCheckInNotifier? checkInNotifier;

  /// Creates a goal agent with its v1 spec — identity, state, spec
  /// version, head and first cadence tick in ONE transaction (nested
  /// `runInTransaction` calls join the outer one), so a failure anywhere
  /// leaves no orphaned half-goal behind.
  ///
  /// Throws [ArgumentError] when [criteria] fails structural validation,
  /// and [StateError] when a goal already exists for a caller-supplied
  /// [agentId] — spec v1 is immutable and must never be rewritten by a
  /// repeated create.
  Future<AgentIdentityEntity> createGoalAgent({
    required String title,
    required String statement,
    required GoalCriterion criteria,
    String? displayName,
    DateTime? startDate,
    DateTime? targetDate,
    String? rationale,
    String? agentId,
  }) async {
    final issues = GoalSpecValidator.criterionIssues(criteria);
    if (issues.isNotEmpty) {
      throw ArgumentError('Invalid goal criteria: ${issues.join('; ')}');
    }
    final now = clock.now();
    AgentIdentityEntity? created;
    AgentIdentityEntity identity;
    try {
      identity = await _syncService.runInTransaction(() async {
        // Inside the transaction, not a preflight: two concurrent creates
        // for the same caller-supplied id must serialize here, so the loser
        // sees the winner's head and cannot rewrite the immutable spec v1.
        if (agentId != null &&
            await _repository.getEntity(goalSpecHeadId(agentId)) != null) {
          throw StateError(
            'goal $agentId already exists; spec v1 is immutable — revise via '
            'a new version, never a repeated create',
          );
        }
        final identity = await _agentService.createAgent(
          kind: AgentKinds.goalAgent,
          displayName: displayName?.trim().isNotEmpty ?? false
              ? displayName!.trim()
              : title,
          config: const AgentConfig(automaticUpdatesEnabled: true),
          agentId: agentId,
        );
        final versionId = '${identity.agentId}:spec-v1';
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
        created = identity;
        return identity;
      });
    } catch (error) {
      // The database transaction can be durable even when a deferred
      // post-commit step (the sync outbox flush) rethrows. If this
      // call's goal is already persisted, reporting failure would
      // re-enable the Create button and a retry would mint a DUPLICATE
      // agent under a fresh random id. A failure BEFORE the writes
      // finished leaves nothing to reconcile.
      final finished = created;
      if (finished == null) rethrow;
      final head = await _repository.getEntity(
        goalSpecHeadId(finished.agentId),
      );
      if (head is! GoalSpecHeadEntity) rethrow;
      final version = await _repository.getEntity(head.versionId);
      if (version is GoalSpecVersionEntity && version.createdAt == now) {
        identity = finished;
      } else {
        rethrow;
      }
    }

    registerSignalSubscription(identity.agentId, criteria);
    // A goal created while the app is open needs its check-in watch now; the
    // startup sweep is too late for the check-in the user is about to record.
    checkInNotifier?.watch(identity.agentId);
    // One immediate deterministic evaluation: a goal created after the
    // cadence hour would otherwise show no register or health for up to
    // a day if its signals never change (the subscription only fires on
    // NEW writes). Phase A over existing journal data is €0.
    _orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: 'goal created',
    );
    // Journal-first in intent, last in order: the agent transaction above is
    // what must not be half-written. Mirroring is a separate, idempotent
    // write, so a failure here leaves a working goal that the next launch's
    // backfill repairs rather than an orphaned agent.
    final head = await _repository.getEntity(goalSpecHeadId(identity.agentId));
    if (head is GoalSpecHeadEntity) {
      final version = await _repository.getEntity(head.versionId);
      if (version is GoalSpecVersionEntity) {
        await goalMirrorService?.mirrorSpec(version: version);
      }
    }
    return identity;
  }

  /// Retires a goal agent through the shared synced lifecycle transition.
  /// Owned goal rows stay available for audit, while the destroyed identity
  /// disappears from active surfaces and no longer receives wake signals.
  Future<bool> deleteGoalAgent(String agentId) async {
    final destroyed = await _agentService.destroyAgent(agentId);
    if (!destroyed) return false;
    _agentService
      ..cancelPendingWake(agentId)
      ..abortRunningWake(agentId);
    removeSignalSubscriptions(agentId);
    return true;
  }

  /// Drops the agent's runtime subscriptions (paused/archived goals must
  /// stop waking on signals; a re-activation re-registers).
  void removeSignalSubscriptions(String agentId) =>
      _orchestrator.removeSubscriptions(agentId);

  /// Goal agents shipped with automatic report refreshes before the setting
  /// was persisted. Preserve that behavior for legacy null configs while new
  /// identities and every user edit write an explicit value.
  static bool automaticUpdatesEnabled(AgentIdentityEntity identity) =>
      identity.config.automaticUpdatesEnabled ?? true;

  /// Queue one report refresh behind the shared two-minute agent countdown.
  ///
  /// The local wake only runs deterministic Phase A. Phase A then writes the
  /// period-scoped synced wake whose lease elects exactly one inference device.
  Future<void> scheduleAutomaticReportRefresh(String agentId) async {
    final entity = await _repository.getEntity(agentId);
    if (entity is! AgentIdentityEntity ||
        entity.lifecycle != AgentLifecycle.active ||
        !automaticUpdatesEnabled(entity)) {
      return;
    }
    await _orchestrator.enqueueDeferredAutomaticWake(
      agentId: agentId,
      reason: WakeReason.subscription.name,
      triggerTokens: const {goalDeferredReportRefreshTriggerToken},
      workspaceKey: goalReportRefreshTriggerToken,
    );
  }

  /// Enable or disable coalesced automatic standing-report refreshes.
  ///
  /// Deterministic progress subscriptions stay live in both states. Turning
  /// automation off only removes the pending inference arm; evidence can keep
  /// updating the goal and marking its report stale. Turning it back on queues
  /// one catch-up refresh when no current report exists or the report is stale.
  Future<void> updateAutomaticUpdates({
    required String agentId,
    required bool enabled,
  }) async {
    var catchUpNeeded = false;
    await _syncService.runInTransaction(() async {
      final current = await _repository.getEntity(agentId);
      if (current is! AgentIdentityEntity ||
          current.kind != AgentKinds.goalAgent) {
        throw StateError('Goal agent $agentId not found');
      }
      final now = clock.now();
      await _syncService.upsertEntity(
        current.copyWith(
          config: current.config.copyWith(
            automaticUpdatesEnabled: enabled,
          ),
          updatedAt: now,
        ),
      );
      if (enabled) {
        final state = await _repository.getAgentState(agentId);
        catchUpNeeded =
            state == null || state.reportFreshAt == null || state.isReportStale;
      }
    });

    // The toggle is a user-visible state change: ping before the catch-up
    // refresh is scheduled so the switch settles immediately rather than
    // waiting on wake work.
    updateNotifications?.notifyUiOnly({agentId, agentNotification});

    if (!enabled) {
      skipPendingReportRefresh(agentId);
    } else if (catchUpNeeded) {
      await scheduleAutomaticReportRefresh(agentId);
    }
  }

  /// Restores the goal-specific deferred arm after restart. The trigger token
  /// is essential: a generic empty-token restore would only recompute Phase A
  /// and never advance to the lease-elected report refresh.
  void restorePendingReportRefresh({
    required AgentIdentityEntity identity,
    required AgentStateEntity? state,
  }) {
    final dueAt = state?.nextWakeAt;
    if (dueAt == null) return;
    if (!automaticUpdatesEnabled(identity)) {
      skipPendingReportRefresh(identity.agentId);
      return;
    }
    _orchestrator.restorePendingWake(
      agentId: identity.agentId,
      dueAt: dueAt,
      triggerTokens: const {goalDeferredReportRefreshTriggerToken},
      workspaceKey: goalReportRefreshTriggerToken,
      reasonId: goalDeferredReportRefreshTriggerToken,
    );
  }

  /// Cancels only the currently pending automatic refresh. The preference
  /// stays enabled, so the next meaningful evidence change can schedule a new
  /// countdown.
  void skipPendingReportRefresh(String agentId) {
    _orchestrator
      ..clearThrottle(agentId)
      ..cancelPendingWakes(
        agentId,
        workspaceKey: goalReportRefreshTriggerToken,
      );
  }

  /// Rebinds the runtime to an owner- or agent-authored spec revision and
  /// evaluates it immediately against the evidence that already exists.
  void refreshAfterRevision({
    required String agentId,
    required GoalCriterion criteria,
  }) {
    registerSignalSubscription(agentId, criteria);
    _orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: 'goal revised',
    );
  }

  /// Observes exactly the signals referenced by the goal criteria.
  ///
  /// Bounded habit and measured-data writes immediately run the deterministic
  /// evaluator. Health samples additionally mark exact report evidence stale,
  /// while high-frequency category-time activity only marks it stale; the
  /// daily cadence or Update now consumes category changes.
  void registerSignalSubscription(String agentId, GoalCriterion criteria) {
    _orchestrator.removeSubscriptions(agentId);
    final immediateTokens = goalImmediateSignalTriggerTokens(criteria);
    if (immediateTokens.isNotEmpty) {
      _orchestrator.addSubscription(
        AgentSubscription(
          id: goalSignalSubscriptionId(agentId),
          agentId: agentId,
          matchEntityIds: immediateTokens,
          deferPropagatedMatches: false,
          drainImmediately: true,
        ),
      );
    }
    final staleTokens = goalStaleSignalTriggerTokens(criteria);
    if (staleTokens.isNotEmpty) {
      _orchestrator.addSubscription(
        AgentSubscription(
          id: goalStaleSignalSubscriptionId(agentId),
          agentId: agentId,
          matchEntityIds: staleTokens,
          reportStaleOnly: true,
        ),
      );
    }
  }
}

/// Stable subscription id, so repeated `restoreSubscriptions` replace
/// instead of accumulate.
String goalSignalSubscriptionId(String agentId) => '${agentId}_goal_signals';

/// Stable id for category-time observation that marks the report stale.
String goalStaleSignalSubscriptionId(String agentId) =>
    '${agentId}_goal_stale_signals';
