import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('taskOneLinerProvider', () {
    late MockAgentRepository mockRepository;

    setUp(() {
      mockRepository = MockAgentRepository();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider.overrideWith(
            (ref, agentId) => const Stream<Set<String>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns oneLiner when agent report has one', () async {
      const taskId = 'task-123';
      const expectedOneLiner = 'Implementing auth flow with OAuth2';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer(
        (_) async => {
          taskId: AgentReportEntity(
            id: 'report-1',
            agentId: 'agent-1',
            scope: 'current',
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            content: 'Full report content',
            oneLiner: expectedOneLiner,
          ),
        },
      );

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, expectedOneLiner);
    });

    test('returns null when agent report has no oneLiner', () async {
      const taskId = 'task-456';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer(
        (_) async => {
          taskId: AgentReportEntity(
            id: 'report-2',
            agentId: 'agent-2',
            scope: 'current',
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            content: 'Full report content',
          ),
        },
      );

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('returns null when no agent report exists for task', () async {
      const taskId = 'task-789';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer((_) async => const {});

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('returns null when oneLiner is empty', () async {
      const taskId = 'task-empty';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer(
        (_) async => {
          taskId: AgentReportEntity(
            id: 'report-3',
            agentId: 'agent-3',
            scope: 'current',
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            content: 'Full report content',
            oneLiner: '',
          ),
        },
      );

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('returns null when oneLiner is only whitespace', () async {
      const taskId = 'task-whitespace';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer(
        (_) async => {
          taskId: AgentReportEntity(
            id: 'report-4',
            agentId: 'agent-4',
            scope: 'current',
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            content: 'Full report content',
            oneLiner: '   ',
          ),
        },
      );

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('trims whitespace from oneLiner', () async {
      const taskId = 'task-trim';

      when(
        () => mockRepository.getLatestTaskReportsForTaskIds([taskId]),
      ).thenAnswer(
        (_) async => {
          taskId: AgentReportEntity(
            id: 'report-5',
            agentId: 'agent-5',
            scope: 'current',
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            content: 'Full report content',
            oneLiner: '  Building REST API endpoints  ',
          ),
        },
      );

      final container = createContainer();
      final result = await container.read(
        taskOneLinerProvider(taskId).future,
      );

      expect(result, 'Building REST API endpoints');
    });
  });
}
