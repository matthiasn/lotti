import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late ProviderContainer container;

  setUp(() {
    syncStream = StreamController<Set<String>>.broadcast();
    addTearDown(syncStream.close);
    agentService = MockAgentService();
    repository = MockAgentRepository();
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
        journalDbProvider.overrideWithValue(MockJournalDb()),
        agentRepositoryProvider.overrideWithValue(repository),
        agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
        agentServiceProvider.overrideWithValue(agentService),
        wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
        updateNotificationsProvider.overrideWithValue(updateNotifications),
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

  test(
    'the sync listener starts on construction and feeds the dispatcher',
    () async {
      container.read(goalSignalSyncListenerProvider);
      syncStream.add({'anything'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Empty agent list → no dispatch, but the listener consumed the batch
      // (listAgents was hit through the provider-wired dispatcher).
      verify(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).called(1);
    },
  );
}
