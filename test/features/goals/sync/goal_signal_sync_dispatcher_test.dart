import 'dart:async';

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
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
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
    bool includeCategoryTimeSessions = true,
    DateTime? categorySessionEvidenceStart,
    DateTime? categoryTimeEndExclusive,
  }) async => const GoalSignalWindow();
}

class _ThrowingThenRecordingPhaseA extends _RecordingPhaseA {
  @override
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) {
    if (agentIdentity.agentId == 'goal-broken') {
      throw StateError('corrupt goal');
    }
    return super.execute(
      agentIdentity: agentIdentity,
      runKey: runKey,
      triggerTokens: triggerTokens,
      threadId: threadId,
    );
  }
}

class _RecordingPhaseA extends GoalAgentPhaseA {
  _RecordingPhaseA()
    : super(
        repository: MockAgentRepository(),
        syncService: MockAgentSyncService(),
        signalReader: _FakeReader(),
      );

  final calls = <(String, Set<String>)>[];

  /// Completed on every recorded call — deterministic synchronization for
  /// listener tests (no event-loop-turn guessing).
  Completer<void> nextCall = Completer<void>();

  @override
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    calls.add((agentIdentity.agentId, triggerTokens));
    final completer = nextCall;
    nextCall = Completer<void>();
    completer.complete();
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

  void stubSpec(
    String agentId, {
    GoalCriterion goalCriteria = criteria,
  }) {
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
        criteria: goalCriteria,
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
  }

  late List<String> evaluated;

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    phaseA = _RecordingPhaseA();
    evaluated = [];
    dispatcher = GoalSignalSyncDispatcher(
      agentService: agentService,
      repository: repository,
      phaseA: phaseA,
      onAgentEvaluated: evaluated.add,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => agentService.markReportStale(any()),
    ).thenAnswer((_) async {});
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
    expect(
      evaluated,
      ['goal-a'],
      reason: 'health projections must hear about the silent Phase A write',
    );
  });

  test('a batch with no goal signals dispatches nothing', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a');

    await dispatcher.dispatchBatch({'some-task-id', 'HABIT_COMPLETION'});
    expect(phaseA.calls, isEmpty);
  });

  test('synced health evidence marks the report stale and evaluates', () async {
    const weight = GoalCriterion.metric(
      criterionId: 'weight',
      dataType: GoalHealthDataTypes.weight,
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 88,
      direction: GoalDirection.atMost,
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a', goalCriteria: weight);

    await dispatcher.dispatchBatch({GoalHealthDataTypes.weight});

    verify(() => agentService.markReportStale('goal-a')).called(1);
    expect(phaseA.calls.single.$2, {GoalHealthDataTypes.weight});
    expect(evaluated, ['goal-a']);
  });

  test('synced category-time churn waits for the scheduled cadence', () async {
    const categoryTime = GoalCriterion.categoryTime(
      criterionId: 'coding-time',
      categoryId: 'coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a', goalCriteria: categoryTime);

    await dispatcher.dispatchBatch(goalStaleSignalTriggerTokens(categoryTime));

    expect(phaseA.calls, isEmpty);
    verify(() => agentService.markReportStale('goal-a')).called(1);
    expect(evaluated, isEmpty, reason: 'no Phase A projection was written');
  });

  test('a mixed synced batch marks category evidence stale and evaluates '
      'bounded evidence once', () async {
    const composite = GoalCriterion.allOf(
      criterionId: 'mixed',
      criteria: [
        criteria,
        GoalCriterion.categoryTime(
          criterionId: 'coding-time',
          categoryId: 'coding',
          window: GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          targetHours: 2,
        ),
      ],
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a', goalCriteria: composite);

    await dispatcher.dispatchBatch({
      'cumulative_step_count',
      goalStaleSignalTriggerTokens(composite).first,
    });

    verify(() => agentService.markReportStale('goal-a')).called(1);
    expect(phaseA.calls.single.$2, {'cumulative_step_count'});
    expect(evaluated, ['goal-a'], reason: 'one batch emits one UI refresh');
  });

  test('the listener pumps synced batches, starts once, and stops on '
      'dispose', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a');

    final controller = StreamController<Set<String>>.broadcast();
    addTearDown(controller.close);
    final updateNotifications = MockUpdateNotifications();
    when(
      () => updateNotifications.syncUpdateStream,
    ).thenAnswer((_) => controller.stream);

    final listener =
        GoalSignalSyncListener(
            updateNotifications: updateNotifications,
            dispatcher: dispatcher,
          )
          ..start()
          // A second start must not double-subscribe.
          ..start();

    controller.add({'cumulative_step_count'});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(phaseA.calls, hasLength(1));

    await listener.dispose();
    controller.add({'cumulative_step_count'});
    await Future<void>.delayed(Duration.zero);
    expect(phaseA.calls, hasLength(1), reason: 'disposed = deaf');
  });

  test('one throwing goal cannot suppress evaluation of the next', () async {
    final throwing = _ThrowingThenRecordingPhaseA();
    final containedDispatcher = GoalSignalSyncDispatcher(
      agentService: agentService,
      repository: repository,
      phaseA: throwing,
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer(
      (_) async => [
        identity('goal-broken', AgentKinds.goalAgent),
        identity('goal-b', AgentKinds.goalAgent),
      ],
    );
    stubSpec('goal-broken');
    stubSpec('goal-b');

    await containedDispatcher.dispatchBatch({'cumulative_step_count'});
    expect(throwing.calls.map((c) => c.$1), ['goal-b']);
  });

  test('a stream error reaches the logger instead of ending evaluation '
      'silently', () async {
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
    final controller = StreamController<Set<String>>.broadcast();
    addTearDown(controller.close);
    final updateNotifications = MockUpdateNotifications();
    when(
      () => updateNotifications.syncUpdateStream,
    ).thenAnswer((_) => controller.stream);
    GoalSignalSyncListener(
      updateNotifications: updateNotifications,
      dispatcher: dispatcher,
      domainLogger: logger,
    ).start();

    controller.addError(StateError('stream broke'));
    await Future<void>.delayed(Duration.zero);
    verify(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).called(1);
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
  test('an agent-level batch with a misaligned register forces a '
      'recompute — split-brain heads self-heal without waiting for '
      'cadence', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity('goal-a', AgentKinds.goalAgent)]);
    stubSpec('goal-a');
    when(
      () => repository.getEntitiesByAgentId('goal-a', type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.goalProgress(
              id: 'goal_progress:goal-a:2026-08-10',
              agentId: 'goal-a',
              periodKey: '2026-08-10',
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1,
              dataCoverage: 1,
              satisfied: true,
              specVersionId: 'goal-a:spec-v2-loser',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalProgressEntity,
      ],
    );

    await dispatcher.dispatchBatch({'goal-a'});
    expect(phaseA.calls, hasLength(1));
    expect(evaluated, ['goal-a']);
  });
}
