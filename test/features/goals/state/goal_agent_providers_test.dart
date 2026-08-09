import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_runtime_maintenance.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
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

    container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(journalDb),
        agentRepositoryProvider.overrideWithValue(repository),
        agentSyncServiceProvider.overrideWithValue(syncService),
        agentServiceProvider.overrideWithValue(agentService),
        wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
        updateNotificationsProvider.overrideWithValue(updateNotifications),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
      ],
    );
    addTearDown(container.dispose);
  });

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
}
