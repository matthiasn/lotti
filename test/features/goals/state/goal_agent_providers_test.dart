import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_runtime_maintenance.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late StreamController<Set<String>> syncStream;
  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late ProviderContainer container;

  setUp(() {
    syncStream = StreamController<Set<String>>.broadcast();
    addTearDown(syncStream.close);
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    when(
      () => updateNotifications.syncUpdateStream,
    ).thenAnswer((_) => syncStream.stream);
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => []);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);

    final aiConfigRepository = MockAiConfigRepository();
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
        cloudInferenceRepositoryProvider.overrideWithValue(
          MockCloudInferenceRepository(),
        ),
        journalDbProvider.overrideWithValue(journalDb),
        agentRepositoryProvider.overrideWithValue(repository),
        agentSyncServiceProvider.overrideWithValue(syncService),
        agentServiceProvider.overrideWithValue(agentService),
        labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
        wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
        updateNotificationsProvider.overrideWithValue(updateNotifications),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
      ],
    );
    addTearDown(container.dispose);
  });

  AgentIdentityEntity goalIdentity(String id) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: AgentKinds.goalAgent,
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

  test('every goal provider constructs against the shared agent runtime', () {
    expect(container.read(goalSignalReaderProvider), isA<GoalSignalReader>());
    expect(container.read(goalAgentPhaseAProvider), isA<GoalAgentPhaseA>());
    expect(container.read(goalAgentServiceProvider), isA<GoalAgentService>());
    expect(
      container.read(goalRuntimeMaintenanceProvider),
      isA<GoalRuntimeMaintenance>(),
    );
    expect(
      container.read(goalSignalSyncDispatcherProvider),
      isA<GoalSignalSyncDispatcher>(),
    );
  });

  test('the runner map routes goal_agent wakes through Phase A', () async {
    final runners = container.read(goalAgentWakeRunnersProvider);
    expect(runners.keys, contains(AgentKinds.goalAgent));

    // Invoking the closure exercises the wiring end to end: a goal agent
    // without a spec head is Phase A's clean no-op.
    final result = await runners[AgentKinds.goalAgent]!(
      agentIdentity:
          AgentDomainEntity.agent(
                id: 'goal-x',
                agentId: 'goal-x',
                kind: AgentKinds.goalAgent,
                displayName: 'x',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: 'goal-x:state',
                config: const AgentConfig(),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                vectorClock: null,
              )
              as AgentIdentityEntity,
      runKey: 'run-1',
      triggerTokens: const {},
      threadId: 'thread-1',
    );
    expect(result.success, isTrue);
  });

  test('an escalation trigger token routes the wake to Phase B — proven '
      'by it failing on the missing inference provider, which the €0 tier '
      'never touches', () async {
    const agentId = 'goal-b';
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
        title: 'Gym',
        statement: 'x',
        criteria: const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    when(
      () => journalDb.getHabitCompletionsByHabitId(
        habitId: any(named: 'habitId'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getMessagesByKind(
        agentId,
        AgentMessageKind.observation,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);

    final runner = container.read(
      goalAgentWakeRunnersProvider,
    )[AgentKinds.goalAgent]!;

    // Phase B path: no AI model configs are registered, so the workflow
    // aborts on provider resolution — an error Phase A cannot produce.
    final phaseB = await runner(
      agentIdentity: goalIdentity(agentId),
      runKey: 'run-b',
      triggerTokens: {goalEscalationWorkspaceKey('2026-08-09')},
      threadId: 'thread-b',
    );
    expect(phaseB.success, isFalse);
    expect(phaseB.error, contains('no inference provider'));

    // The same wake without the escalation token stays on the €0 tier and
    // succeeds without any inference plumbing.
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => repository.getDueScheduledWakeRecords(any()),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getDueScheduledAgentStates(any()),
    ).thenAnswer((_) async => []);
    final phaseA = await runner(
      agentIdentity: goalIdentity(agentId),
      runKey: 'run-a',
      triggerTokens: const {'gym-habit'},
      threadId: 'thread-a',
    );
    expect(phaseA.success, isTrue);
  });

  test('a local escalation nudges the scheduled-wake manager instead of '
      'waiting out the hourly poll', () async {
    const agentId = 'goal-esc';
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
        title: 'Gym',
        statement: 'x',
        criteria: const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    when(
      () => journalDb.getHabitCompletionsByHabitId(
        habitId: any(named: 'habitId'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    // The nudged manager runs one scan pass; an empty due list ends it.
    when(
      () => repository.getDueScheduledWakeRecords(any()),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getDueScheduledAgentStates(any()),
    ).thenAnswer((_) async => []);

    final result =
        await container.read(
          goalAgentWakeRunnersProvider,
        )[AgentKinds.goalAgent]!(
          agentIdentity:
              AgentDomainEntity.agent(
                    id: agentId,
                    agentId: agentId,
                    kind: AgentKinds.goalAgent,
                    displayName: 'Gym',
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
          runKey: 'run-esc',
          triggerTokens: const {'gym-habit'},
          threadId: 'thread-esc',
        );
    expect(result.success, isTrue);

    // First-ever evaluation is a transition, so Phase A armed an
    // escalation and the provider-wired callback must have kicked the
    // manager into an immediate scan pass.
    await untilCalled(() => repository.getDueScheduledWakeRecords(any()));
  });

  test(
    'the sync listener starts on construction and feeds the dispatcher',
    () async {
      final listed = Completer<void>();
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async {
        if (!listed.isCompleted) listed.complete();
        return [];
      });
      container.read(goalSignalSyncListenerProvider);
      syncStream.add({'anything'});
      // Deterministic: resolves exactly when the provider-wired dispatcher
      // reached the agent service, however many event-loop turns that took.
      await listed.future;
    },
  );

  test('accepting a revision proposal end-to-end: decision persisted, v2 '
      'minted, head moved, and the signal subscription re-registered from '
      'the NEW criteria', () async {
    const agentId = 'goal-rev';
    final changeSet =
        AgentDomainEntity.changeSet(
              id: 'cs-1',
              agentId: agentId,
              taskId: agentId,
              threadId: 'thread-1',
              runKey: 'run-1',
              status: ChangeSetStatus.pending,
              items: const [
                ChangeItem(
                  toolName: GoalAgentToolNames.proposeGoalRevision,
                  args: {
                    'changes': {'targetValue': 8000},
                    'rationale': 'ease off',
                  },
                  humanSummary: 'Lower the target to 8000',
                ),
              ],
              createdAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as ChangeSetEntity;

    final upserted = <AgentDomainEntity>[];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserted.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => syncService.repository).thenReturn(repository);
    final orchestrator =
        container.read(wakeOrchestratorProvider) as MockWakeOrchestrator;
    when(() => orchestrator.addSubscription(any())).thenReturn(null);

    final headV1 =
        AgentDomainEntity.goalSpecHead(
              id: goalSpecHeadId(agentId),
              agentId: agentId,
              versionId: '$agentId:spec-v1',
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecHeadEntity;
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      // The confirmation hook re-reads the head AFTER the mint: serve the
      // freshest head that has been written, v1 before.
      (_) async =>
          upserted.whereType<GoalSpecHeadEntity>().lastOrNull ?? headV1,
    );
    when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v1',
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Gym',
        statement: 'x',
        criteria: const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        createdAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v2')).thenAnswer(
      (_) async => upserted
          .whereType<GoalSpecVersionEntity>()
          .where((v) => v.id == '$agentId:spec-v2')
          .lastOrNull,
    );
    when(() => repository.getEntity('cs-1')).thenAnswer((_) async => changeSet);

    final service = container.read(goalChangeSetConfirmationServiceProvider);
    // A habit goal can't take targetValue — use cadence instead so the
    // revision is applicable.
    final applicable = changeSet.copyWith(
      items: const [
        ChangeItem(
          toolName: GoalAgentToolNames.proposeGoalRevision,
          args: {
            'changes': {'cadence': 4},
            'rationale': 'step it up',
          },
          humanSummary: 'Raise the cadence to 4',
        ),
      ],
    );
    when(
      () => repository.getEntity('cs-1'),
    ).thenAnswer((_) async => applicable);

    final result = await service.confirmItem(applicable, 0);
    expect(result.success, isTrue, reason: result.errorMessage ?? '');
    expect(result.mutatedEntityId, '$agentId:spec-v2');

    final minted = upserted.whereType<GoalSpecVersionEntity>().singleWhere(
      (v) => v.id == '$agentId:spec-v2',
    );
    expect((minted.criteria as GoalCriterionHabit).targetCount, 4);
    final head = upserted.whereType<GoalSpecHeadEntity>().last;
    expect(head.versionId, '$agentId:spec-v2');

    final decision = upserted.whereType<ChangeDecisionEntity>().single;
    expect(decision.verdict, ChangeDecisionVerdict.confirmed);

    // The hook re-registered the subscription from the NEW criteria.
    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.last
            as AgentSubscription;
    expect(subscription.agentId, agentId);
    expect(subscription.matchEntityIds, {'gym-habit'});
  });
}
