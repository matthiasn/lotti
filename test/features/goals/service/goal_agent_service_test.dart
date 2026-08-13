import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      AgentSubscription(id: 'f', agentId: 'f', matchEntityIds: const {}),
    );
  });

  const agentId = 'goal-agent-1';
  const criteria = GoalCriterion.habit(
    criterionId: 'gym',
    habitId: 'gym-habit',
    window: GoalWindow.calendarWeek(),
    targetCount: 3,
  );

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late GoalAgentService service;
  late List<AgentDomainEntity> upserts;

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    orchestrator = MockWakeOrchestrator();
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => repository.getAgentState(any())).thenAnswer((_) async => null);
    service = GoalAgentService(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
    );
    upserts = [];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => orchestrator.addSubscription(any())).thenReturn(null);
    when(() => orchestrator.clearThrottle(any())).thenReturn(null);
    when(
      () => orchestrator.cancelPendingWakes(
        any(),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    ).thenReturn(const []);
    when(
      () => orchestrator.enqueueDeferredAutomaticWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    ).thenAnswer((_) async => 'run-deferred');
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
      ),
    ).thenReturn('run-initial');
    when(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        agentId: any(named: 'agentId'),
      ),
    ).thenAnswer(
      (_) async =>
          AgentDomainEntity.agent(
                id: agentId,
                agentId: agentId,
                kind: AgentKinds.goalAgent,
                displayName: 'Gym 3×/week',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: '$agentId:state',
                config: const AgentConfig(),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                vectorClock: null,
              )
              as AgentIdentityEntity,
    );
  });

  test('invalid criteria never reach persistence', () async {
    const doomed = GoalCriterion.allOf(criterionId: 'root', criteria: []);
    await expectLater(
      () => service.createGoalAgent(
        title: 'Broken',
        statement: 'x',
        criteria: doomed,
      ),
      throwsArgumentError,
    );
    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        agentId: any(named: 'agentId'),
      ),
    );
    expect(upserts, isEmpty);
  });

  test('creation writes spec v1 + head + first cadence tick, then '
      'subscribes to the goal signals', () async {
    final identity = await service.createGoalAgent(
      title: 'Gym 3×/week',
      displayName: 'Juno',
      statement: 'Train at the station gym three times per week.',
      criteria: criteria,
      agentId: agentId,
    );
    expect(identity.kind, AgentKinds.goalAgent);

    final version = upserts.whereType<GoalSpecVersionEntity>().single;
    expect(version.version, 1);
    expect(version.status, GoalSpecVersionStatus.active);
    expect(version.authoredBy, 'user');
    expect(version.criteria, criteria);

    final head = upserts.whereType<GoalSpecHeadEntity>().single;
    expect(head.id, goalSpecHeadId(agentId));
    expect(head.versionId, version.id);

    final cadence = upserts.whereType<ScheduledWakeEntity>().single;
    expect(cadence.workspaceKey, goalCadenceWorkspaceKey);

    // The just-created goal is evaluated immediately — no day-long blank
    // health while waiting for the next cadence tick.
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
        reason: any(named: 'reason'),
      ),
    ).called(1);

    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.single
            as AgentSubscription;
    expect(subscription.id, goalSignalSubscriptionId(agentId));
    expect(subscription.agentId, agentId);
    expect(subscription.matchEntityIds, {'gym-habit'});
    // A habit check-off is atomic evidence and Phase A is €0: the wake
    // dispatches immediately instead of sitting behind the task-agent
    // 120-second coalescing window (the user's tap must be acknowledged
    // in seconds).
    expect(subscription.drainImmediately, isTrue);
    verify(
      () => agentService.createAgent(
        kind: AgentKinds.goalAgent,
        displayName: 'Juno',
        config: const AgentConfig(automaticUpdatesEnabled: true),
        agentId: agentId,
      ),
    ).called(1);
  });

  test('removeSignalSubscriptions drops the agent from the orchestrator', () {
    when(() => orchestrator.removeSubscriptions(any())).thenReturn(null);
    service.removeSignalSubscriptions(agentId);
    verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
  });

  test('legacy goal configs keep automatic refreshes enabled', () {
    final legacy =
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: const AgentConfig(),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;

    expect(GoalAgentService.automaticUpdatesEnabled(legacy), isTrue);
    expect(
      GoalAgentService.automaticUpdatesEnabled(
        legacy.copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        ),
      ),
      isFalse,
    );
  });

  test('an active automatic goal queues the deferred Phase A arm', () async {
    final identity =
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: const AgentConfig(automaticUpdatesEnabled: true),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    when(() => repository.getEntity(agentId)).thenAnswer((_) async => identity);

    await service.scheduleAutomaticReportRefresh(agentId);

    verify(
      () => orchestrator.enqueueDeferredAutomaticWake(
        agentId: agentId,
        reason: WakeReason.subscription.name,
        triggerTokens: const {goalDeferredReportRefreshTriggerToken},
        workspaceKey: goalReportRefreshTriggerToken,
      ),
    ).called(1);
  });

  test('a disabled or dormant goal never queues automatic inference', () async {
    AgentIdentityEntity identity({
      bool enabled = false,
      AgentLifecycle lifecycle = AgentLifecycle.active,
    }) =>
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: lifecycle,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: AgentConfig(automaticUpdatesEnabled: enabled),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => identity());
    await service.scheduleAutomaticReportRefresh(agentId);

    when(
      () => repository.getEntity(agentId),
    ).thenAnswer(
      (_) async => identity(enabled: true, lifecycle: AgentLifecycle.dormant),
    );
    await service.scheduleAutomaticReportRefresh(agentId);

    verifyNever(
      () => orchestrator.enqueueDeferredAutomaticWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    );
  });

  test('turning automatic refreshes off persists the preference and cancels '
      'only pending work', () async {
    final identity =
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: const AgentConfig(automaticUpdatesEnabled: true),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    when(() => repository.getEntity(agentId)).thenAnswer((_) async => identity);
    await service.updateAutomaticUpdates(agentId: agentId, enabled: false);

    final written = upserts.whereType<AgentIdentityEntity>().single;
    expect(written.config.automaticUpdatesEnabled, isFalse);
    verify(() => orchestrator.clearThrottle(agentId)).called(1);
    verify(
      () => orchestrator.cancelPendingWakes(
        agentId,
        workspaceKey: goalReportRefreshTriggerToken,
      ),
    ).called(1);
    verifyNever(
      () => orchestrator.enqueueDeferredAutomaticWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    );
  });

  test('turning automatic refreshes on queues one catch-up for a stale '
      'report', () async {
    AgentIdentityEntity identity({required bool enabled}) =>
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: AgentConfig(automaticUpdatesEnabled: enabled),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    var reads = 0;
    when(() => repository.getEntity(agentId)).thenAnswer((_) async {
      reads++;
      return identity(enabled: reads > 1);
    });
    when(() => repository.getAgentState(agentId)).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentState(
                id: '$agentId:state',
                agentId: agentId,
                slots: const AgentSlots(),
                updatedAt: DateTime(2026, 8, 13, 12),
                vectorClock: null,
                reportFreshAt: DateTime(2026, 8, 13, 10),
                reportStaleAt: DateTime(2026, 8, 13, 11),
              )
              as AgentStateEntity,
    );

    await service.updateAutomaticUpdates(agentId: agentId, enabled: true);

    expect(
      upserts
          .whereType<AgentIdentityEntity>()
          .single
          .config
          .automaticUpdatesEnabled,
      isTrue,
    );
    verify(
      () => orchestrator.enqueueDeferredAutomaticWake(
        agentId: agentId,
        reason: WakeReason.subscription.name,
        triggerTokens: const {goalDeferredReportRefreshTriggerToken},
        workspaceKey: goalReportRefreshTriggerToken,
      ),
    ).called(1);
  });

  test('restoring a countdown reconstructs its goal-specific trigger', () {
    final identity =
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: const AgentConfig(automaticUpdatesEnabled: true),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    final dueAt = DateTime(2026, 8, 13, 12, 2);
    final state =
        AgentDomainEntity.agentState(
              id: '$agentId:state',
              agentId: agentId,
              slots: const AgentSlots(),
              updatedAt: DateTime(2026, 8, 13, 12),
              vectorClock: null,
              nextWakeAt: dueAt,
            )
            as AgentStateEntity;
    when(
      () => orchestrator.restorePendingWake(
        agentId: any(named: 'agentId'),
        dueAt: any(named: 'dueAt'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
        reasonId: any(named: 'reasonId'),
      ),
    ).thenReturn(null);

    service.restorePendingReportRefresh(identity: identity, state: state);

    verify(
      () => orchestrator.restorePendingWake(
        agentId: agentId,
        dueAt: dueAt,
        triggerTokens: const {goalDeferredReportRefreshTriggerToken},
        workspaceKey: goalReportRefreshTriggerToken,
        reasonId: goalDeferredReportRefreshTriggerToken,
      ),
    ).called(1);
  });

  test('a disabled goal clears a restored local countdown', () {
    final identity =
        AgentDomainEntity.agent(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.goalAgent,
              displayName: 'Goal',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: '$agentId:state',
              config: const AgentConfig(automaticUpdatesEnabled: false),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    final state =
        AgentDomainEntity.agentState(
              id: '$agentId:state',
              agentId: agentId,
              slots: const AgentSlots(),
              updatedAt: DateTime(2026, 8, 13, 12),
              vectorClock: null,
              nextWakeAt: DateTime(2026, 8, 13, 12, 2),
            )
            as AgentStateEntity;

    service.restorePendingReportRefresh(identity: identity, state: state);

    verify(() => orchestrator.clearThrottle(agentId)).called(1);
    verify(
      () => orchestrator.cancelPendingWakes(
        agentId,
        workspaceKey: goalReportRefreshTriggerToken,
      ),
    ).called(1);
  });

  test('category time marks the report stale while bounded signals wake', () {
    const categoryTime = GoalCriterion.categoryTime(
      criterionId: 'coding-time',
      categoryId: 'coding',
      window: GoalWindow.rollingDays(count: 7),
      targetHours: 10,
      aggregation: GoalAggregation.sum,
    );
    const mixed = GoalCriterion.allOf(
      criterionId: 'balanced',
      criteria: [criteria, categoryTime],
    );

    service.registerSignalSubscription(agentId, mixed);

    final subscriptions = verify(
      () => orchestrator.addSubscription(captureAny()),
    ).captured.cast<AgentSubscription>();
    final immediate = subscriptions.singleWhere(
      (subscription) => subscription.id == goalSignalSubscriptionId(agentId),
    );
    expect(immediate.matchEntityIds, {'gym-habit'});
    expect(immediate.drainImmediately, isTrue);
    expect(immediate.reportStaleOnly, isFalse);

    final stale = subscriptions.singleWhere(
      (subscription) =>
          subscription.id == goalStaleSignalSubscriptionId(agentId),
    );
    expect(stale.matchEntityIds, goalStaleSignalTriggerTokens(categoryTime));
    expect(stale.drainImmediately, isFalse);
    expect(stale.reportStaleOnly, isTrue);
    verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
  });

  test('health samples both evaluate and mark exact report evidence stale', () {
    const weight = GoalCriterion.metric(
      criterionId: 'weight',
      dataType: GoalHealthDataTypes.weight,
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 88,
      direction: GoalDirection.atMost,
    );

    service.registerSignalSubscription(agentId, weight);

    final subscriptions = verify(
      () => orchestrator.addSubscription(captureAny()),
    ).captured.cast<AgentSubscription>();
    final immediate = subscriptions.singleWhere(
      (subscription) => subscription.id == goalSignalSubscriptionId(agentId),
    );
    final stale = subscriptions.singleWhere(
      (subscription) =>
          subscription.id == goalStaleSignalSubscriptionId(agentId),
    );
    expect(immediate.matchEntityIds, {GoalHealthDataTypes.weight});
    expect(immediate.drainImmediately, isTrue);
    expect(stale.matchEntityIds, {GoalHealthDataTypes.weight});
    expect(stale.reportStaleOnly, isTrue);
  });

  test('refreshAfterRevision re-registers changed signals and wakes the goal '
      'immediately', () {
    const revised = GoalCriterion.habit(
      criterionId: 'run',
      habitId: 'run-habit',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 5,
    );

    service.refreshAfterRevision(agentId: agentId, criteria: revised);

    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.single
            as AgentSubscription;
    expect(subscription.matchEntityIds, {'run-habit'});
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
        reason: 'goal revised',
      ),
    ).called(1);
  });

  test(
    'a repeated create for an existing goal refuses to rewrite spec v1, '
    'and the guard runs INSIDE the creation transaction',
    () async {
      // Two concurrent creates for the same id must serialize on the
      // transaction — a preflight read outside it would let both pass and
      // the loser rewrite the immutable spec v1.
      final order = <String>[];
      final txnSyncService = _OrderRecordingSyncService(order);
      when(() => txnSyncService.upsertEntity(any())).thenAnswer(
        (invocation) async {
          upserts.add(
            invocation.positionalArguments.first as AgentDomainEntity,
          );
        },
      );
      final txnService = GoalAgentService(
        agentService: agentService,
        repository: repository,
        syncService: txnSyncService,
        orchestrator: orchestrator,
      );
      when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
        (_) async {
          order.add('guard');
          return AgentDomainEntity.goalSpecHead(
            id: goalSpecHeadId(agentId),
            agentId: agentId,
            versionId: '$agentId:spec-v1',
            updatedAt: DateTime(2026),
            vectorClock: null,
          );
        },
      );
      await expectLater(
        () => txnService.createGoalAgent(
          title: 'Gym 3×/week',
          statement: 'x',
          criteria: criteria,
          agentId: agentId,
        ),
        throwsStateError,
      );
      expect(order, ['transaction', 'guard']);
      expect(upserts, isEmpty);
      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: any(named: 'agentId'),
        ),
      );
    },
  );
  test('a post-commit sync failure is reconciled: the goal is durable, so '
      'the creation reports success instead of inviting a duplicate '
      'retry', () async {
    final failing = _CommitThenThrowSyncService();
    final failUpserts = <AgentDomainEntity>[];
    when(() => failing.upsertEntity(any())).thenAnswer((invocation) async {
      failUpserts.add(
        invocation.positionalArguments.first as AgentDomainEntity,
      );
    });
    final reconciling = GoalAgentService(
      agentService: agentService,
      repository: repository,
      syncService: failing,
      orchestrator: orchestrator,
    );
    // After the durable writes, the repository serves the committed rows.
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => failUpserts.whereType<GoalSpecHeadEntity>().lastOrNull,
    );
    when(
      () => repository.getEntity('$agentId:spec-v1'),
    ).thenAnswer(
      (_) async => failUpserts.whereType<GoalSpecVersionEntity>().lastOrNull,
    );

    final identity = await reconciling.createGoalAgent(
      title: 'Gym 3×/week',
      statement: 'x',
      criteria: criteria,
      agentId: agentId,
    );
    expect(identity.agentId, agentId);
    expect(
      failUpserts.whereType<GoalSpecHeadEntity>(),
      hasLength(1),
      reason: 'exactly one goal exists — no duplicate mint on retry',
    );
  });

  group('deleteGoalAgent', () {
    test('retires the goal through the shared destroyed lifecycle', () async {
      when(() => agentService.cancelPendingWake(agentId)).thenReturn(null);
      when(() => agentService.abortRunningWake(agentId)).thenReturn(true);
      when(() => orchestrator.removeSubscriptions(agentId)).thenReturn(null);
      when(
        () => agentService.destroyAgent(agentId),
      ).thenAnswer((_) async => true);

      expect(await service.deleteGoalAgent(agentId), isTrue);

      verify(() => agentService.cancelPendingWake(agentId)).called(1);
      verify(() => agentService.abortRunningWake(agentId)).called(1);
      verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
      verify(() => agentService.destroyAgent(agentId)).called(1);
    });

    test('reports when no goal matched the id', () async {
      when(
        () => agentService.destroyAgent('missing'),
      ).thenAnswer((_) async => false);

      expect(await service.deleteGoalAgent('missing'), isFalse);

      verify(() => agentService.destroyAgent('missing')).called(1);
      verifyNever(() => agentService.cancelPendingWake('missing'));
      verifyNever(() => agentService.abortRunningWake('missing'));
      verifyNever(() => orchestrator.removeSubscriptions('missing'));
    });

    test('preserves the live runtime when the lifecycle write throws', () {
      when(
        () => agentService.destroyAgent('goal-live'),
      ).thenThrow(StateError('sync write failed'));

      expect(
        () => service.deleteGoalAgent('goal-live'),
        throwsA(isA<StateError>()),
      );
      verifyNever(() => agentService.cancelPendingWake('goal-live'));
      verifyNever(() => agentService.abortRunningWake('goal-live'));
      verifyNever(() => orchestrator.removeSubscriptions('goal-live'));
    });
  });
}

class _OrderRecordingSyncService extends MockAgentSyncService {
  _OrderRecordingSyncService(this.order);

  final List<String> order;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    order.add('transaction');
    return action();
  }
}

/// Runs the transaction body (writes land) and THEN throws — the durable
/// commit + failed outbox flush shape.
class _CommitThenThrowSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    await action();
    throw StateError('outbox flush failed');
  }
}
