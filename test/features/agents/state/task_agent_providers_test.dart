import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('taskAgentServiceProvider', () {
    test('creates TaskAgentService with correct dependencies', () {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final wakeQueue = WakeQueue();
      final wakeRunner = WakeRunner();
      final orchestrator = WakeOrchestrator(
        repository: mockRepository,
        queue: wakeQueue,
        runner: wakeRunner,
      );

      final mockSyncService = MockAgentSyncService();

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(orchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(taskAgentServiceProvider);

      expect(service, isNotNull);
      expect(service.agentService, same(mockAgentService));
      expect(service.repository, same(mockRepository));
      expect(service.orchestrator, same(orchestrator));
      expect(service.syncService, same(mockSyncService));
    });
  });

  group('taskAgentProvider', () {
    test('returns identity when agent exists for task', () async {
      final mockService = MockTaskAgentService();
      const taskId = 'task-123';
      final identity = makeTestIdentity(id: 'agent-for-task');

      when(() => mockService.getTaskAgentForTask(taskId))
          .thenAnswer((_) async => identity);

      final container = ProviderContainer(
        overrides: [
          taskAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(taskAgentProvider(taskId).future);

      expect(result, equals(identity));
      verify(() => mockService.getTaskAgentForTask(taskId)).called(1);
    });

    test('returns null when no agent exists for task', () async {
      final mockService = MockTaskAgentService();
      const taskId = 'task-no-agent';

      when(() => mockService.getTaskAgentForTask(taskId))
          .thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          taskAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(taskAgentProvider(taskId).future);

      expect(result, isNull);
      verify(() => mockService.getTaskAgentForTask(taskId)).called(1);
    });

    test('propagates error from service', () async {
      final mockService = MockTaskAgentService();
      const taskId = 'task-error';

      when(() => mockService.getTaskAgentForTask(taskId))
          .thenAnswer((_) async => throw Exception('DB error'));

      final container = ProviderContainer(
        overrides: [
          taskAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      // Use a Completer to capture the first error state from the provider.
      final completer = Completer<AsyncValue<AgentDomainEntity?>>();
      final sub = container.listen(
        taskAgentProvider(taskId),
        (_, next) {
          if (!completer.isCompleted && (next.hasValue || next.hasError)) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final result = await completer.future;
      expect(result.hasError, isTrue);
      expect(result.error, isA<Exception>());
    });

    test('returns different results for different task IDs', () async {
      final mockService = MockTaskAgentService();
      const taskIdA = 'task-a';
      const taskIdB = 'task-b';
      final identityA = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final identityB = makeTestIdentity(id: 'agent-b', agentId: 'agent-b');

      when(() => mockService.getTaskAgentForTask(taskIdA))
          .thenAnswer((_) async => identityA);
      when(() => mockService.getTaskAgentForTask(taskIdB))
          .thenAnswer((_) async => identityB);

      final container = ProviderContainer(
        overrides: [
          taskAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final resultA = await container.read(taskAgentProvider(taskIdA).future);
      final resultB = await container.read(taskAgentProvider(taskIdB).future);

      expect(resultA, equals(identityA));
      expect(resultB, equals(identityB));
      expect(resultA, isNot(equals(resultB)));
    });
  });
}
