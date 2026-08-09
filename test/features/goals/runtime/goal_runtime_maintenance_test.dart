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
    );
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => orchestrator.addSubscription(any())).thenReturn(null);
  });

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
