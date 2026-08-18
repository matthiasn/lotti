import 'package:clock/clock.dart';
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
import 'package:lotti/features/goals/runtime/goal_runtime_maintenance.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';
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

  final now = DateTime(2026, 8, 8, 14, 30);
  final fixedClock = Clock.fixed(now);

  const criteria = GoalCriterion.habit(
    criterionId: 'gym',
    habitId: 'gym-habit',
    window: GoalWindow.calendarWeek(),
    targetCount: 3,
  );

  AgentIdentityEntity goalIdentity(
    String id, {
    String kind = AgentKinds.goalAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: kind,
            displayName: id,
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$id:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late GoalRuntimeMaintenance maintenance;
  late MockGoalMirrorService mirror;
  late MockGoalCheckInNotifier notifier;
  late List<AgentDomainEntity> upserts;

  void stubSpec(String agentId) {
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v1',
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: agentId,
        statement: 'x',
        criteria: criteria,
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
  }

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    orchestrator = MockWakeOrchestrator();
    mirror = MockGoalMirrorService();
    notifier = MockGoalCheckInNotifier();
    when(() => notifier.watch(any())).thenReturn(null);
    when(() => notifier.unwatch(any())).thenReturn(null);
    when(() => notifier.start(any())).thenReturn(null);
    when(
      () => mirror.mirrorHead(any(), categoryId: any(named: 'categoryId')),
    ).thenAnswer((_) async => null);
    maintenance = GoalRuntimeMaintenance(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      goalAgentService: GoalAgentService(
        agentService: agentService,
        repository: repository,
        syncService: syncService,
        orchestrator: orchestrator,
      ),
      goalMirrorService: mirror,
      checkInNotifier: notifier,
    );
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => orchestrator.addSubscription(any())).thenReturn(null);
  });

  group(
    'the journal-side backfill covers every goal, not just active ones',
    () {
      AgentIdentityEntity goal(String id, AgentLifecycle lifecycle) =>
          AgentDomainEntity.agent(
                id: id,
                agentId: id,
                kind: AgentKinds.goalAgent,
                displayName: id,
                lifecycle: lifecycle,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: '$id:state',
                config: const AgentConfig(),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                vectorClock: null,
              )
              as AgentIdentityEntity;

      test('a dormant or destroyed goal still gets its durable row', () async {
        // These are exactly the goals a restore without the agent database
        // would lose, so gating the mirror on "should this be subscribed"
        // stranded precisely the ones that most needed it.
        when(() => agentService.listAgents()).thenAnswer(
          (_) async => [
            goal('active-goal', AgentLifecycle.active),
            goal('dormant-goal', AgentLifecycle.dormant),
            goal('destroyed-goal', AgentLifecycle.destroyed),
          ],
        );
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [goal('active-goal', AgentLifecycle.active)]);
        stubSpec('active-goal');

        await maintenance.restoreSubscriptions();

        verify(() => mirror.mirrorHead('active-goal')).called(1);
        verify(() => mirror.mirrorHead('dormant-goal')).called(1);
        verify(() => mirror.mirrorHead('destroyed-goal')).called(1);
      });

      test('one goal failing to mirror does not strand the others', () async {
        when(() => agentService.listAgents()).thenAnswer(
          (_) async => [
            goal('broken-goal', AgentLifecycle.active),
            goal('fine-goal', AgentLifecycle.active),
          ],
        );
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => []);
        when(
          () => mirror.mirrorHead('broken-goal'),
        ).thenThrow(Exception('journal is unavailable'));

        await maintenance.restoreSubscriptions();

        verify(() => mirror.mirrorHead('fine-goal')).called(1);
      });

      test(
        'a synced dormant goal is mirrored before the lifecycle gate',
        () async {
          await maintenance.onIdentityReceived(
            goal('synced-dormant', AgentLifecycle.dormant),
          );

          // The mirror runs first; only the SUBSCRIPTION is gated on lifecycle.
          verify(() => mirror.mirrorHead('synced-dormant')).called(1);
          verify(
            () => orchestrator.removeSubscriptions('synced-dormant'),
          ).called(1);
        },
      );

      test('a goal that syncs in before its spec head is still watched', () async {
        // Identity and spec head arrive as separate synced entities in no
        // guaranteed order. Watching behind the criteria gate meant an identity
        // that landed first left the goal unwatched until a restart — the
        // startup-snapshot bug reintroduced by placement rather than by logic.
        when(() => repository.getEntity(any())).thenAnswer((_) async => null);

        await maintenance.onIdentityReceived(
          goal('head-not-here-yet', AgentLifecycle.active),
        );

        verify(() => mirror.mirrorHead('head-not-here-yet')).called(1);
        verify(() => notifier.watch('head-not-here-yet')).called(1);
        // No criteria, so no signal subscription — only the watch survives the
        // missing head.
        verifyNever(() => orchestrator.addSubscription(any()));
      });

      test('a non-goal identity is ignored entirely', () async {
        await maintenance.onIdentityReceived(
          AgentDomainEntity.agent(
                id: 'task-1',
                agentId: 'task-1',
                kind: AgentKinds.taskAgent,
                displayName: 'task',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: 'task-1:state',
                config: const AgentConfig(),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                vectorClock: null,
              )
              as AgentIdentityEntity,
        );

        verifyNever(() => mirror.mirrorHead(any()));
      });
    },
  );

  test('restoreSubscriptions re-registers every active goal agent, and one '
      'broken goal does not take the others down', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer(
      (_) async => [goalIdentity('goal-a'), goalIdentity('goal-b')],
    );
    stubSpec('goal-b');
    // goal-a's head read explodes; goal-b must still be restored.
    when(
      () => repository.getEntity(goalSpecHeadId('goal-a')),
    ).thenThrow(StateError('boom'));

    await maintenance.restoreSubscriptions();

    final captured = verify(
      () => orchestrator.addSubscription(captureAny()),
    ).captured;
    expect(captured, hasLength(1));
    expect(
      (captured.single as AgentSubscription).id,
      goalSignalSubscriptionId('goal-b'),
    );
  });

  test(
    'a repository explosion in beforeWakeScan is contained and logged',
    () async {
      final logger = MockDomainLogger();
      when(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      ).thenReturn(null);
      final loggingMaintenance = GoalRuntimeMaintenance(
        agentService: agentService,
        repository: repository,
        syncService: syncService,
        goalAgentService: GoalAgentService(
          agentService: agentService,
          repository: repository,
          syncService: syncService,
          orchestrator: orchestrator,
        ),
        domainLogger: logger,
      );
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async => [goalIdentity('goal-a')]);
      when(() => repository.getEntity(any())).thenThrow(StateError('boom'));

      await withClock(fixedClock, loggingMaintenance.beforeWakeScan);

      verify(
        () => logger.error(
          LogDomain.agentRuntime,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      ).called(1);
    },
  );

  test(
    'a listAgents failure is contained in both maintenance passes',
    () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenThrow(StateError('db gone'));
      await expectLater(maintenance.restoreSubscriptions(), completes);
      await expectLater(
        withClock(fixedClock, maintenance.beforeWakeScan),
        completes,
      );
      verifyNever(() => orchestrator.addSubscription(any()));
      expect(upserts, isEmpty);
    },
  );

  test('a synced-in ACTIVE goal identity subscribes mid-session; a '
      'non-goal identity is ignored', () async {
    stubSpec('goal-a');
    await maintenance.onIdentityReceived(goalIdentity('goal-a'));
    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.single
            as AgentSubscription;
    expect(subscription.agentId, 'goal-a');
    expect(subscription.matchEntityIds, {'gym-habit'});
    verify(() => orchestrator.removeSubscriptions('goal-a')).called(1);
    clearInteractions(orchestrator);

    await maintenance.onIdentityReceived(
      goalIdentity('task-1', kind: AgentKinds.taskAgent),
    );
    verifyNever(() => orchestrator.removeSubscriptions(any()));
  });

  test('a synced-in dormant goal identity is unsubscribed, and a failing '
      'spec read is contained', () async {
    when(() => orchestrator.removeSubscriptions(any())).thenReturn(null);
    await maintenance.onIdentityReceived(
      goalIdentity('goal-a', lifecycle: AgentLifecycle.dormant),
    );
    verify(() => orchestrator.removeSubscriptions('goal-a')).called(1);

    when(
      () => repository.getEntity(goalSpecHeadId('goal-a')),
    ).thenThrow(StateError('db gone'));
    await expectLater(
      maintenance.onIdentityReceived(goalIdentity('goal-a')),
      completes,
    );
    verifyNever(() => orchestrator.addSubscription(any()));
  });

  test('beforeWakeScan heals a missing cadence record', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [goalIdentity('goal-a')]);

    await withClock(fixedClock, maintenance.beforeWakeScan);

    final cadence = upserts.whereType<ScheduledWakeEntity>().single;
    expect(cadence.agentId, 'goal-a');
    expect(cadence.workspaceKey, goalCadenceWorkspaceKey);
  });

  test('beforeWakeScan leaves a pending future cadence alone', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [goalIdentity('goal-a')]);
    when(
      () => repository.getEntity(
        scheduledWakeRecordId(
          'goal-a',
          workspaceKey: goalCadenceWorkspaceKey,
        ),
      ),
    ).thenAnswer(
      (_) async => AgentDomainEntity.scheduledWake(
        id: scheduledWakeRecordId(
          'goal-a',
          workspaceKey: goalCadenceWorkspaceKey,
        ),
        agentId: 'goal-a',
        scheduledAt: now.add(const Duration(hours: 12)),
        status: ScheduledWakeStatus.pending,
        reason: WakeReason.scheduled.name,
        updatedAt: now,
        vectorClock: null,
        workspaceKey: goalCadenceWorkspaceKey,
      ),
    );

    await withClock(fixedClock, maintenance.beforeWakeScan);
    expect(upserts, isEmpty);
  });

  test('beforeWakeScan re-arms after a consumed tick whose run died before '
      're-arming', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [goalIdentity('goal-a')]);
    when(
      () => repository.getEntity(
        scheduledWakeRecordId(
          'goal-a',
          workspaceKey: goalCadenceWorkspaceKey,
        ),
      ),
    ).thenAnswer(
      (_) async => AgentDomainEntity.scheduledWake(
        id: scheduledWakeRecordId(
          'goal-a',
          workspaceKey: goalCadenceWorkspaceKey,
        ),
        agentId: 'goal-a',
        scheduledAt: now.subtract(const Duration(hours: 8)),
        status: ScheduledWakeStatus.consumed,
        reason: WakeReason.scheduled.name,
        updatedAt: now.subtract(const Duration(hours: 8)),
        vectorClock: null,
        workspaceKey: goalCadenceWorkspaceKey,
        consumedAt: now.subtract(const Duration(hours: 8)),
      ),
    );

    await withClock(fixedClock, maintenance.beforeWakeScan);
    expect(upserts.whereType<ScheduledWakeEntity>(), hasLength(1));
  });
}
