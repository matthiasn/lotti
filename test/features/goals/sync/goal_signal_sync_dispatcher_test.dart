import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

class _FakeReader extends GoalSignalReader {
  _FakeReader() : super(journalDb: MockJournalDb());

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
  }) async => const GoalSignalWindow();
}

class _RecordingPhaseA extends GoalAgentPhaseA {
  _RecordingPhaseA()
    : super(
        repository: MockAgentRepository(),
        syncService: MockAgentSyncService(),
        signalReader: _FakeReader(),
      );

  final calls = <(String, Set<String>)>[];

  @override
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    calls.add((agentIdentity.agentId, triggerTokens));
    return const WakeResult(success: true);
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  const criteria = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  AgentIdentityEntity identity(String id, String kind) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: kind,
            displayName: id,
            lifecycle: AgentLifecycle.active,
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
  late _RecordingPhaseA phaseA;
  late GoalSignalSyncDispatcher dispatcher;

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
    phaseA = _RecordingPhaseA();
    dispatcher = GoalSignalSyncDispatcher(
      agentService: agentService,
      repository: repository,
      phaseA: phaseA,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
  });

  test('a synced batch touching a goal signal runs Phase A with the '
      'intersection', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer(
      (_) async => [
        identity('goal-a', AgentKinds.goalAgent),
        identity('task-1', AgentKinds.taskAgent),
      ],
    );
    stubSpec('goal-a');

    await dispatcher.dispatchBatch(
      {'cumulative_step_count', 'unrelated-id'},
    );

    expect(phaseA.calls, hasLength(1));
    expect(phaseA.calls.single.$1, 'goal-a');
    expect(phaseA.calls.single.$2, {'cumulative_step_count'});
  });

  test('a batch with no goal signals dispatches nothing', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a');

    await dispatcher.dispatchBatch({'some-task-id', 'HABIT_COMPLETION'});
    expect(phaseA.calls, isEmpty);
  });

  test(
    'failures are contained — a listAgents explosion never throws',
    () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenThrow(StateError('db gone'));
      await expectLater(
        dispatcher.dispatchBatch({'cumulative_step_count'}),
        completes,
      );
    },
  );
}
