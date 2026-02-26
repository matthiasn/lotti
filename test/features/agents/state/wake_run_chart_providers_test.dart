import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  group('templateWakeRunTimeSeriesProvider', () {
    late MockAgentRepository mockRepository;

    setUp(() {
      mockRepository = MockAgentRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    }

    test('returns computed time series from repository data', () async {
      final day1 = DateTime(2024, 3, 15);
      final day2 = DateTime(2024, 3, 16);

      when(() => mockRepository.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [
                makeTestWakeRun(
                  runKey: 'r1',
                  status: 'completed',
                  createdAt: day1,
                  templateId: kTestTemplateId,
                  templateVersionId: 'v1',
                  startedAt: day1,
                  completedAt: day1.add(const Duration(seconds: 10)),
                ),
                makeTestWakeRun(
                  runKey: 'r2',
                  status: 'failed',
                  createdAt: day2,
                  templateId: kTestTemplateId,
                  templateVersionId: 'v1',
                  startedAt: day2,
                  completedAt: day2.add(const Duration(seconds: 5)),
                ),
              ]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateWakeRunTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, hasLength(2));
      expect(result.dailyBuckets[0].successCount, 1);
      expect(result.dailyBuckets[1].failureCount, 1);
      expect(result.versionBuckets, hasLength(1));
      expect(result.versionBuckets.first.totalRuns, 2);
    });

    test('returns empty time series when no runs exist', () async {
      when(() => mockRepository.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateWakeRunTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, isEmpty);
      expect(result.versionBuckets, isEmpty);
    });
  });

  group('templateTaskResolutionTimeSeriesProvider', () {
    late MockAgentRepository mockRepository;
    late MockAgentTemplateService mockTemplateService;
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockRepository = MockAgentRepository();
      mockTemplateService = MockAgentTemplateService();
      mockJournalDb = MockJournalDb();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          journalDbProvider.overrideWithValue(mockJournalDb),
        ],
      );
    }

    test('computes MTTR from agent creation to task resolution', () async {
      final agentCreated = DateTime(2024, 3, 15, 10);
      final taskResolved = DateTime(2024, 3, 15, 14); // 4 hours later

      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        createdAt: agentCreated,
      );

      when(() => mockTemplateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [agent]);

      when(() => mockRepository.getLinksFrom('agent-1', type: 'agent_task'))
          .thenAnswer(
        (_) async => [
          model.AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-1',
            createdAt: agentCreated,
            updatedAt: agentCreated,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockJournalDb.journalEntityById('task-1'))
          .thenAnswer((_) async => _makeTask(
                id: 'task-1',
                createdAt: agentCreated,
                statusHistory: [
                  TaskStatus.open(
                    id: uuid.v1(),
                    createdAt: agentCreated,
                    utcOffset: 0,
                  ),
                  TaskStatus.inProgress(
                    id: uuid.v1(),
                    createdAt: agentCreated.add(const Duration(hours: 1)),
                    utcOffset: 0,
                  ),
                  TaskStatus.done(
                    id: uuid.v1(),
                    createdAt: taskResolved,
                    utcOffset: 0,
                  ),
                ],
              ));

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateTaskResolutionTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.resolvedCount, 1);
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 4),
      );
    });

    test('returns empty when no agents exist for template', () async {
      when(() => mockTemplateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateTaskResolutionTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, isEmpty);
    });

    test('handles unresolved tasks (no DONE/REJECTED status)', () async {
      final agentCreated = DateTime(2024, 3, 15, 10);

      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        createdAt: agentCreated,
      );

      when(() => mockTemplateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [agent]);

      when(() => mockRepository.getLinksFrom('agent-1', type: 'agent_task'))
          .thenAnswer(
        (_) async => [
          model.AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-1',
            createdAt: agentCreated,
            updatedAt: agentCreated,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockJournalDb.journalEntityById('task-1'))
          .thenAnswer((_) async => _makeTask(
                id: 'task-1',
                createdAt: agentCreated,
                statusHistory: [
                  TaskStatus.open(
                    id: uuid.v1(),
                    createdAt: agentCreated,
                    utcOffset: 0,
                  ),
                  TaskStatus.inProgress(
                    id: uuid.v1(),
                    createdAt: agentCreated.add(const Duration(hours: 1)),
                    utcOffset: 0,
                  ),
                ],
              ));

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateTaskResolutionTimeSeriesProvider(kTestTemplateId).future,
      );

      // Unresolved task should not produce any daily buckets
      expect(result.dailyBuckets, isEmpty);
    });

    test('handles rejected tasks as resolved', () async {
      final agentCreated = DateTime(2024, 3, 15, 10);
      final taskRejected = DateTime(2024, 3, 16, 10); // 24 hours later

      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        createdAt: agentCreated,
      );

      when(() => mockTemplateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [agent]);

      when(() => mockRepository.getLinksFrom('agent-1', type: 'agent_task'))
          .thenAnswer(
        (_) async => [
          model.AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-1',
            createdAt: agentCreated,
            updatedAt: agentCreated,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockJournalDb.journalEntityById('task-1'))
          .thenAnswer((_) async => _makeTask(
                id: 'task-1',
                createdAt: agentCreated,
                statusHistory: [
                  TaskStatus.open(
                    id: uuid.v1(),
                    createdAt: agentCreated,
                    utcOffset: 0,
                  ),
                  TaskStatus.rejected(
                    id: uuid.v1(),
                    createdAt: taskRejected,
                    utcOffset: 0,
                  ),
                ],
              ));

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateTaskResolutionTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.resolvedCount, 1);
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 24),
      );
    });

    test('skips non-task journal entities', () async {
      final agentCreated = DateTime(2024, 3, 15, 10);

      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        createdAt: agentCreated,
      );

      when(() => mockTemplateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [agent]);

      when(() => mockRepository.getLinksFrom('agent-1', type: 'agent_task'))
          .thenAnswer(
        (_) async => [
          model.AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'not-a-task',
            createdAt: agentCreated,
            updatedAt: agentCreated,
            vectorClock: null,
          ),
        ],
      );

      // Return null (entity not found)
      when(() => mockJournalDb.journalEntityById('not-a-task'))
          .thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateTaskResolutionTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, isEmpty);
    });
  });
}

/// Helper to create a minimal [Task] journal entity for testing.
Task _makeTask({
  required String id,
  required DateTime createdAt,
  required List<TaskStatus> statusHistory,
}) {
  return JournalEntity.task(
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
    ),
    data: TaskData(
      status: statusHistory.last,
      dateFrom: createdAt,
      dateTo: createdAt,
      statusHistory: statusHistory,
      title: 'Test Task',
    ),
  ) as Task;
}
