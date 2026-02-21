import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(orchestrator),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(taskAgentServiceProvider);

      expect(service, isNotNull);
      expect(service.agentService, same(mockAgentService));
      expect(service.repository, same(mockRepository));
      expect(service.orchestrator, same(orchestrator));
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
  });
}
