// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

// Mock for TaskProgressRepository
class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {
  @override
  TaskProgressState getTaskProgress({
    required Map<String, TimeRange> timeRanges,
    Duration? estimate,
  }) {
    final progress = calculateUnionDuration(timeRanges.values.toList());
    return TaskProgressState(
      progress: progress,
      estimate: estimate ?? Duration.zero,
    );
  }
}

// Mock for PersistenceLogic
class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Mock classes for parameters
class FakeId extends Mock {}

// Create real implementations rather than mocks that can cause test issues
class TestTaskProgressState implements TaskProgressState {
  TestTaskProgressState(this._progress, {Duration? estimate})
    : _estimate = estimate ?? Duration.zero;
  final Duration _progress;
  final Duration _estimate;

  @override
  Duration get progress => _progress;

  @override
  Duration get estimate => _estimate;

  // Skip implementation of copyWith since we don't use it in tests
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #copyWith) {
      return null;
    }
    return super.noSuchMethod(invocation);
  }

  @override
  String toString() =>
      'TestTaskProgressState(progress: $_progress, estimate: $_estimate)';
}

/// Test helper to build a ProviderContainer with task progress overrides
class TestContainerBuilder {
  TestContainerBuilder(this._mockTaskProgressRepository);

  final TaskProgressRepository _mockTaskProgressRepository;
  final _progressOverrides = <String, TaskProgressState?>{};

  void setTaskProgress(String taskId, Duration? progress) {
    final progressState = progress != null
        ? TestTaskProgressState(progress)
        : null;
    _progressOverrides[taskId] = progressState;
  }

  ProviderContainer build() {
    return ProviderContainer(
      overrides: [
        taskProgressRepositoryProvider.overrideWithValue(
          _mockTaskProgressRepository,
        ),
      ],
    );
  }

  Ref getRef(ProviderContainer container) {
    return container.read(testRefProvider);
  }
}

