import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
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
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late StreamController<Set<String>> syncStream;
  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<TimeService>(MockTimeService()),
    );
    syncStream = StreamController<Set<String>>.broadcast();
    addTearDown(syncStream.close);
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    when(() => updateNotifications.notify(any())).thenReturn(null);
    when(
      () => updateNotifications.syncUpdateStream,
    ).thenAnswer((_) => syncStream.stream);
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => []);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => []);

    final aiConfigRepository = MockAiConfigRepository();
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
        // The banner provider is gated on the agents rollout flag.
        configFlagProvider(
          enableAgentsPageFlag,
        ).overrideWith((ref) => Stream.value(true)),
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
  tearDown(tearDownTestGetIt);

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
    expect(container.read(goalChatServiceProvider), isA<GoalChatService>());
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

  test(
    'a chat-message trigger routes to the durable user-message workflow',
    () async {
      final runner = container.read(
        goalAgentWakeRunnersProvider,
      )[AgentKinds.goalAgent]!;
      final result = await runner(
        agentIdentity: goalIdentity('goal-chat'),
        runKey: 'chat-run',
        triggerTokens: const {'goal-chat-message:missing'},
        threadId: 'chat-run',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('source message is unavailable'));
    },
  );

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
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});

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

    // A report refresh requested by the goal-detail habit editor follows the
    // same fact-grounded Phase B path even when the status itself did not
    // transition.
    final reportRefresh = await runner(
      agentIdentity: goalIdentity(agentId),
      runKey: 'run-refresh',
      triggerTokens: const {goalReportRefreshTriggerToken},
      threadId: 'thread-refresh',
    );
    expect(reportRefresh.success, isFalse);
    expect(reportRefresh.error, contains('no inference provider'));

    // The same wake without the escalation token stays on the €0 tier and
    // succeeds without any inference plumbing.
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

  test('a successful synced-batch evaluation notifies the UI for exactly '
      'the evaluated agent — the health projections have no other way to '
      'learn about it', () async {
    const agentId = 'goal-sync';
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [goalIdentity(agentId)]);
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
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => repository.getDueScheduledWakeRecords(any()),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getDueScheduledAgentStates(any()),
    ).thenAnswer((_) async => []);

    final dispatcher = container.read(goalSignalSyncDispatcherProvider);
    await dispatcher.dispatchBatch({'gym-habit'});

    verify(() => updateNotifications.notify({agentId})).called(1);
  });

  test('accepting a revision proposal end-to-end: decision persisted, v2 '
      'minted, head moved, and the signal subscription re-registered from '
      'the NEW criteria', () async {
    const agentId = 'goal-rev';
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => goalIdentity(agentId));
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
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
      ),
    ).thenReturn('run-revision');

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
    when(
      () => repository.getEntity(
        any(that: startsWith('$agentId:spec-v2')),
      ),
    ).thenAnswer(
      (invocation) async => upserted
          .whereType<GoalSpecVersionEntity>()
          .where((v) => v.id == invocation.positionalArguments.first)
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
            'baseVersionId': '$agentId:spec-v1',
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
    expect(result.mutatedEntityId, startsWith('$agentId:spec-v2-'));

    final minted = upserted.whereType<GoalSpecVersionEntity>().singleWhere(
      (v) => v.version == 2,
    );
    expect((minted.criteria as GoalCriterionHabit).targetCount, 4);
    final head = upserted.whereType<GoalSpecHeadEntity>().last;
    expect(head.versionId, minted.id);

    final decision = upserted.whereType<ChangeDecisionEntity>().single;
    expect(decision.verdict, ChangeDecisionVerdict.confirmed);

    // The approved revision is evaluated immediately — no blank health
    // until tomorrow's cadence tick.
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
        reason: any(named: 'reason'),
      ),
    ).called(1);

    // The hook re-registered the subscription from the NEW criteria.
    final subscription =
        verify(() => orchestrator.addSubscription(captureAny())).captured.last
            as AgentSubscription;
    expect(subscription.agentId, agentId);
    expect(subscription.matchEntityIds, {'gym-habit'});
  });

  test('a confirmed revision whose spec cannot be read back logs the '
      'skipped re-registration instead of failing silently', () async {
    const agentId = 'goal-gone';
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => goalIdentity(agentId));
    final logger = container.read(domainLoggerProvider) as MockDomainLogger;
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
    final upserted = <AgentDomainEntity>[];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserted.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => syncService.repository).thenReturn(repository);

    // The head is readable for the mint, then gone for the hook's
    // read-back (e.g. clobbered by a concurrent sync apply).
    var headReads = 0;
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer((
      _,
    ) async {
      headReads++;
      if (headReads > 1) return null;
      return AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      );
    });
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

    final changeSet =
        AgentDomainEntity.changeSet(
              id: 'cs-2',
              agentId: agentId,
              taskId: agentId,
              threadId: 'thread-1',
              runKey: 'run-1',
              status: ChangeSetStatus.pending,
              items: const [
                ChangeItem(
                  toolName: GoalAgentToolNames.proposeGoalRevision,
                  args: {
                    'baseVersionId': '$agentId:spec-v1',
                    'changes': {'cadence': 4},
                    'rationale': 'step it up',
                  },
                  humanSummary: 'Raise the cadence to 4',
                ),
              ],
              createdAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as ChangeSetEntity;
    when(() => repository.getEntity('cs-2')).thenAnswer((_) async => changeSet);

    final orchestrator =
        container.read(wakeOrchestratorProvider) as MockWakeOrchestrator;
    final service = container.read(goalChangeSetConfirmationServiceProvider);
    final result = await service.confirmItem(changeSet, 0);
    expect(result.success, isTrue);

    verify(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'goalRevision',
        message: any(
          named: 'message',
          that: contains('re-registration skipped'),
        ),
      ),
    ).called(1);
    verifyNever(() => orchestrator.addSubscription(any()));
  });

  test('activeGoalNudgesProvider surfaces only ACTIVE ads of goal agents, '
      'newest first, with the goal title attached', () async {
    GoalNudgeEntity nudgeRow(
      String id,
      GoalNudgeStatus status,
      DateTime activatedAt,
    ) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-a',
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
              activatedAt: activatedAt,
            )
            as GoalNudgeEntity;

    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer(
      (_) async => [
        goalIdentity('goal-a'),
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
      ],
    );
    when(
      () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        nudgeRow('ad-old', GoalNudgeStatus.active, DateTime(2026, 8, 8)),
        nudgeRow('ad-new', GoalNudgeStatus.active, DateTime(2026, 8, 10)),
        nudgeRow(
          'ad-snoozed',
          GoalNudgeStatus.active,
          DateTime(2026, 8, 11),
        ).copyWith(
          provenance: const {'snoozedUntil': '2099-08-11T12:00:00.000Z'},
        ),
        nudgeRow('ad-gone', GoalNudgeStatus.dismissed, DateTime(2026, 8, 9)),
      ],
    );
    when(
      () => repository.getEntity(goalSpecHeadId('goal-a')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId('goal-a'),
        agentId: 'goal-a',
        versionId: 'goal-a:spec-v1',
        updatedAt: DateTime(2026, 8, 11),
        vectorClock: null,
      ),
    );
    when(
      () => repository.getEntity('goal-a:spec-v1'),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: 'goal-a:spec-v1',
        agentId: 'goal-a',
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Walk daily',
        statement: 'Walk every day.',
        criteria: const GoalCriterion.habit(
          criterionId: 'walk',
          habitId: 'walk',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 5,
        ),
        createdAt: DateTime(2026, 8, 11),
        vectorClock: null,
      ),
    );

    // Warm the rollout flag and KEEP it alive: the gate reads the
    // stream's latest value, and an autodisposed flag provider would be
    // torn down between reads.
    final flagSub = container.listen(
      configFlagProvider(enableAgentsPageFlag),
      (_, _) {},
    );
    addTearDown(flagSub.close);
    await container.read(configFlagProvider(enableAgentsPageFlag).future);
    final entries = await container.read(activeGoalNudgesProvider.future);
    expect(
      [for (final entry in entries) entry.nudge.id],
      ['ad-new', 'ad-old'],
    );
    expect(entries.first.goalTitle, 'Walk daily');

    // An ad past its staleAt stops rendering even while still `active`.
    when(
      () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        nudgeRow(
          'ad-stale',
          GoalNudgeStatus.active,
          DateTime(2026, 8),
        ).copyWith(staleAt: DateTime(2026, 8, 2)),
      ],
    );
    container.invalidate(activeGoalNudgesProvider);
    expect(await container.read(activeGoalNudgesProvider.future), isEmpty);
  });

  test('goalAgentHealthProvider assembles the latest register verdict, '
      'the report one-liner and the pending-proposal count', () async {
    const agentId = 'goal-h';
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
        title: 'Steps',
        statement: 'Average 10,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 10000,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    GoalProgressEntity register(
      String period,
      double attainment, {
      int? deficit,
      int? buffer,
    }) =>
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, period),
              agentId: agentId,
              periodKey: period,
              trackStatus: attainment >= 0.8
                  ? GoalTrackStatus.onTrack
                  : GoalTrackStatus.atRisk,
              attainment: attainment,
              dataCoverage: 1,
              satisfied: attainment >= 1,
              specVersionId: '$agentId:spec-v1',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
              deficit: deficit,
              buffer: buffer,
            )
            as GoalProgressEntity;
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [
        register('2026-08-08', 1),
        // The latest register carries the rolling-window deficit/buffer.
        register('2026-08-09', 0.64, deficit: 2),
      ],
    );
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentReport(
                id: 'r1',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 8, 9),
                vectorClock: null,
                content: 'body',
                oneLiner: 'Averaging 6.4k of 10k.',
              )
              as AgentReportEntity,
    );
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.changeSet(
              id: 'cs',
              agentId: agentId,
              taskId: agentId,
              threadId: 't',
              runKey: 'r',
              status: ChangeSetStatus.pending,
              items: const [],
              createdAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as ChangeSetEntity,
      ],
    );

    final health = await container.read(
      goalAgentHealthProvider(agentId).future,
    );
    expect(
      health.trackStatus,
      GoalTrackStatus.atRisk,
      reason: 'the LATEST period wins, not the best one',
    );
    expect(health.attainment, 0.64);
    expect(health.reportOneLiner, 'Averaging 6.4k of 10k.');
    expect(health.pendingProposals, 1);
    expect(health.spec?.title, 'Steps');
    // Direction: latest 0.64 vs the prior 1.0 — a drop beyond the deadband.
    expect(health.direction, GoalHealthDirection.down);
    // The latest register's rolling-window deficit/buffer reach the row.
    expect(health.deficit, 2);
    expect(health.buffer, isNull);
  });

  test('goalAgentHealthProvider reports no direction with a single register, '
      'and flat within the deadband', () async {
    const agentId = 'goal-dir';
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
        title: 'Steps',
        statement: 'Average 10,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 10000,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    GoalProgressEntity register(String period, double attainment) =>
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, period),
              agentId: agentId,
              periodKey: period,
              trackStatus: GoalTrackStatus.onTrack,
              attainment: attainment,
              dataCoverage: 1,
              satisfied: true,
              specVersionId: '$agentId:spec-v1',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalProgressEntity;
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer((_) async => []);

    // One register: no comparison, no arrow.
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer((_) async => [register('2026-08-09', 0.9)]);
    var health = await container.read(goalAgentHealthProvider(agentId).future);
    expect(health.direction, isNull);

    // Two registers within the deadband: flat.
    container.invalidate(goalAgentHealthProvider(agentId));
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [register('2026-08-09', 0.9), register('2026-08-08', 0.91)],
    );
    health = await container.read(goalAgentHealthProvider(agentId).future);
    expect(health.direction, GoalHealthDirection.flat);
  });

  test(
    'goalAgentHealthProvider withholds the trend arrow when either '
    'register is insufficient-data — no downward judgment over a gap',
    () async {
      const agentId = 'goal-gap';
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
          title: 'Steps',
          statement: 'Average 10,000 steps per day.',
          criteria: const GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 10000,
          ),
          createdAt: DateTime(2026),
          vectorClock: null,
        ),
      );
      GoalProgressEntity register(
        String period,
        double attainment,
        GoalTrackStatus status,
      ) =>
          AgentDomainEntity.goalProgress(
                id: goalProgressId(agentId, period),
                agentId: agentId,
                periodKey: period,
                trackStatus: status,
                attainment: attainment,
                dataCoverage: status == GoalTrackStatus.insufficientData
                    ? 0.1
                    : 1,
                satisfied: false,
                specVersionId: '$agentId:spec-v1',
                createdAt: DateTime(2026, 8, 9),
                updatedAt: DateTime(2026, 8, 9),
                vectorClock: null,
              )
              as GoalProgressEntity;
      when(
        () => repository.getLatestReport(agentId, 'current'),
      ).thenAnswer((_) async => null);
      when(
        () => repository.getPendingChangeSets(agentId, taskId: agentId),
      ).thenAnswer((_) async => []);

      // Latest register is insufficient-data. Even though its attainment is a
      // full point below the prior register — which WOULD read as a steep
      // decline — no arrow is emitted: the gap must not be judged.
      when(
        () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
      ).thenAnswer(
        (_) async => [
          register('2026-08-09', 0, GoalTrackStatus.insufficientData),
          register('2026-08-08', 1, GoalTrackStatus.onTrack),
        ],
      );
      final health = await container.read(
        goalAgentHealthProvider(agentId).future,
      );
      expect(health.direction, isNull);
    },
  );

  test('goalAgentHealthProvider emits no trend for a calendar-window goal — '
      'attainment resets each period, so a consecutive-register delta is a '
      'boundary reset, not a decline', () async {
    const agentId = 'goal-cal';
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
        statement: 'Gym three times a week.',
        // Calendar week: attainment is within-week and resets Monday.
        criteria: const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'habit-gym',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    GoalProgressEntity register(String period, double attainment) =>
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, period),
              agentId: agentId,
              periodKey: period,
              trackStatus: GoalTrackStatus.onTrack,
              attainment: attainment,
              dataCoverage: 1,
              satisfied: attainment >= 1,
              specVersionId: '$agentId:spec-v1',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalProgressEntity;
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer((_) async => []);

    // Last week finished at 1.0; this week is on pace with one of three at
    // 0.33. Raw subtraction would read "down" — but it is a fresh period.
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [register('2026-W33', 0.33), register('2026-W32', 1)],
    );
    final health = await container.read(
      goalAgentHealthProvider(agentId).future,
    );
    expect(health.direction, isNull);
  });

  test('goalAgentHealthProvider emits a trend for a composite goal only when '
      'every child window is rolling', () async {
    const agentId = 'goal-comp';
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    GoalProgressEntity register(String period, double attainment) =>
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, period),
              agentId: agentId,
              periodKey: period,
              trackStatus: GoalTrackStatus.onTrack,
              attainment: attainment,
              dataCoverage: 1,
              satisfied: true,
              specVersionId: '$agentId:spec-v1',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalProgressEntity;
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [register('2026-08-09', 0.9), register('2026-08-08', 0.6)],
    );

    Future<GoalAgentHealth> healthFor(GoalCriterion criteria) {
      when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v1',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: 'Combined',
          statement: 'Two habits.',
          criteria: criteria,
          createdAt: DateTime(2026),
          vectorClock: null,
        ),
      );
      container.invalidate(goalAgentHealthProvider(agentId));
      return container.read(goalAgentHealthProvider(agentId).future);
    }

    const rollingA = GoalCriterion.habit(
      criterionId: 'a',
      habitId: 'h-a',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 3,
    );
    const rollingB = GoalCriterion.habit(
      criterionId: 'b',
      habitId: 'h-b',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 3,
    );

    // Every composite flavour with all-rolling children is sound → arrow up.
    // (Exercises the allOf / anyOf / atLeastCount arms of the soundness fold.)
    for (final composite in <GoalCriterion>[
      const GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [rollingA, rollingB],
      ),
      const GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [rollingA, rollingB],
      ),
      const GoalCriterion.atLeastCount(
        criterionId: 'root',
        successes: 1,
        criteria: [rollingA, rollingB],
      ),
    ]) {
      final rolling = await healthFor(composite);
      expect(rolling.direction, GoalHealthDirection.up);
    }

    // One CALENDAR child taints the composite → no arrow.
    final mixed = await healthFor(
      const GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'a',
            habitId: 'h-a',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
          GoalCriterion.habit(
            criterionId: 'b',
            habitId: 'h-b',
            window: GoalWindow.calendarWeek(),
            targetCount: 3,
          ),
        ],
      ),
    );
    expect(mixed.direction, isNull);
  });

  test('a failing exposure flush is contained and logged — never an '
      'uncaught async error from a disposed banner', () async {
    when(
      () => repository.getEntity('ad-err'),
    ).thenAnswer((_) async => throw StateError('db closed mid-dispose'));
    final logger = container.read(domainLoggerProvider) as MockDomainLogger;
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);

    container.read(goalNudgeExposureFlushProvider)(
      'ad-err',
      const Duration(seconds: 1),
    );
    await pumpEventQueue();

    verify(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'goalNudgeExposure',
        message: any(named: 'message', that: contains('ad-err')),
      ),
    ).called(1);
  });

  test('the exposure flush provider forwards to the interactions service '
      'fire-and-forget', () async {
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => repository.getEntity('ad-x')).thenAnswer((_) async => null);
    container.read(goalNudgeExposureFlushProvider)(
      'ad-x',
      const Duration(seconds: 2),
    );
    // Unknown id is a no-op inside the service — the provider's job is
    // only to bridge the sync call into a void signature.
    await container
        .read(goalNudgeInteractionsProvider)
        .recordExposure('ad-x', visibleFor: const Duration(seconds: 2));
    verify(() => repository.getEntity('ad-x')).called(greaterThan(0));
  });

  test('health for a goal without a spec head reports nulls instead of '
      'throwing', () async {
    when(
      () => repository.getEntitiesByAgentId('goal-z', type: 'goalProgress'),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getLatestReport('goal-z', 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getPendingChangeSets('goal-z', taskId: 'goal-z'),
    ).thenAnswer((_) async => []);
    final health = await container.read(
      goalAgentHealthProvider('goal-z').future,
    );
    expect(health.trackStatus, isNull);
    expect(health.spec, isNull);
    expect(health.pendingProposals, 0);
  });

  test('a standing report older than the active spec version is withheld '
      '— its one-liner describes the superseded goal', () async {
    const agentId = 'goal-old-report';
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v2',
        updatedAt: DateTime(2026, 8, 10),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v2')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v2',
        agentId: agentId,
        version: 2,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps, revised',
        statement: 'Average 8,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 8000,
        ),
        createdAt: DateTime(2026, 8, 10, 9),
        vectorClock: null,
      ),
    );
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentReport(
                id: 'r-old',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 8, 9),
                vectorClock: null,
                content: 'body',
                oneLiner: 'Chasing 10k — two days behind.',
              )
              as AgentReportEntity,
    );
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer((_) async => []);

    final health = await container.read(
      goalAgentHealthProvider(agentId).future,
    );
    expect(
      health.reportOneLiner,
      isNull,
      reason: 'the old goal report must not caption the revised goal',
    );

    // Spec-version provenance outranks the timestamp: a v2 report with a
    // skewed EARLIER clock still shows.
    when(() => repository.getLatestReport(agentId, 'current')).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentReport(
                id: 'r-v2-skewed',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 8, 8),
                vectorClock: null,
                content: 'body',
                oneLiner: 'Fresh verdict, slow clock.',
                provenance: const {'specVersionId': '$agentId:spec-v2'},
              )
              as AgentReportEntity,
    );
    container.invalidate(goalAgentHealthProvider(agentId));
    final skewed = await container.read(
      goalAgentHealthProvider(agentId).future,
    );
    expect(skewed.reportOneLiner, 'Fresh verdict, slow clock.');
  });

  test('health ignores progress registers written for superseded spec '
      'versions', () async {
    const agentId = 'goal-rev';
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v2',
        updatedAt: DateTime(2026, 8, 10),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v2')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v2',
        agentId: agentId,
        version: 2,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps, revised',
        statement: 'Average 8,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 8000,
        ),
        createdAt: DateTime(2026, 8, 10),
        vectorClock: null,
      ),
    );
    GoalProgressEntity register({
      required String period,
      required String specVersionId,
      required double attainment,
      required GoalTrackStatus trackStatus,
    }) =>
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, period),
              agentId: agentId,
              periodKey: period,
              trackStatus: trackStatus,
              attainment: attainment,
              dataCoverage: 1,
              satisfied: false,
              specVersionId: specVersionId,
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalProgressEntity;
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [
        // The OLD goal's verdict has the newest period key — without the
        // spec-version filter it would win and misreport the revised goal.
        register(
          period: '2026-08-10',
          specVersionId: '$agentId:spec-v1',
          attainment: 0.2,
          trackStatus: GoalTrackStatus.offTrack,
        ),
        register(
          period: '2026-08-09',
          specVersionId: '$agentId:spec-v2',
          attainment: 0.9,
          trackStatus: GoalTrackStatus.onTrack,
        ),
      ],
    );
    when(
      () => repository.getLatestReport(agentId, 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getPendingChangeSets(agentId, taskId: agentId),
    ).thenAnswer((_) async => []);

    final health = await container.read(
      goalAgentHealthProvider(agentId).future,
    );
    expect(health.trackStatus, GoalTrackStatus.onTrack);
    expect(health.attainment, 0.9);
    expect(health.spec?.version, 2);
  });

  test('a rendered banner is re-evaluated at its staleness deadline, with '
      'no agent notification needed', () {
    final start = DateTime(2026, 8, 10, 12);
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [goalIdentity('goal-a')]);
        when(
          () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.goalNudge(
                  id: 'ad-deadline',
                  agentId: 'goal-a',
                  status: GoalNudgeStatus.active,
                  brief: const GoalNudgeBrief(
                    headline: 'h',
                    tone: GoalNudgeTone.nudge,
                    animation: GoalBannerAnimation.steady,
                  ),
                  briefDigest: 'd',
                  createdAt: start,
                  updatedAt: start,
                  vectorClock: null,
                  staleAt: start.add(const Duration(hours: 1)),
                )
                as GoalNudgeEntity,
          ],
        );

        // Keep the flag and the banner provider alive: the deadline timer
        // dies with the provider on autodispose.
        final flagSub = container.listen(
          configFlagProvider(enableAgentsPageFlag),
          (_, _) {},
        );
        addTearDown(flagSub.close);
        final sub = container.listen(activeGoalNudgesProvider, (_, _) {});
        addTearDown(sub.close);
        async
          ..flushMicrotasks()
          // The flag stream's first value lands on the event queue, and
          // the gated provider rebuilds behind it.
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(
          container.read(activeGoalNudgesProvider).value,
          hasLength(1),
          reason: 'fresh banner renders',
        );

        // Nothing else happens — the deadline alone must remove it.
        async
          ..elapse(const Duration(hours: 1, seconds: 1))
          ..flushMicrotasks();
        expect(
          container.read(activeGoalNudgesProvider).value,
          isEmpty,
          reason: 'the staleness contract holds without an external event',
        );
      });
    });
  });

  test('a local snooze deadline removes itself exactly on time', () {
    final start = DateTime.utc(2026, 8, 11, 12);
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        container
            .read(locallySnoozedNudgeDeadlinesProvider.notifier)
            .add('ad-1', start.add(const Duration(minutes: 15)));

        expect(container.read(locallySnoozedNudgeDeadlinesProvider), {
          'ad-1': start.add(const Duration(minutes: 15)),
        });
        async.elapse(const Duration(minutes: 15));
        expect(container.read(locallySnoozedNudgeDeadlinesProvider), isEmpty);
      });
    });
  });

  test('a snoozed banner automatically returns at its deadline without an '
      'agent notification', () {
    final start = DateTime.utc(2026, 8, 10, 12);
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [goalIdentity('goal-a')]);
        when(
          () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.goalNudge(
                  id: 'ad-snoozed',
                  agentId: 'goal-a',
                  status: GoalNudgeStatus.active,
                  brief: const GoalNudgeBrief(
                    headline: 'h',
                    tone: GoalNudgeTone.nudge,
                    animation: GoalBannerAnimation.steady,
                  ),
                  briefDigest: 'd',
                  createdAt: start,
                  updatedAt: start,
                  vectorClock: null,
                  staleAt: start.add(const Duration(days: 1)),
                  provenance: {
                    'snoozedUntil': start
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                  },
                )
                as GoalNudgeEntity,
          ],
        );

        final flagSub = container.listen(
          configFlagProvider(enableAgentsPageFlag),
          (_, _) {},
        );
        addTearDown(flagSub.close);
        final sub = container.listen(activeGoalNudgesProvider, (_, _) {});
        addTearDown(sub.close);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(container.read(activeGoalNudgesProvider).value, isEmpty);

        async
          ..elapse(const Duration(hours: 1, seconds: 1))
          ..flushMicrotasks();
        expect(
          container.read(activeGoalNudgesProvider).value?.single.nudge.id,
          'ad-snoozed',
        );
      });
    });
  });

  test('a day-dismissed banner automatically returns at local midnight', () {
    final start = DateTime(2026, 8, 10, 23, 30);
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [goalIdentity('goal-a')]);
        when(
          () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.goalNudge(
                  id: 'ad-dismissed-today',
                  agentId: 'goal-a',
                  status: GoalNudgeStatus.active,
                  brief: const GoalNudgeBrief(
                    headline: 'h',
                    tone: GoalNudgeTone.nudge,
                    animation: GoalBannerAnimation.steady,
                  ),
                  briefDigest: 'd',
                  createdAt: start,
                  updatedAt: start,
                  vectorClock: null,
                  staleAt: start.add(const Duration(days: 1)),
                  dismissedForDayAt: start.toUtc(),
                )
                as GoalNudgeEntity,
          ],
        );

        final flagSub = container.listen(
          configFlagProvider(enableAgentsPageFlag),
          (_, _) {},
        );
        addTearDown(flagSub.close);
        final sub = container.listen(activeGoalNudgesProvider, (_, _) {});
        addTearDown(sub.close);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(container.read(activeGoalNudgesProvider).value, isEmpty);

        async
          ..elapse(const Duration(minutes: 31))
          ..flushMicrotasks();
        expect(
          container.read(activeGoalNudgesProvider).value?.single.nudge.id,
          'ad-dismissed-today',
        );
      });
    });
  });

  test('a late-synced banner from a superseded spec version is fenced by '
      'its own provenance', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [goalIdentity('goal-a')]);
    when(() => repository.getEntity(goalSpecHeadId('goal-a'))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId('goal-a'),
        agentId: 'goal-a',
        versionId: 'goal-a:spec-v2-aa',
        updatedAt: DateTime(2026, 8, 10),
        vectorClock: null,
      ),
    );
    // The head must RESOLVE — a dangling pointer is not a live spec.
    when(() => repository.getEntity('goal-a:spec-v2-aa')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: 'goal-a:spec-v2-aa',
        agentId: 'goal-a',
        version: 2,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps',
        statement: 'x',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 8000,
        ),
        createdAt: DateTime(2026, 8, 10),
        vectorClock: null,
      ),
    );
    GoalNudgeEntity row(String id, Map<String, String> provenance) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-a',
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
              provenance: provenance,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId('goal-a', type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        row('ad-old-spec', {'specVersionId': 'goal-a:spec-v1'}),
        row('ad-current', {'specVersionId': 'goal-a:spec-v2-aa'}),
        row('ad-legacy', const {}),
      ],
    );

    final flagSub = container.listen(
      configFlagProvider(enableAgentsPageFlag),
      (_, _) {},
    );
    addTearDown(flagSub.close);
    await container.read(configFlagProvider(enableAgentsPageFlag).future);
    final entries = await container.read(activeGoalNudgesProvider.future);
    expect(
      {for (final e in entries) e.nudge.id},
      {'ad-current', 'ad-legacy'},
      reason:
          'the old-spec banner is fenced; legacy rows without the '
          'field still render',
    );

    // With NO live head, tagged banners have nothing to validate against
    // and are hidden; only the untagged legacy row remains.
    when(
      () => repository.getEntity(goalSpecHeadId('goal-a')),
    ).thenAnswer((_) async => null);
    container.invalidate(activeGoalNudgesProvider);
    final headless = await container.read(activeGoalNudgesProvider.future);
    expect(
      {for (final e in headless) e.nudge.id},
      {'ad-legacy'},
    );
  });

  test('goalNudgeHistoryProvider lists only terminal outcomes, newest '
      'first — pipeline rows and failures stay internal', () async {
    GoalNudgeEntity row(String id, GoalNudgeStatus status, int day) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-h',
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8, day),
              updatedAt: DateTime(2026, 8, day),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId('goal-h', type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        row('ad-dismissed', GoalNudgeStatus.dismissed, 3),
        row('ad-retired', GoalNudgeStatus.retired, 5),
        row('ad-active', GoalNudgeStatus.active, 6),
        row('ad-draft', GoalNudgeStatus.draft, 7),
        row('ad-failed', GoalNudgeStatus.failed, 8),
      ],
    );
    final history = await container.read(
      goalNudgeHistoryProvider('goal-h').future,
    );
    expect(
      [for (final n in history) n.id],
      ['ad-retired', 'ad-dismissed'],
    );
  });

  test('goalNudgeHistoryProvider orders expired/superseded rows by their '
      'OWN outcome stamp, falling back to updatedAt when the stamp is '
      'missing — proves each switch arm, not just the sort', () async {
    GoalNudgeEntity row({
      required String id,
      required GoalNudgeStatus status,
      required DateTime updatedAt,
      DateTime? expiredAt,
      DateTime? supersededAt,
    }) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-h2',
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8),
              updatedAt: updatedAt,
              vectorClock: null,
              expiredAt: expiredAt,
              supersededAt: supersededAt,
            )
            as GoalNudgeEntity;

    when(
      () => repository.getEntitiesByAgentId('goal-h2', type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        // expiredAt PRESENT but far in the past — updatedAt (bumped by a
        // later exposure flush) must NOT leak in; the expiredAt arm wins.
        row(
          id: 'ad-expired-stamped',
          status: GoalNudgeStatus.expired,
          updatedAt: DateTime(2026, 8, 20),
          expiredAt: DateTime(2026, 8, 5),
        ),
        // expiredAt MISSING — falls back to updatedAt, landing it ahead of
        // the stamped row above.
        row(
          id: 'ad-expired-fallback',
          status: GoalNudgeStatus.expired,
          updatedAt: DateTime(2026, 8, 12),
        ),
        // supersededAt PRESENT, older than its updatedAt.
        row(
          id: 'ad-superseded-stamped',
          status: GoalNudgeStatus.superseded,
          updatedAt: DateTime(2026, 8, 18),
          supersededAt: DateTime(2026, 8, 3),
        ),
        // supersededAt MISSING — falls back to updatedAt, the newest of
        // all four.
        row(
          id: 'ad-superseded-fallback',
          status: GoalNudgeStatus.superseded,
          updatedAt: DateTime(2026, 8, 25),
        ),
      ],
    );

    final history = await container.read(
      goalNudgeHistoryProvider('goal-h2').future,
    );
    // Newest outcomeAt first: 08-25 (superseded, updatedAt fallback),
    // 08-12 (expired, updatedAt fallback), 08-05 (expired, expiredAt
    // stamp), 08-03 (superseded, supersededAt stamp) — each status's own
    // stamp is honored over its (later) updatedAt, and each fallback
    // reads updatedAt only when its own stamp is null.
    expect(
      [for (final n in history) n.id],
      [
        'ad-superseded-fallback',
        'ad-expired-fallback',
        'ad-expired-stamped',
        'ad-superseded-stamped',
      ],
    );
  });

  test('activeGoalAgentsProvider lists only goal-kind identities', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer(
      (_) async => [
        goalIdentity('goal-a'),
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
      ],
    );
    final agents = await container.read(activeGoalAgentsProvider.future);
    expect([for (final a in agents) a.agentId], ['goal-a']);
  });

  test('the banner provider returns nothing while the rollout flag is '
      'off', () async {
    final gated = ProviderContainer(
      overrides: [
        configFlagProvider(
          enableAgentsPageFlag,
        ).overrideWith((ref) => Stream.value(false)),
        agentServiceProvider.overrideWithValue(agentService),
        agentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(gated.dispose);
    final flagSub = gated.listen(
      configFlagProvider(enableAgentsPageFlag),
      (_, _) {},
    );
    addTearDown(flagSub.close);
    await gated.read(configFlagProvider(enableAgentsPageFlag).future);
    expect(await gated.read(activeGoalNudgesProvider.future), isEmpty);
    verifyNever(
      () => agentService.listAgents(lifecycle: any(named: 'lifecycle')),
    );
  });
}
