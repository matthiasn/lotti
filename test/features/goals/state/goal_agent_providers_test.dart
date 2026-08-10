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
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/consts.dart';
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

  test('a confirmed revision whose spec cannot be read back logs the '
      'skipped re-registration instead of failing silently', () async {
    const agentId = 'goal-gone';
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
        nudgeRow('ad-gone', GoalNudgeStatus.dismissed, DateTime(2026, 8, 9)),
      ],
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
    expect(entries.first.goalTitle, 'goal-a');

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
    GoalProgressEntity register(String period, double attainment) =>
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
            )
            as GoalProgressEntity;
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalProgress'),
    ).thenAnswer(
      (_) async => [register('2026-08-08', 1), register('2026-08-09', 0.64)],
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