void main() {
  const taskId = 'task-123';
  final creationDate = DateTime(2023);

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeId());
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String>{});
    registerFallbackValue(<String, TimeRange>{});
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      const AiResponseData(
        model: 'test-model',
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
      ),
    );
    registerFallbackValue(DateTime(2024, 3, 15, 10, 30));
    registerFallbackValue(
      Metadata(
        id: 'fake-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        dateFrom: DateTime(2023),
        dateTo: DateTime(2023),
        starred: false,
        flag: EntryFlag.none,
      ),
    );
    registerFallbackValue(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'fake-entry',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
          flag: EntryFlag.none,
        ),
        entryText: const EntryText(plainText: 'fake'),
      ),
    );
  });

  group('AiInputRepository', () {
    late MockJournalDb mockDb;
    late MockTaskProgressRepository mockTaskProgressRepository;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockProjectRepository mockProjectRepository;
    late MockAgentRepository mockAgentRepository;
    late TestContainerBuilder containerBuilder;
    late ProviderContainer container;
    late AiInputRepository repository;

    setUp(() {
      mockDb = MockJournalDb();
      mockTaskProgressRepository = MockTaskProgressRepository();
      mockPersistenceLogic = MockPersistenceLogic();
      mockProjectRepository = MockProjectRepository();
      mockAgentRepository = MockAgentRepository();
      containerBuilder = TestContainerBuilder(mockTaskProgressRepository);

      // Register function for service locator
      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      // Set initial value to null
      containerBuilder.setTaskProgress(taskId, null);

      // Build container and get ref
      container = containerBuilder.build();
      final ref = containerBuilder.getRef(container);
      repository = AiInputRepository(
        ref,
        taskSummaryResolver: TaskSummaryResolver(null),
        projectRepository: mockProjectRepository,
        agentRepository: mockAgentRepository,
      );

      // Set default mock for taskProgressRepository if not overridden in tests
      when(
        () => mockTaskProgressRepository.getTaskProgressData(
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => (null, <String, TimeRange>{}));

      // Set default return value for journalEntityById to avoid null subtype errors
      when(() => mockDb.journalEntityById(any())).thenAnswer((_) async => null);
      when(
        () => mockDb.getLinkedEntities(any()),
      ).thenAnswer((_) async => <JournalEntity>[]);
      when(
        () => mockProjectRepository.getProjectForTask(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockProjectRepository.getTasksForProject(any()),
      ).thenAnswer((_) async => <Task>[]);
      when(
        () => mockAgentRepository.getLatestProjectReportForProjectId(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
      ).thenAnswer((_) async => <String, AgentReportEntity>{});
      when(
        () => mockDb.getBulkLinkedEntities(any()),
      ).thenAnswer((_) async => <String, List<JournalEntity>>{});
    });

    tearDown(() {
      container.dispose();
      getIt
        ..unregister<JournalDb>()
        ..unregister<PersistenceLogic>();
    });

    test('generate returns null when entity is not a Task', () async {
      // Arrange
      when(() => mockDb.journalEntityById(taskId)).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: ''),
        ),
      );

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNull);
      verify(() => mockDb.journalEntityById(taskId)).called(1);
    });

    group('buildProjectContextJsonForTask', () {
      final projectDate = DateTime(2024, 3, 15, 10, 30);
      final project =
          JournalEntity.project(
                meta: Metadata(
                  id: 'project-123',
                  createdAt: projectDate,
                  updatedAt: projectDate,
                  dateFrom: projectDate,
                  dateTo: projectDate,
                  categoryId: 'cat-123',
                ),
                data: ProjectData(
                  title: 'Agentic Architecture',
                  status: ProjectStatus.active(
                    id: 'project-status-1',
                    createdAt: projectDate,
                    utcOffset: 60,
                  ),
                  dateFrom: projectDate,
                  dateTo: projectDate,
                  targetDate: projectDate.add(const Duration(days: 7)),
                ),
              )
              as ProjectEntry;

      test(
        'returns project metadata plus latest full project report',
        () async {
          final report =
              AgentDomainEntity.agentReport(
                    id: 'project-report-1',
                    agentId: 'project-agent-1',
                    scope: 'current',
                    createdAt: projectDate,
                    vectorClock: null,
                    tldr: 'Project is focused on wake-cycle context quality.',
                    content:
                        '## Project Report\nFull project context goes here.',
                  )
                  as AgentReportEntity;
          when(
            () => mockProjectRepository.getProjectForTask(taskId),
          ).thenAnswer((_) async => project);
          when(
            () => mockAgentRepository.getLatestProjectReportForProjectId(
              'project-123',
            ),
          ).thenAnswer((_) async => report);

          final result = await repository.buildProjectContextJsonForTask(
            taskId,
          );
          final decoded = jsonDecode(result) as Map<String, dynamic>;

          expect(decoded['project'], isA<Map<String, dynamic>>());
          expect(
            decoded['project'],
            containsPair('title', 'Agentic Architecture'),
          );
          expect(decoded['project'], containsPair('status', 'ACTIVE'));
          expect(decoded['project'], containsPair('categoryId', 'cat-123'));
          expect(
            decoded['latestProjectAgentReport'],
            containsPair(
              'tldr',
              'Project is focused on wake-cycle context quality.',
            ),
          );
          expect(
            decoded['latestProjectAgentReport'],
            containsPair(
              'content',
              '## Project Report\nFull project context goes here.',
            ),
          );
        },
      );

      test('returns empty object when task has no parent project', () async {
        final result = await repository.buildProjectContextJsonForTask(taskId);

        expect(result, '{}');
        verify(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).called(1);
        verifyNever(
          () => mockAgentRepository.getLatestProjectReportForProjectId(any()),
        );
      });

      test('returns empty object when project has no current report', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => project);

        final result = await repository.buildProjectContextJsonForTask(taskId);

        expect(result, '{}');
        verify(
          () => mockAgentRepository.getLatestProjectReportForProjectId(
            'project-123',
          ),
        ).called(1);
      });

      test('returns empty object when project lookup throws', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenThrow(Exception('boom'));

        final result = await repository.buildProjectContextJsonForTask(taskId);

        expect(result, '{}');
      });

      test('returns empty object when agentRepository is null', () async {
        final ref = container.read(testRefProvider);
        final repoWithoutAgent = AiInputRepository(
          ref,
          taskSummaryResolver: TaskSummaryResolver(null),
          projectRepository: mockProjectRepository,
        );
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => project);

        final result = await repoWithoutAgent.buildProjectContextJsonForTask(
          taskId,
        );

        expect(result, '{}');
      });
    });

    group('buildRelatedProjectTasksJson', () {
      final projectDate = DateTime(2024, 3, 15, 10, 30);
      final project =
          JournalEntity.project(
                meta: Metadata(
                  id: 'project-123',
                  createdAt: projectDate,
                  updatedAt: projectDate,
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
                data: ProjectData(
                  title: 'Agentic Architecture',
                  status: ProjectStatus.active(
                    id: 'project-status-1',
                    createdAt: projectDate,
                    utcOffset: 60,
                  ),
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
              )
              as ProjectEntry;

      Task makeTask({
        required String id,
        required String title,
        required DateTime updatedAt,
      }) {
        return JournalEntity.task(
              meta: Metadata(
                id: id,
                createdAt: projectDate,
                updatedAt: updatedAt,
                dateFrom: projectDate,
                dateTo: projectDate,
              ),
              data: TaskData(
                title: title,
                status: TaskStatus.inProgress(
                  id: 'status-$id',
                  createdAt: updatedAt,
                  utcOffset: 0,
                ),
                statusHistory: const [],
                dateFrom: projectDate,
                dateTo: projectDate,
              ),
            )
            as Task;
      }

      test(
        'returns bounded sibling rows with stored tldrs and derived time spent',
        () async {
          final currentTask = makeTask(
            id: taskId,
            title: 'Current Task',
            updatedAt: DateTime(2024, 3, 16, 8),
          );
          final siblingOlder = makeTask(
            id: 'task-older',
            title: 'Older Sibling',
            updatedAt: DateTime(2024, 3, 16, 9),
          );
          final siblingNewer = makeTask(
            id: 'task-newer',
            title: 'Newer Sibling',
            updatedAt: DateTime(2024, 3, 16, 10),
          );
          final siblingWithoutTldr = makeTask(
            id: 'task-no-tldr',
            title: 'No TLDR',
            updatedAt: DateTime(2024, 3, 16, 11),
          );

          when(
            () => mockProjectRepository.getProjectForTask(taskId),
          ).thenAnswer((_) async => project);
          when(
            () => mockProjectRepository.getTasksForProject('project-123'),
          ).thenAnswer(
            (_) async => [
              currentTask,
              siblingOlder,
              siblingNewer,
              siblingWithoutTldr,
            ],
          );
          when(
            () => mockDb.getBulkLinkedEntities(any()),
          ).thenAnswer(
            (_) async => <String, List<JournalEntity>>{
              'task-older': [
                JournalEntity.journalEntry(
                  meta: Metadata(
                    id: 'entry-older',
                    createdAt: projectDate,
                    updatedAt: projectDate,
                    dateFrom: projectDate,
                    dateTo: projectDate.add(const Duration(minutes: 15)),
                  ),
                  entryText: const EntryText(plainText: 'Older work'),
                ),
              ],
              'task-newer': [
                JournalEntity.journalEntry(
                  meta: Metadata(
                    id: 'entry-newer',
                    createdAt: projectDate,
                    updatedAt: projectDate,
                    dateFrom: projectDate,
                    dateTo: projectDate.add(const Duration(minutes: 30)),
                  ),
                  entryText: const EntryText(plainText: 'Newer work'),
                ),
              ],
            },
          );
          when(
            () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
          ).thenAnswer(
            (_) async => <String, AgentReportEntity>{
              'task-older':
                  AgentDomainEntity.agentReport(
                        id: 'report-older',
                        agentId: 'agent-older',
                        scope: 'current',
                        createdAt: projectDate,
                        vectorClock: null,
                        tldr: 'Older sibling TLDR',
                        content: 'Older sibling report',
                      )
                      as AgentReportEntity,
              'task-newer':
                  AgentDomainEntity.agentReport(
                        id: 'report-newer',
                        agentId: 'agent-newer',
                        scope: 'current',
                        createdAt: projectDate,
                        vectorClock: null,
                        tldr: 'Newer sibling TLDR',
                        content: 'Newer sibling report',
                      )
                      as AgentReportEntity,
              'task-no-tldr':
                  AgentDomainEntity.agentReport(
                        id: 'report-no-tldr',
                        agentId: 'agent-no-tldr',
                        scope: 'current',
                        createdAt: projectDate,
                        vectorClock: null,
                        content: 'Missing TLDR should be omitted',
                      )
                      as AgentReportEntity,
            },
          );

          final result = await repository.buildRelatedProjectTasksJson(
            taskId: taskId,
            limit: 2,
          );
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          final tasks = decoded['tasks'] as List<dynamic>;

          expect(decoded['projectId'], 'project-123');
          expect(tasks, hasLength(2));
          expect(tasks[0], containsPair('id', 'task-newer'));
          expect(tasks[0], containsPair('timeSpent', '00:30'));
          expect(tasks[0], containsPair('tldr', 'Newer sibling TLDR'));
          expect(tasks[1], containsPair('id', 'task-older'));
          expect(tasks[1], containsPair('timeSpent', '00:15'));
          expect(
            tasks.where((row) => (row as Map<String, dynamic>)['id'] == taskId),
            isEmpty,
          );
        },
      );

      test('returns empty object when no sibling has a stored tldr', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => project);
        when(
          () => mockProjectRepository.getTasksForProject('project-123'),
        ).thenAnswer(
          (_) async => [
            makeTask(
              id: taskId,
              title: 'Current Task',
              updatedAt: DateTime(2024, 3, 16, 8),
            ),
            makeTask(
              id: 'task-sibling',
              title: 'Sibling',
              updatedAt: DateTime(2024, 3, 16, 9),
            ),
          ],
        );
        when(
          () => mockDb.getBulkLinkedEntities(any()),
        ).thenAnswer((_) async => <String, List<JournalEntity>>{});
        when(
          () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
        ).thenAnswer(
          (_) async => <String, AgentReportEntity>{
            'task-sibling':
                AgentDomainEntity.agentReport(
                      id: 'report-sibling',
                      agentId: 'agent-sibling',
                      scope: 'current',
                      createdAt: projectDate,
                      vectorClock: null,
                      content: 'No tldr field',
                    )
                    as AgentReportEntity,
          },
        );

        final result = await repository.buildRelatedProjectTasksJson(
          taskId: taskId,
        );

        expect(result, '{}');
      });

      test('returns empty object when sibling-task lookup throws', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenThrow(Exception('boom'));

        final result = await repository.buildRelatedProjectTasksJson(
          taskId: taskId,
        );

        expect(result, '{}');
      });

      test('orders siblings by dateFrom when updatedAt ties', () async {
        Task makeTask({
          required String id,
          required String title,
          required DateTime updatedAt,
          required DateTime dateFrom,
        }) {
          return JournalEntity.task(
                meta: Metadata(
                  id: id,
                  createdAt: DateTime(2024, 3, 15, 8),
                  updatedAt: updatedAt,
                  dateFrom: dateFrom,
                  dateTo: dateFrom,
                ),
                data: TaskData(
                  title: title,
                  status: TaskStatus.open(
                    id: 'status-$id',
                    createdAt: updatedAt,
                    utcOffset: 0,
                  ),
                  statusHistory: const [],
                  dateFrom: dateFrom,
                  dateTo: dateFrom,
                ),
              )
              as Task;
        }

        final project =
            JournalEntity.project(
                  meta: Metadata(
                    id: 'project-123',
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    dateFrom: DateTime(2024, 3, 15),
                    dateTo: DateTime(2024, 3, 15),
                  ),
                  data: ProjectData(
                    title: 'Project',
                    status: ProjectStatus.active(
                      id: 'project-status',
                      createdAt: DateTime(2024, 3, 15),
                      utcOffset: 60,
                    ),
                    dateFrom: DateTime(2024, 3, 15),
                    dateTo: DateTime(2024, 3, 15),
                  ),
                )
                as ProjectEntry;

        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => project);
        when(
          () => mockProjectRepository.getTasksForProject('project-123'),
        ).thenAnswer(
          (_) async => [
            makeTask(
              id: taskId,
              title: 'Current',
              updatedAt: DateTime(2024, 3, 16, 9),
              dateFrom: DateTime(2024, 3, 16, 9),
            ),
            makeTask(
              id: 'task-late-date',
              title: 'Late Date',
              updatedAt: DateTime(2024, 3, 16, 12),
              dateFrom: DateTime(2024, 3, 16, 12),
            ),
            makeTask(
              id: 'task-early-date',
              title: 'Early Date',
              updatedAt: DateTime(2024, 3, 16, 12),
              dateFrom: DateTime(2024, 3, 16, 10),
            ),
          ],
        );
        when(
          () => mockDb.getBulkLinkedEntities(any()),
        ).thenAnswer((_) async => <String, List<JournalEntity>>{});
        when(
          () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
        ).thenAnswer(
          (_) async => <String, AgentReportEntity>{
            'task-late-date':
                AgentDomainEntity.agentReport(
                      id: 'report-late-date',
                      agentId: 'agent-late-date',
                      scope: 'current',
                      createdAt: DateTime(2024, 3, 16, 12),
                      vectorClock: null,
                      tldr: 'Late Date TLDR',
                      content: 'Late Date report',
                    )
                    as AgentReportEntity,
            'task-early-date':
                AgentDomainEntity.agentReport(
                      id: 'report-early-date',
                      agentId: 'agent-early-date',
                      scope: 'current',
                      createdAt: DateTime(2024, 3, 16, 12),
                      vectorClock: null,
                      tldr: 'Early Date TLDR',
                      content: 'Early Date report',
                    )
                    as AgentReportEntity,
          },
        );

        final result = await repository.buildRelatedProjectTasksJson(
          taskId: taskId,
        );
        final tasks =
            (jsonDecode(result) as Map<String, dynamic>)['tasks'] as List;

        expect((tasks[0] as Map<String, dynamic>)['id'], 'task-late-date');
        expect((tasks[1] as Map<String, dynamic>)['id'], 'task-early-date');
      });

      test(
        'orders siblings by createdAt then id when updatedAt/dateFrom tie',
        () async {
          Task makeTask({
            required String id,
            required String title,
            required DateTime createdAt,
          }) {
            final sharedUpdatedAt = DateTime(2024, 3, 16, 12);
            final sharedDateFrom = DateTime(2024, 3, 16, 10);
            return JournalEntity.task(
                  meta: Metadata(
                    id: id,
                    createdAt: createdAt,
                    updatedAt: sharedUpdatedAt,
                    dateFrom: sharedDateFrom,
                    dateTo: sharedDateFrom,
                  ),
                  data: TaskData(
                    title: title,
                    status: TaskStatus.open(
                      id: 'status-$id',
                      createdAt: sharedUpdatedAt,
                      utcOffset: 0,
                    ),
                    statusHistory: const [],
                    dateFrom: sharedDateFrom,
                    dateTo: sharedDateFrom,
                  ),
                )
                as Task;
          }

          final project =
              JournalEntity.project(
                    meta: Metadata(
                      id: 'project-123',
                      createdAt: DateTime(2024, 3, 15),
                      updatedAt: DateTime(2024, 3, 15),
                      dateFrom: DateTime(2024, 3, 15),
                      dateTo: DateTime(2024, 3, 15),
                    ),
                    data: ProjectData(
                      title: 'Project',
                      status: ProjectStatus.active(
                        id: 'project-status',
                        createdAt: DateTime(2024, 3, 15),
                        utcOffset: 60,
                      ),
                      dateFrom: DateTime(2024, 3, 15),
                      dateTo: DateTime(2024, 3, 15),
                    ),
                  )
                  as ProjectEntry;

          when(
            () => mockProjectRepository.getProjectForTask(taskId),
          ).thenAnswer((_) async => project);
          when(
            () => mockProjectRepository.getTasksForProject('project-123'),
          ).thenAnswer(
            (_) async => [
              makeTask(
                id: taskId,
                title: 'Current',
                createdAt: DateTime(2024, 3, 15, 8),
              ),
              makeTask(
                id: 'task-new-created',
                title: 'New Created',
                createdAt: DateTime(2024, 3, 15, 11),
              ),
              makeTask(
                id: 'task-old-created',
                title: 'Old Created',
                createdAt: DateTime(2024, 3, 15, 9),
              ),
              makeTask(
                id: 'task-id-b',
                title: 'ID B',
                createdAt: DateTime(2024, 3, 15, 7),
              ),
              makeTask(
                id: 'task-id-a',
                title: 'ID A',
                createdAt: DateTime(2024, 3, 15, 7),
              ),
            ],
          );
          when(
            () => mockDb.getBulkLinkedEntities(any()),
          ).thenAnswer((_) async => <String, List<JournalEntity>>{});
          when(
            () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
          ).thenAnswer(
            (_) async => <String, AgentReportEntity>{
              for (final id in [
                'task-new-created',
                'task-old-created',
                'task-id-b',
                'task-id-a',
              ])
                id:
                    AgentDomainEntity.agentReport(
                          id: 'report-$id',
                          agentId: 'agent-$id',
                          scope: 'current',
                          createdAt: DateTime(2024, 3, 16, 12),
                          vectorClock: null,
                          tldr: '$id TLDR',
                          content: '$id report',
                        )
                        as AgentReportEntity,
            },
          );

          final result = await repository.buildRelatedProjectTasksJson(
            taskId: taskId,
          );
          final tasks =
              (jsonDecode(result) as Map<String, dynamic>)['tasks'] as List;
          final ids = tasks
              .map((task) => (task as Map<String, dynamic>)['id'] as String)
              .toList();

          expect(
            ids,
            containsAllInOrder([
              'task-new-created',
              'task-old-created',
              'task-id-b',
              'task-id-a',
            ]),
          );
        },
      );
    });

    group('buildRelatedTaskDetailsJson', () {
      final projectDate = DateTime(2024, 3, 15, 10, 30);
      final sharedProject =
          JournalEntity.project(
                meta: Metadata(
                  id: 'project-123',
                  createdAt: projectDate,
                  updatedAt: projectDate,
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
                data: ProjectData(
                  title: 'Agentic Architecture',
                  status: ProjectStatus.active(
                    id: 'project-status-1',
                    createdAt: projectDate,
                    utcOffset: 60,
                  ),
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
              )
              as ProjectEntry;
      final otherProject =
          JournalEntity.project(
                meta: Metadata(
                  id: 'project-999',
                  createdAt: projectDate,
                  updatedAt: projectDate,
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
                data: ProjectData(
                  title: 'Other Project',
                  status: ProjectStatus.active(
                    id: 'project-status-2',
                    createdAt: projectDate,
                    utcOffset: 60,
                  ),
                  dateFrom: projectDate,
                  dateTo: projectDate,
                ),
              )
              as ProjectEntry;

      test(
        'returns task payload, latest report, and project context',
        () async {
          final siblingTask =
              JournalEntity.task(
                    meta: Metadata(
                      id: 'task-sibling',
                      createdAt: projectDate,
                      updatedAt: projectDate,
                      dateFrom: projectDate,
                      dateTo: projectDate,
                    ),
                    data: TaskData(
                      title: 'Sibling Task',
                      status: TaskStatus.open(
                        id: 'status-sibling',
                        createdAt: projectDate,
                        utcOffset: 0,
                      ),
                      statusHistory: const [],
                      dateFrom: projectDate,
                      dateTo: projectDate,
                    ),
                  )
                  as Task;

          when(
            () => mockProjectRepository.getProjectForTask(taskId),
          ).thenAnswer((_) async => sharedProject);
          when(
            () => mockProjectRepository.getProjectForTask('task-sibling'),
          ).thenAnswer((_) async => sharedProject);
          when(
            () => mockDb.journalEntityById('task-sibling'),
          ).thenAnswer((_) async => siblingTask);
          when(
            () => mockDb.getLinkedEntities('task-sibling'),
          ).thenAnswer((_) async => <JournalEntity>[]);
          when(
            () => mockAgentRepository.getLatestTaskReportsForTaskIds(any()),
          ).thenAnswer(
            (_) async => <String, AgentReportEntity>{
              'task-sibling':
                  AgentDomainEntity.agentReport(
                        id: 'report-sibling',
                        agentId: 'agent-sibling',
                        scope: 'current',
                        createdAt: projectDate,
                        vectorClock: null,
                        tldr: 'Sibling TLDR',
                        content: '## Sibling Report\nFull details.',
                      )
                      as AgentReportEntity,
            },
          );

          final result = await repository.buildRelatedTaskDetailsJson(
            currentTaskId: taskId,
            requestedTaskId: 'task-sibling',
          );
          final decoded = jsonDecode(result!) as Map<String, dynamic>;

          expect(decoded['task'], containsPair('title', 'Sibling Task'));
          expect(
            decoded['latestTaskAgentReport'],
            containsPair('tldr', 'Sibling TLDR'),
          );
          expect(
            decoded['latestTaskAgentReport'],
            containsPair('content', '## Sibling Report\nFull details.'),
          );
          expect(
            decoded['projectContext'],
            containsPair('projectTitle', 'Agentic Architecture'),
          );
        },
      );

      test('returns null when requested task is outside the project', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => sharedProject);
        when(
          () => mockProjectRepository.getProjectForTask('task-sibling'),
        ).thenAnswer((_) async => otherProject);

        final result = await repository.buildRelatedTaskDetailsJson(
          currentTaskId: taskId,
          requestedTaskId: 'task-sibling',
        );

        expect(result, isNull);
      });

      test('returns null when related-task resolution throws', () async {
        when(
          () => mockProjectRepository.getProjectForTask(taskId),
        ).thenThrow(Exception('boom'));

        final result = await repository.buildRelatedTaskDetailsJson(
          currentTaskId: taskId,
          requestedTaskId: 'task-sibling',
        );

        expect(result, isNull);
      });
    });

    test(
      'generate returns AiInputTaskObject with correct data for a Task',
      () async {
        // Arrange
        const taskTitle = 'Test Task';
        const checklistId = 'checklist-123';
        const checklistItemId = 'checklist-item-123';
        const linkedEntryId = 'linked-entry-123';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository for this test
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(minutes: 60), // estimate
            {
              'entry1': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 45),
              ),
            },
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.inProgress(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            checklistIds: [checklistId],
            estimate: const Duration(minutes: 60),
          ),
        );

        // Mock the checklist
        final checklist = JournalEntity.checklist(
          meta: Metadata(
            id: checklistId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: [checklistItemId],
            linkedTasks: [taskId],
          ),
        );

        // Mock the checklist item
        final checklistItem = JournalEntity.checklistItem(
          meta: Metadata(
            id: checklistItemId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: true,
            linkedChecklists: [checklistId],
          ),
        );

        // Mock the linked entry
        final linkedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: linkedEntryId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 30)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'Test Journal Entry'),
        );

        // Set up mocks
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [linkedEntry]);
        when(
          () => mockDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        when(
          () => mockDb.journalEntityById(checklistItemId),
        ).thenAnswer((_) async => checklistItem);

        // Set task progress via the mock repository
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(hours: 1),
            <String, TimeRange>{
              'entry': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 45),
              ),
            },
          ),
        );

        // Act
        final result = await repository.generate(taskId);

        // Assert
        expect(result, isNotNull);
        expect(result!.title, equals(taskTitle));
        expect(result.status, equals('IN PROGRESS'));
        expect(result.creationDate, isNotNull);
        expect(result.estimatedDuration, equals('01:00'));
        expect(result.timeSpent, equals('00:45'));

        // Check action items
        expect(result.actionItems.length, 1);
        expect(result.actionItems[0].title, 'Test Checklist Item');
        expect(result.actionItems[0].completed, true);

        // Check log entries
        expect(result.logEntries.length, 1);
        expect(result.logEntries[0].text, 'Test Journal Entry');
        expect(result.logEntries[0].creationTimestamp, equals(creationDate));
        expect(result.logEntries[0].loggedDuration, equals('00:30'));

        // Verify calls
        verify(() => mockDb.journalEntityById(taskId)).called(1);
        verify(() => mockDb.getLinkedEntities(taskId)).called(1);
        verify(() => mockDb.journalEntityById(checklistId)).called(1);
        verify(() => mockDb.journalEntityById(checklistItemId)).called(1);
      },
    );

    test('generate handles null checklist items and time properly', () async {
      // Arrange
      const taskTitle = 'Test Task';
      const statusId = 'status-123';

      // Set up specific mock for the task progress repository for this test
      when(
        () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
      ).thenAnswer(
        (_) async => (
          null, // null estimate
          <String, TimeRange>{}, // empty time ranges
        ),
      );

      // Mock the task with no checklist ids and no estimate
      final task = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.open(
            id: statusId,
            createdAt: creationDate,
            utcOffset: 0,
          ),
          dateFrom: creationDate,
          dateTo: creationDate,
          statusHistory: [],
        ),
      );

      // Set up mocks
      when(
        () => mockDb.journalEntityById(taskId),
      ).thenAnswer((_) async => task);
      when(() => mockDb.getLinkedEntities(taskId)).thenAnswer((_) async => []);

      // Don't set any progress to keep the default null

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNotNull);
      expect(result!.title, equals(taskTitle));
      expect(result.status, equals('OPEN'));
      expect(result.estimatedDuration, equals('00:00'));
      expect(result.timeSpent, equals('00:00'));
      expect(result.actionItems, isEmpty);
      expect(result.logEntries, isEmpty);

      // Verify calls
      verify(() => mockDb.journalEntityById(taskId)).called(1);
      verify(() => mockDb.getLinkedEntities(taskId)).called(1);
    });

    test(
      'generate processes different types of linked entities correctly',
      () async {
        // Arrange
        const taskTitle = 'Test Task';
        const entryId = 'entry-123';
        const imageId = 'image-123';
        const audioId = 'audio-123';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository for this test
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(minutes: 30), // estimate
            <String, TimeRange>{
              'entry-123': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 15),
              ),
              'image-123': TimeRange(
                start: DateTime(2022, 7, 7, 10),
                end: DateTime(2022, 7, 7, 10, 30),
              ),
              'audio-123': TimeRange(
                start: DateTime(2022, 7, 7, 11),
                end: DateTime(2022, 7, 7, 11, 45),
              ),
            },
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.inProgress(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            dateFrom: creationDate,
            dateTo: creationDate,
            statusHistory: [],
            checklistIds: [],
          ),
        );

        // Mock different types of linked entities
        final journalEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: entryId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 15)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'Journal Entry Text'),
        );

        final journalImage = JournalEntity.journalImage(
          meta: Metadata(
            id: imageId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 30)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: ImageData(
            capturedAt: creationDate,
            imageId: 'img-1',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
          ),
          entryText: const EntryText(plainText: 'Image Caption'),
        );

        final journalAudio = JournalEntity.journalAudio(
          meta: Metadata(
            id: audioId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 45)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: AudioData(
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 45)),
            audioFile: 'test.mp3',
            audioDirectory: '/test',
            duration: const Duration(minutes: 45),
          ),
          entryText: const EntryText(plainText: 'Audio Transcription'),
        );

        // Set up mocks
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [journalEntry, journalImage, journalAudio]);

        // Act
        final result = await repository.generate(taskId);

        // Assert
        expect(result, isNotNull);
        expect(result!.logEntries.length, 3);

        // Verify the journal entry
        expect(result.logEntries[0].text, 'Journal Entry Text');
        expect(result.logEntries[0].loggedDuration, '00:15');

        // Verify the image entry
        expect(result.logEntries[1].text, 'Image Caption');
        expect(result.logEntries[1].loggedDuration, '00:30');

        // Verify the audio entry
        expect(result.logEntries[2].text, 'Audio Transcription');
        expect(result.logEntries[2].loggedDuration, '00:45');
      },
    );

    // Tests for getEntity method
    group('getEntity', () {
      test('returns entity when entity exists', () async {
        // Arrange
        final expectedEntity = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-123',
              createdAt: creationDate,
              utcOffset: 0,
            ),
            dateFrom: creationDate,
            dateTo: creationDate,
            statusHistory: [],
          ),
        );

        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => expectedEntity);

        // Act
        final result = await repository.getEntity(taskId);

        // Assert
        expect(result, equals(expectedEntity));
        verify(() => mockDb.journalEntityById(taskId)).called(1);
      });

      test('returns null when entity does not exist', () async {
        // Arrange
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getEntity(taskId);

        // Assert
        expect(result, isNull);
        verify(() => mockDb.journalEntityById(taskId)).called(1);
      });
    });

    // Tests for createAiResponseEntry method
    group('createAiResponseEntry', () {
      test(
        'calls PersistenceLogic.createAiResponseEntry with correct parameters',
        () async {
          // Arrange
          const testData = AiResponseData(
            model: 'test-model',
            systemMessage: 'test-system-message',
            prompt: 'test-prompt',
            thoughts: 'test-thoughts',
            response: 'test-response',
          );

          final testStart = DateTime(2023);
          const testLinkedId = 'linked-123';
          const testCategoryId = 'category-123';

          when(
            () => mockPersistenceLogic.createAiResponseEntry(
              data: any(named: 'data'),
              dateFrom: any(named: 'dateFrom'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);

          // Act
          await repository.createAiResponseEntry(
            data: testData,
            start: testStart,
            linkedId: testLinkedId,
            categoryId: testCategoryId,
          );

          // Assert
          verify(
            () => mockPersistenceLogic.createAiResponseEntry(
              data: testData,
              dateFrom: testStart,
              linkedId: testLinkedId,
              categoryId: testCategoryId,
            ),
          ).called(1);
        },
      );

      test('handles optional parameters correctly', () async {
        // Arrange
        const testData = AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system-message',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
        );

        final testStart = DateTime(2023);

        when(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: any(named: 'data'),
            dateFrom: any(named: 'dateFrom'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Act - omit optional parameters
        await repository.createAiResponseEntry(
          data: testData,
          start: testStart,
        );

        // Assert
        verify(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: testData,
            dateFrom: testStart,
          ),
        ).called(1);
      });
    });

    // Tests for buildTaskDetailsJson method
    group('buildTaskDetailsJson', () {
      test('returns JSON string for valid task', () async {
        // Arrange
        const taskTitle = 'Test Task';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(minutes: 30), // estimate
            <String, TimeRange>{
              'entry1': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 15),
              ),
            },
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.inProgress(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 30),
          ),
        );

        // Set up mocks
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('"title": "Test Task"'));
        expect(result, contains('"status": "IN PROGRESS"'));
        expect(result, contains('"estimatedDuration": "00:30"'));
        expect(result, contains('"timeSpent": "00:15"'));
        expect(result, contains('"actionItems": []'));
        expect(result, contains('"logEntries": []'));

        // Verify the JSON is properly formatted
        expect(() => jsonDecode(result!), returnsNormally);
      });

      test('returns null for non-task entity', () async {
        // Arrange
        when(() => mockDb.journalEntityById(taskId)).thenAnswer(
          (_) async => JournalEntity.journalEntry(
            meta: Metadata(
              id: taskId,
              dateFrom: creationDate,
              dateTo: creationDate,
              createdAt: creationDate,
              updatedAt: creationDate,
            ),
            entryText: const EntryText(plainText: 'Not a task'),
          ),
        );

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNull);
      });

      test('returns null for non-existent entity', () async {
        // Arrange
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNull);
      });

      test('includes action items and log entries in JSON', () async {
        // Arrange
        const taskTitle = 'Test Task';
        const checklistId = 'checklist-123';
        const checklistItemId = 'checklist-item-123';
        const linkedEntryId = 'linked-entry-123';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(minutes: 60), // estimate
            <String, TimeRange>{
              'entry1': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 45),
              ),
            },
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.inProgress(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            checklistIds: [checklistId],
            estimate: const Duration(minutes: 60),
          ),
        );

        // Mock the checklist
        final checklist = JournalEntity.checklist(
          meta: Metadata(
            id: checklistId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: [checklistItemId],
            linkedTasks: [taskId],
          ),
        );

        // Mock the checklist item
        final checklistItem = JournalEntity.checklistItem(
          meta: Metadata(
            id: checklistItemId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: true,
            linkedChecklists: [checklistId],
          ),
        );

        // Mock the linked entry
        final linkedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: linkedEntryId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 30)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'Test Journal Entry'),
        );

        // Set up mocks
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [linkedEntry]);
        when(
          () => mockDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        when(
          () => mockDb.journalEntityById(checklistItemId),
        ).thenAnswer((_) async => checklistItem);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNotNull);

        // Parse JSON to verify structure
        final jsonData = jsonDecode(result!) as Map<String, dynamic>;
        expect(jsonData['title'], equals('Test Task'));
        expect(jsonData['status'], equals('IN PROGRESS'));
        expect(jsonData['estimatedDuration'], equals('01:00'));
        expect(jsonData['timeSpent'], equals('00:45'));

        // Check action items
        expect(jsonData['actionItems'], isList);
        expect(jsonData['actionItems'].length, equals(1));
        expect(
          jsonData['actionItems'][0]['title'],
          equals('Test Checklist Item'),
        );
        expect(jsonData['actionItems'][0]['completed'], isTrue);

        // Check log entries
        expect(jsonData['logEntries'], isList);
        expect(jsonData['logEntries'].length, equals(1));
        expect(jsonData['logEntries'][0]['text'], equals('Test Journal Entry'));
        expect(jsonData['logEntries'][0]['loggedDuration'], equals('00:30'));
      });

      test('includes assigned labels with names in task JSON', () async {
        // Arrange
        const taskTitle = 'Test Task';
        const statusId = 'status-abc';

        // Provide progress data
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (const Duration(minutes: 10), <String, TimeRange>{}),
        );

        // Task with assigned labels
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
            labelIds: const ['l1', 'l2'],
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.open(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 10),
          ),
        );

        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        // Label definitions
        final defs = [
          LabelDefinition(
            id: 'l1',
            name: 'Label 1',
            color: '#000',
            createdAt: creationDate,
            updatedAt: creationDate,
            vectorClock: null,
            private: false,
          ),
          LabelDefinition(
            id: 'l2',
            name: 'Label 2',
            color: '#000',
            createdAt: creationDate,
            updatedAt: creationDate,
            vectorClock: null,
            private: false,
          ),
        ];
        when(
          () => mockDb.getAllLabelDefinitions(),
        ).thenAnswer((_) async => defs);

        // Act
        final jsonString = await repository.buildTaskDetailsJson(id: taskId);
        expect(jsonString, isNotNull);
        final data = jsonDecode(jsonString!) as Map<String, dynamic>;

        // Assert labels present with resolved names
        expect(data['labels'], isA<List<dynamic>>());
        final labels = (data['labels'] as List).cast<Map<String, dynamic>>();
        expect(labels.length, 2);
        expect(labels[0]['id'], anyOf('l1', 'l2'));
        final ids = labels.map((e) => e['id']).toSet();
        expect(ids, {'l1', 'l2'});
        final namesById = {for (final l in labels) l['id']: l['name']};
        expect(namesById['l1'], 'Label 1');
        expect(namesById['l2'], 'Label 2');
      });

      test('includes priority and dueDate in task JSON', () async {
        // Arrange
        const taskTitle = 'Task with priority and due date';
        const statusId = 'status-prio';
        final dueDate = DateTime(2025, 6, 15, 12);

        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (const Duration(minutes: 20), <String, TimeRange>{}),
        );

        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.open(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 20),
            priority: TaskPriority.p1High,
            due: dueDate,
          ),
        );

        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockDb.getAllLabelDefinitions(),
        ).thenAnswer((_) async => const []);

        // Act
        final jsonString = await repository.buildTaskDetailsJson(id: taskId);
        expect(jsonString, isNotNull);
        final data = jsonDecode(jsonString!) as Map<String, dynamic>;

        // Assert priority is included
        expect(data['priority'], 'P1');

        // Assert dueDate is included
        expect(data['dueDate'], isNotNull);
        expect(data['dueDate'], contains('2025-06-15'));
      });

      test('omits dueDate when task has no due date', () async {
        // Arrange
        const taskTitle = 'Task without due date';
        const statusId = 'status-nodue';

        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (const Duration(minutes: 15), <String, TimeRange>{}),
        );

        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.open(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 15),
          ),
        );

        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockDb.getAllLabelDefinitions(),
        ).thenAnswer((_) async => const []);

        // Act
        final jsonString = await repository.buildTaskDetailsJson(id: taskId);
        expect(jsonString, isNotNull);
        final data = jsonDecode(jsonString!) as Map<String, dynamic>;

        // Assert default priority is P2
        expect(data['priority'], 'P2');

        // Assert dueDate is null (not present or explicitly null)
        expect(data['dueDate'], isNull);
      });
    });
  });
}
