import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
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
  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late GoalAgentService service;
  late List<AgentDomainEntity> upserts;

  setUp(() {
    agentService = MockAgentService();
    syncService = MockAgentSyncService();
    orchestrator = MockWakeOrchestrator();
    service = GoalAgentService(
      agentService: agentService,
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
}
