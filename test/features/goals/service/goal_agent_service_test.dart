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

    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.single
            as AgentSubscription;
    expect(subscription.id, goalSignalSubscriptionId(agentId));
    expect(subscription.agentId, agentId);
    expect(subscription.matchEntityIds, {'gym-habit'});
  });

  test('removeSignalSubscriptions drops the agent from the orchestrator', () {
    when(() => orchestrator.removeSubscriptions(any())).thenReturn(null);
    service.removeSignalSubscriptions(agentId);
    verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
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
