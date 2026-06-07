// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

// Local fake (not a plain mock): computes real union durations so the
// repository's progress maths are exercised end-to-end.
class _ComputingTaskProgressRepository extends Mock
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

// ---------------------------------------------------------------------------
// From ai_input_repository_language_test.dart — bare mock (no getTaskProgress
// override) used only in the 'Language support in task data' group below.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// From ai_input_repository_suppressed_ids_test.dart
// ---------------------------------------------------------------------------

class TestAiInputRepo extends AiInputRepository {
  TestAiInputRepo(super.ref, {required super.projectRepository})
    : super(taskSummaryResolver: TaskSummaryResolver(null));

  @override
  Future<AiInputTaskObject?> generate(String id) async {
    // Return minimal task JSON base to allow buildTaskDetailsJson to extend
    return AiInputTaskObject(
      title: 't',
      status: 'OPEN',
      priority: 'P2',
      creationDate: DateTime(2024),
      actionItems: const [],
      logEntries: const [],
      estimatedDuration: '00:00',
      timeSpent: '00:00',
      languageCode: 'en',
    );
  }
}

// ---------------------------------------------------------------------------
// From ai_linked_task_context_test.dart — Glados generators for round-trip
// property tests (must be at top-level; Dart extensions cannot be inside fns).
// ---------------------------------------------------------------------------

/// Wraps the combination of variant choices for a generated AiLinkedTaskContext.
class _GeneratedLinkedTaskContextScenario {
  const _GeneratedLinkedTaskContextScenario({
    required this.idIndex,
    required this.titleIndex,
    required this.statusIndex,
    required this.priorityIndex,
    required this.estimateIndex,
    required this.langIndex,
    required this.summaryIndex,
  });

  final int idIndex;
  final int titleIndex;
  final int statusIndex;
  final int priorityIndex;
  final int estimateIndex;
  final int langIndex;
  final int summaryIndex;

  static const List<String> _ids = [
    'task-001',
    'task-abc',
    'epic-42',
    'subtask-x',
  ];
  static const List<String> _titles = [
    'Fix login bug',
    'Implement search',
    'Write tests',
    'Deploy to prod',
  ];
  static const List<String> _statuses = [
    'OPEN',
    'GROOMED',
    'IN PROGRESS',
    'DONE',
    'REJECTED',
  ];
  static const List<String> _priorities = ['P0', 'P1', 'P2', 'P3'];
  static const List<String> _times = ['00:00', '01:30', '10:00', '40:00'];
  // null encodes as index 0, non-null values at 1+
  static const List<String?> _langs = [null, 'en', 'de', 'fr'];
  static const List<String?> _summaries = [
    null,
    '',
    'Completed the auth flow.',
    'Blocked by external API.',
  ];

  String get id => _ids[idIndex % _ids.length];
  String get title => _titles[titleIndex % _titles.length];
  String get status => _statuses[statusIndex % _statuses.length];
  String get priority => _priorities[priorityIndex % _priorities.length];
  String get estimate => _times[estimateIndex % _times.length];
  String get timeSpent => _times[(estimateIndex + 1) % _times.length];
  String? get languageCode => _langs[langIndex % _langs.length];
  String? get latestSummary => _summaries[summaryIndex % _summaries.length];

  @override
  String toString() =>
      '_GeneratedLinkedTaskContextScenario(id: $id, title: $title, '
      'status: $status, priority: $priority, estimate: $estimate, '
      'lang: $languageCode, summary: $latestSummary)';
}

extension _AnyLinkedTaskContext on glados.Any {
  glados.Generator<_GeneratedLinkedTaskContextScenario>
  get linkedTaskContextScenario => glados.CombinableAny(this).combine7(
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 4),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 3),
    (
      int idIdx,
      int titleIdx,
      int statusIdx,
      int priorityIdx,
      int estimateIdx,
      int langIdx,
      int summaryIdx,
    ) => _GeneratedLinkedTaskContextScenario(
      idIndex: idIdx,
      titleIndex: titleIdx,
      statusIndex: statusIdx,
      priorityIndex: priorityIdx,
      estimateIndex: estimateIdx,
      langIndex: langIdx,
      summaryIndex: summaryIdx,
    ),
  );
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
    late _ComputingTaskProgressRepository mockTaskProgressRepository;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockProjectRepository mockProjectRepository;
    late MockAgentRepository mockAgentRepository;
    late TestContainerBuilder containerBuilder;
    late ProviderContainer container;
    late AiInputRepository repository;

    setUp(() async {
      mockDb = MockJournalDb();
      mockTaskProgressRepository = _ComputingTaskProgressRepository();
      mockPersistenceLogic = MockPersistenceLogic();
      mockProjectRepository = MockProjectRepository();
      mockAgentRepository = MockAgentRepository();
      containerBuilder = TestContainerBuilder(mockTaskProgressRepository);

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockDb)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
        },
      );

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

    tearDown(() async {
      container.dispose();
      await tearDownTestGetIt();
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

    group('generate maps every task status to its AI input string', () {
      // (TaskStatus factory, expected AiInputTaskObject.status string).
      final statusCases = <(TaskStatus, String)>[
        (
          TaskStatus.open(id: 's', createdAt: creationDate, utcOffset: 0),
          'OPEN',
        ),
        (
          TaskStatus.groomed(id: 's', createdAt: creationDate, utcOffset: 0),
          'GROOMED',
        ),
        (
          TaskStatus.inProgress(id: 's', createdAt: creationDate, utcOffset: 0),
          'IN PROGRESS',
        ),
        (
          TaskStatus.blocked(
            id: 's',
            createdAt: creationDate,
            utcOffset: 0,
            reason: 'waiting',
          ),
          'BLOCKED',
        ),
        (
          TaskStatus.onHold(
            id: 's',
            createdAt: creationDate,
            utcOffset: 0,
            reason: 'paused',
          ),
          'ON HOLD',
        ),
        (
          TaskStatus.done(id: 's', createdAt: creationDate, utcOffset: 0),
          'DONE',
        ),
        (
          TaskStatus.rejected(id: 's', createdAt: creationDate, utcOffset: 0),
          'REJECTED',
        ),
      ];

      for (final (status, expected) in statusCases) {
        test(expected, () async {
          final task = JournalEntity.task(
            meta: Metadata(
              id: taskId,
              dateFrom: creationDate,
              dateTo: creationDate,
              createdAt: creationDate,
              updatedAt: creationDate,
            ),
            data: TaskData(
              title: 'Status task',
              status: status,
              dateFrom: creationDate,
              dateTo: creationDate,
              statusHistory: const [],
            ),
          );
          when(
            () => mockDb.journalEntityById(taskId),
          ).thenAnswer((_) async => task);
          when(
            () => mockDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => <JournalEntity>[]);

          final result = await repository.generate(taskId);

          expect(result, isNotNull);
          expect(result!.status, equals(expected));
        });
      }
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
        'returns project metadata plus compact report summary '
        '(oneLiner/tldr, not full body)',
        () async {
          final report =
              AgentDomainEntity.agentReport(
                    id: 'project-report-1',
                    agentId: 'project-agent-1',
                    scope: 'current',
                    createdAt: projectDate,
                    vectorClock: null,
                    oneLiner: 'Improving wake-cycle context quality.',
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

          final reportJson =
              decoded['latestProjectAgentReport'] as Map<String, dynamic>;
          expect(
            reportJson,
            containsPair('oneLiner', 'Improving wake-cycle context quality.'),
          );
          expect(
            reportJson,
            containsPair(
              'tldr',
              'Project is focused on wake-cycle context quality.',
            ),
          );
          // Full body is intentionally omitted to keep wake prefill small.
          expect(reportJson.containsKey('content'), isFalse);
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

      test('omits logEntries when includeLogEntries is false', () async {
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (const Duration(minutes: 30), <String, TimeRange>{}),
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
            title: 'Compacted Task',
            status: TaskStatus.inProgress(
              id: 'status-c',
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
          ),
        );
        final linkedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'le-1',
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'a log entry'),
        );
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [linkedEntry]);

        final full = await repository.buildTaskDetailsJson(id: taskId);
        final slim = await repository.buildTaskDetailsJson(
          id: taskId,
          includeLogEntries: false,
        );

        // The full header carries the log; the slim (compaction) header drops
        // it entirely, so the captured log + summary can supply it instead.
        expect(full, contains('logEntries'));
        expect(full, contains('a log entry'));
        expect(slim, isNot(contains('logEntries')));
        expect(slim, isNot(contains('a log entry')));
        expect(slim, contains('"title": "Compacted Task"'));
      });

      test('buildTaskStateMarkdown renders the compact state block without '
          'log entries', () async {
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer(
          (_) async => (
            const Duration(minutes: 30),
            <String, TimeRange>{
              'entry1': TimeRange(
                start: DateTime(2022, 7, 7, 9),
                end: DateTime(2022, 7, 7, 9, 15),
              ),
            },
          ),
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
            title: 'Markdown Task',
            status: TaskStatus.inProgress(
              id: 'status-m',
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 30),
          ),
        );
        final linkedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'le-1',
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'a log entry'),
        );
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [linkedEntry]);

        final markdown = await repository.buildTaskStateMarkdown(taskId);

        expect(markdown, isNotNull);
        expect(markdown, contains('- Title: Markdown Task'));
        expect(markdown, contains('- Status: IN PROGRESS'));
        expect(markdown, contains('Estimate: 00:30'));
        expect(markdown, contains('Time spent: 00:15'));
        // State, not log: the linked entry never leaks into the state block.
        expect(markdown, isNot(contains('a log entry')));
        expect(markdown, isNot(contains('logEntries')));
        expect(markdown, isNot(contains('{')));
      });

      test('buildTaskStateMarkdown resolves assigned label names', () async {
        when(
          () => mockTaskProgressRepository.getTaskProgressData(id: taskId),
        ).thenAnswer((_) async => (Duration.zero, <String, TimeRange>{}));
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
            labelIds: const ['label-1'],
          ),
          data: TaskData(
            title: 'Labelled Task',
            status: TaskStatus.inProgress(
              id: 'status-l',
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
          ),
        );
        when(
          () => mockDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task);
        when(
          () => mockDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);
        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            LabelDefinition(
              id: 'label-1',
              name: 'deep work',
              color: '#FF0000',
              createdAt: creationDate,
              updatedAt: creationDate,
              vectorClock: null,
            ),
          ],
        );

        final markdown = await repository.buildTaskStateMarkdown(taskId);

        expect(markdown, contains('- Labels: deep work'));
      });

      test(
        'buildTaskStateMarkdown returns null for a non-task entity',
        () async {
          when(() => mockDb.journalEntityById(taskId)).thenAnswer(
            (_) async => JournalEntity.journalEntry(
              meta: Metadata(
                id: taskId,
                dateFrom: creationDate,
                dateTo: creationDate,
                createdAt: creationDate,
                updatedAt: creationDate,
              ),
            ),
          );

          expect(await repository.buildTaskStateMarkdown(taskId), isNull);
        },
      );

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

  group('aiInputRepositoryProvider wiring', () {
    late MockJournalDb mockDb;
    late MockProjectRepository mockProjectRepository;
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
                title: 'Wiring Project',
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

    setUp(() async {
      mockDb = MockJournalDb();
      mockProjectRepository = MockProjectRepository();
      await setUpTestGetIt(
        additionalSetup: () {
          // These tests exercise both the registered and the absent branch
          // for AgentDatabase/DomainLogger — start from the absent state.
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockDb)
            ..unregister<DomainLogger>();
        },
      );
      when(
        () => mockProjectRepository.getProjectForTask(any()),
      ).thenAnswer((_) async => project);
    });

    tearDown(tearDownTestGetIt);

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(mockProjectRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'wires an AgentRepository backed by the registered AgentDatabase '
      'when AgentDatabase is registered',
      () async {
        // AgentDatabase IS registered -> provider must construct a real
        // AgentRepository (line 612 branch). We observe this by checking that
        // a project-context lookup reaches the underlying AgentDatabase query.
        final mockAgentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);
        when(
          () => mockAgentDb.getAgentLinksByToIdAndType(any(), any()),
        ).thenReturn(MockSelectable<AgentLink>([]));

        final repository = buildContainer().read(aiInputRepositoryProvider);
        final result = await repository.buildProjectContextJsonForTask('t-1');

        // No links -> no current report -> compact empty context.
        expect(result, equals('{}'));
        // The wired AgentRepository delegated down to the registered DB.
        verify(
          () => mockAgentDb.getAgentLinksByToIdAndType('project-123', any()),
        ).called(1);
      },
    );

    test(
      'leaves the agent repository unset when no AgentDatabase is registered',
      () async {
        // AgentDatabase NOT registered -> agentRepository is null (line 611
        // false branch). The project lookup never touches an agent DB; the
        // method short-circuits to an empty context.
        expect(getIt.isRegistered<AgentDatabase>(), isFalse);

        final repository = buildContainer().read(aiInputRepositoryProvider);
        final result = await repository.buildProjectContextJsonForTask('t-1');

        expect(result, equals('{}'));
        verify(() => mockProjectRepository.getProjectForTask('t-1')).called(1);
      },
    );

    test(
      'wires the registered DomainLogger so errors are forwarded to it',
      () async {
        // DomainLogger IS registered -> provider must pass it through (line
        // 620 branch). Forcing the project lookup to throw drives the catch
        // block, which calls _domainLogger?.error.
        final mockLogger = MockDomainLogger();
        getIt.registerSingleton<DomainLogger>(mockLogger);
        final failure = Exception('boom');
        when(
          () => mockProjectRepository.getProjectForTask(any()),
        ).thenThrow(failure);

        final repository = buildContainer().read(aiInputRepositoryProvider);
        final result = await repository.buildProjectContextJsonForTask('t-1');

        expect(result, equals('{}'));
        verify(
          () => mockLogger.error(
            LogDomain.ai,
            failure,
            message: 'buildProjectContextJsonForTask failed',
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'AiInputRepository',
          ),
        ).called(1);
      },
    );

    test(
      'does not log when no DomainLogger is registered and the lookup fails',
      () async {
        // DomainLogger NOT registered -> _domainLogger is null (line 619 false
        // branch). The catch block must still swallow the error and return an
        // empty context without throwing.
        expect(getIt.isRegistered<DomainLogger>(), isFalse);
        when(
          () => mockProjectRepository.getProjectForTask(any()),
        ).thenThrow(Exception('boom'));

        final repository = buildContainer().read(aiInputRepositoryProvider);
        final result = await repository.buildProjectContextJsonForTask('t-1');

        expect(result, equals('{}'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // From ai_input_repository_language_test.dart
  // ---------------------------------------------------------------------------

  group('Language support in task data', () {
    late AiInputRepository repository;
    late MockJournalDb mockDbLang;
    late ProviderContainer containerLang;
    late MockTaskProgressRepository mockTaskProgressRepoLang;
    late MockPersistenceLogic mockPersistenceLogicLang;
    late MockProjectRepository mockProjectRepositoryLang;

    final testDate = DateTime(2024, 3, 15, 10, 30);

    Metadata createMetadata({String id = 'test-id'}) {
      return Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
    }

    void setupTaskProgressMock() {
      when(
        () => mockTaskProgressRepoLang.getTaskProgress(
          timeRanges: any(named: 'timeRanges'),
          estimate: any(named: 'estimate'),
        ),
      ).thenReturn(
        const TaskProgressState(
          progress: Duration.zero,
          estimate: Duration.zero,
        ),
      );
    }

    setUp(() async {
      mockDbLang = MockJournalDb();
      mockTaskProgressRepoLang = MockTaskProgressRepository();
      mockPersistenceLogicLang = MockPersistenceLogic();
      mockProjectRepositoryLang = MockProjectRepository();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockDbLang)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogicLang);
        },
      );

      containerLang = ProviderContainer(
        overrides: [
          taskProgressRepositoryProvider.overrideWithValue(
            mockTaskProgressRepoLang,
          ),
        ],
      );

      final ref = containerLang.read(testRefProvider);
      repository = AiInputRepository(
        ref,
        taskSummaryResolver: TaskSummaryResolver(null),
        projectRepository: mockProjectRepositoryLang,
      );
    });

    tearDown(() async {
      containerLang.dispose();
      await tearDownTestGetIt();
    });

    test('includes languageCode in generated task object', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: testDate,
          dateTo: testDate,
          languageCode: 'de',
        ),
      );

      when(
        () => mockDbLang.journalEntityById('test-id'),
      ).thenAnswer((_) async => task);
      when(
        () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
      ).thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(
        () => mockDbLang.getLinkedEntities('test-id'),
      ).thenAnswer((_) async => []);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.languageCode, equals('de'));
    });

    test('handles null languageCode', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: testDate,
          dateTo: testDate,
        ),
      );

      when(
        () => mockDbLang.journalEntityById('test-id'),
      ).thenAnswer((_) async => task);
      when(
        () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
      ).thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(
        () => mockDbLang.getLinkedEntities('test-id'),
      ).thenAnswer((_) async => []);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.languageCode, isNull);
    });

    test(
      'includes transcript language in log entries when no edited text',
      () async {
        final task = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: testDate,
            dateTo: testDate,
          ),
        );

        // Audio entry WITHOUT edited text - should use original transcript
        final audioEntry = JournalAudio(
          meta: createMetadata(id: 'audio-1'),
          data: AudioData(
            dateFrom: testDate,
            dateTo: testDate,
            audioFile: 'test.mp3',
            audioDirectory: '/audio',
            duration: const Duration(minutes: 5),
            transcripts: [
              AudioTranscript(
                created: testDate,
                library: 'whisper',
                model: 'base',
                detectedLanguage: 'es',
                transcript: 'Este es un texto en español',
              ),
            ],
          ),
          // No entryText - so audioTranscript should be included
        );

        when(
          () => mockDbLang.journalEntityById('test-id'),
        ).thenAnswer((_) async => task);
        when(
          () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
        ).thenAnswer((_) async => null);
        setupTaskProgressMock();
        when(
          () => mockDbLang.getLinkedEntities('test-id'),
        ).thenAnswer((_) async => [audioEntry]);

        final result = await repository.generate('test-id');

        expect(result, isNotNull);
        expect(result!.logEntries, hasLength(1));

        final logEntry = result.logEntries.first;
        expect(logEntry.entryType, equals('audio'));
        expect(logEntry.audioTranscript, equals('Este es un texto en español'));
        expect(logEntry.transcriptLanguage, equals('es'));
        expect(logEntry.text, isEmpty);
      },
    );

    test(
      'uses edited text instead of original transcript when available',
      () async {
        final task = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: testDate,
            dateTo: testDate,
          ),
        );

        // Audio entry WITH edited text - should use edited text, not transcript
        final audioEntry = JournalAudio(
          meta: createMetadata(id: 'audio-1'),
          data: AudioData(
            dateFrom: testDate,
            dateTo: testDate,
            audioFile: 'test.mp3',
            audioDirectory: '/audio',
            duration: const Duration(minutes: 5),
            transcripts: [
              AudioTranscript(
                created: testDate,
                library: 'whisper',
                model: 'base',
                detectedLanguage: 'es',
                transcript: 'Original transcript with errors',
              ),
            ],
          ),
          entryText: const EntryText(
            plainText: 'Corrected transcript by user',
          ),
        );

        when(
          () => mockDbLang.journalEntityById('test-id'),
        ).thenAnswer((_) async => task);
        when(
          () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
        ).thenAnswer((_) async => null);
        setupTaskProgressMock();
        when(
          () => mockDbLang.getLinkedEntities('test-id'),
        ).thenAnswer((_) async => [audioEntry]);

        final result = await repository.generate('test-id');

        expect(result, isNotNull);
        expect(result!.logEntries, hasLength(1));

        final logEntry = result.logEntries.first;
        expect(logEntry.entryType, equals('audio'));
        // Edited text takes precedence - audioTranscript should be null
        expect(logEntry.audioTranscript, isNull);
        expect(logEntry.transcriptLanguage, isNull);
        expect(logEntry.text, equals('Corrected transcript by user'));
      },
    );

    test(
      'empty edited text takes precedence over original transcript',
      () async {
        final task = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: testDate,
            dateTo: testDate,
          ),
        );

        // Audio entry with explicitly cleared text (empty string)
        // Should NOT fall back to original transcript
        final audioEntry = JournalAudio(
          meta: createMetadata(id: 'audio-1'),
          data: AudioData(
            dateFrom: testDate,
            dateTo: testDate,
            audioFile: 'test.mp3',
            audioDirectory: '/audio',
            duration: const Duration(minutes: 5),
            transcripts: [
              AudioTranscript(
                created: testDate,
                library: 'whisper',
                model: 'base',
                detectedLanguage: 'en',
                transcript: 'Original transcript should not appear',
              ),
            ],
          ),
          entryText: const EntryText(
            plainText: '', // User explicitly cleared the text
          ),
        );

        when(
          () => mockDbLang.journalEntityById('test-id'),
        ).thenAnswer((_) async => task);
        when(
          () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
        ).thenAnswer((_) async => null);
        setupTaskProgressMock();
        when(
          () => mockDbLang.getLinkedEntities('test-id'),
        ).thenAnswer((_) async => [audioEntry]);

        final result = await repository.generate('test-id');

        expect(result, isNotNull);
        expect(result!.logEntries, hasLength(1));

        final logEntry = result.logEntries.first;
        expect(logEntry.entryType, equals('audio'));
        // Empty edited text still takes precedence - no fallback to transcript
        expect(logEntry.audioTranscript, isNull);
        expect(logEntry.transcriptLanguage, isNull);
        expect(logEntry.text, isEmpty);
      },
    );

    test('handles multiple audio transcripts', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: testDate,
          dateTo: testDate,
        ),
      );

      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: testDate,
          dateTo: testDate,
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
          transcripts: [
            AudioTranscript(
              created: testDate.subtract(const Duration(hours: 1)),
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'en',
              transcript: 'Old English transcript',
            ),
            AudioTranscript(
              created: testDate,
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'de',
              transcript: 'Dies ist die neueste deutsche Transkription',
            ),
          ],
        ),
      );

      when(
        () => mockDbLang.journalEntityById('test-id'),
      ).thenAnswer((_) async => task);
      when(
        () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
      ).thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(
        () => mockDbLang.getLinkedEntities('test-id'),
      ).thenAnswer((_) async => [audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(1));

      final logEntry = result.logEntries.first;
      // Should use the most recent transcript
      expect(
        logEntry.audioTranscript,
        equals('Dies ist die neueste deutsche Transkription'),
      );
      expect(logEntry.transcriptLanguage, equals('de'));
    });

    test('sets correct entry types for different journal entities', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: testDate,
          dateTo: testDate,
        ),
      );

      final textEntry = JournalEntry(
        meta: createMetadata(id: 'text-1'),
        entryText: const EntryText(plainText: 'Some text'),
      );

      final imageEntry = JournalImage(
        meta: createMetadata(id: 'image-1'),
        data: ImageData(
          capturedAt: testDate,
          imageId: 'img-1',
          imageFile: 'test.jpg',
          imageDirectory: '/images',
        ),
      );

      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: testDate,
          dateTo: testDate,
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
        ),
      );

      when(
        () => mockDbLang.journalEntityById('test-id'),
      ).thenAnswer((_) async => task);
      when(
        () => mockTaskProgressRepoLang.getTaskProgressData(id: 'test-id'),
      ).thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(
        () => mockDbLang.getLinkedEntities('test-id'),
      ).thenAnswer((_) async => [textEntry, imageEntry, audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(3));

      expect(result.logEntries[0].entryType, equals('text'));
      expect(result.logEntries[1].entryType, equals('image'));
      expect(result.logEntries[2].entryType, equals('audio'));
    });
  });

  // ---------------------------------------------------------------------------
  // From ai_input_repository_suppressed_ids_test.dart
  // ---------------------------------------------------------------------------

  group('buildTaskDetailsJson suppressed label IDs', () {
    test('buildTaskDetailsJson includes aiSuppressedLabelIds', () async {
      final db = MockJournalDb();
      final mockProjectRepository = MockProjectRepository();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(db);
        },
      );
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await tearDownTestGetIt();
      });

      final testDate = DateTime(2024, 3, 15, 10, 30);
      final task = Task(
        meta: Metadata(
          id: 't1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          labelIds: const ['a'],
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: const [],
          title: 't',
          aiSuppressedLabelIds: const {'x', 'y'},
        ),
      );
      when(() => db.journalEntityById('t1')).thenAnswer((_) async => task);
      when(db.getAllLabelDefinitions).thenAnswer((_) async => const []);

      final repo = TestAiInputRepo(
        container.read(testRefProvider),
        projectRepository: mockProjectRepository,
      );
      final jsonStr = await repo.buildTaskDetailsJson(id: 't1');
      expect(jsonStr, isNotNull);
      final map = jsonDecode(jsonStr!) as Map<String, dynamic>;
      expect(map['aiSuppressedLabelIds'], containsAll(['x', 'y']));
    });
  });

  // ---------------------------------------------------------------------------
  // From ai_linked_task_context_test.dart
  // ---------------------------------------------------------------------------

  group('AiLinkedTaskContext', () {
    final testDate = DateTime(2025, 12, 20, 14, 30);
    final createdDate = DateTime(2025, 12, 15, 10);

    test('serializes to JSON correctly', () {
      final context = AiLinkedTaskContext(
        id: 'task-123',
        title: 'Implement login form',
        status: 'DONE',
        statusSince: testDate,
        priority: 'P1',
        estimate: '02:00',
        timeSpent: '01:45',
        createdAt: createdDate,
        labels: [
          {'id': 'l1', 'name': 'frontend'},
        ],
        languageCode: 'en',
        latestSummary: 'Implemented the login form with validation.',
      );

      final json = context.toJson();

      expect(json['id'], equals('task-123'));
      expect(json['title'], equals('Implement login form'));
      expect(json['status'], equals('DONE'));
      expect(json['statusSince'], equals(testDate.toIso8601String()));
      expect(json['priority'], equals('P1'));
      expect(json['estimate'], equals('02:00'));
      expect(json['timeSpent'], equals('01:45'));
      expect(json['createdAt'], equals(createdDate.toIso8601String()));
      expect(json['labels'], isA<List<Map<String, String>>>());
      expect((json['labels']! as List<Map<String, String>>).length, equals(1));
      expect(json['languageCode'], equals('en'));
      expect(
        json['latestSummary'],
        equals('Implemented the login form with validation.'),
      );
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'task-456',
        'title': 'Authentication Epic',
        'status': 'IN PROGRESS',
        'statusSince': testDate.toIso8601String(),
        'priority': 'P0',
        'estimate': '40:00',
        'timeSpent': '12:30',
        'createdAt': createdDate.toIso8601String(),
        'labels': [
          {'id': 'l2', 'name': 'auth'},
          {'id': 'l3', 'name': 'epic'},
        ],
        'languageCode': 'en',
        'latestSummary': 'Parent epic for authentication.',
      };

      final context = AiLinkedTaskContext.fromJson(json);

      expect(context.id, equals('task-456'));
      expect(context.title, equals('Authentication Epic'));
      expect(context.status, equals('IN PROGRESS'));
      expect(context.statusSince, equals(testDate));
      expect(context.priority, equals('P0'));
      expect(context.estimate, equals('40:00'));
      expect(context.timeSpent, equals('12:30'));
      expect(context.createdAt, equals(createdDate));
      expect(context.labels.length, equals(2));
      expect(context.languageCode, equals('en'));
      expect(context.latestSummary, equals('Parent epic for authentication.'));
    });

    test('handles null latestSummary', () {
      final context = AiLinkedTaskContext(
        id: 'task-789',
        title: 'New Task',
        status: 'OPEN',
        statusSince: testDate,
        priority: 'P2',
        estimate: '00:00',
        timeSpent: '00:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['latestSummary'], isNull);

      // Round-trip test
      final restored = AiLinkedTaskContext.fromJson(json);
      expect(restored.latestSummary, isNull);
    });

    test('handles null languageCode', () {
      final context = AiLinkedTaskContext(
        id: 'task-abc',
        title: 'Task without language',
        status: 'GROOMED',
        statusSince: testDate,
        priority: 'P3',
        estimate: '01:00',
        timeSpent: '00:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['languageCode'], isNull);

      // Round-trip test
      final restored = AiLinkedTaskContext.fromJson(json);
      expect(restored.languageCode, isNull);
    });

    test('handles empty labels list', () {
      final context = AiLinkedTaskContext(
        id: 'task-xyz',
        title: 'Task without labels',
        status: 'BLOCKED',
        statusSince: testDate,
        priority: 'P1',
        estimate: '03:00',
        timeSpent: '02:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['labels'], isA<List<Map<String, String>>>());
      expect((json['labels']! as List<Map<String, String>>).isEmpty, isTrue);
    });

    test('JSON output is valid for prompt injection', () {
      final linkedFrom = [
        AiLinkedTaskContext(
          id: 'child-1',
          title: 'Child Task 1',
          status: 'DONE',
          statusSince: testDate,
          priority: 'P2',
          estimate: '01:00',
          timeSpent: '00:45',
          createdAt: createdDate,
          labels: [
            {'id': 'l1', 'name': 'frontend'},
          ],
          languageCode: 'en',
          latestSummary:
              'Completed the UI.\n\n## Links\n- [PR #123](https://github.com/org/repo/pull/123)',
        ),
      ];

      final linkedTo = [
        AiLinkedTaskContext(
          id: 'parent-1',
          title: 'Parent Epic',
          status: 'IN PROGRESS',
          statusSince: testDate,
          priority: 'P0',
          estimate: '40:00',
          timeSpent: '12:30',
          createdAt: createdDate,
          labels: [
            {'id': 'l2', 'name': 'epic'},
          ],
          languageCode: 'en',
          latestSummary: 'Epic for the feature.',
        ),
      ];

      final data = <String, dynamic>{
        'linked_from': linkedFrom.map((c) => c.toJson()).toList(),
        'linked_to': linkedTo.map((c) => c.toJson()).toList(),
        'note':
            'If summaries contain links to GitHub PRs, Issues, or similar '
            'platforms, use web search to retrieve additional context when relevant.',
      };

      const encoder = JsonEncoder.withIndent('    ');
      final jsonString = encoder.convert(data);

      // Verify the JSON is valid
      expect(() => jsonDecode(jsonString), returnsNormally);

      // Verify structure
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(parsed['linked_from'], isA<List<dynamic>>());
      expect(parsed['linked_to'], isA<List<dynamic>>());
      expect(parsed['note'], contains('web search'));

      // Verify linked_from content
      final linkedFromParsed = parsed['linked_from'] as List<dynamic>;
      expect(linkedFromParsed.length, equals(1));
      final linkedFromFirst = linkedFromParsed[0] as Map<String, dynamic>;
      expect(linkedFromFirst['title'], equals('Child Task 1'));
      expect(linkedFromFirst['latestSummary'], contains('[PR #123]'));

      // Verify linked_to content
      final linkedToParsed = parsed['linked_to'] as List<dynamic>;
      expect(linkedToParsed.length, equals(1));
      final linkedToFirst = linkedToParsed[0] as Map<String, dynamic>;
      expect(linkedToFirst['title'], equals('Parent Epic'));
    });

    test('handles all task statuses', () {
      final statuses = [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ];

      for (final status in statuses) {
        final context = AiLinkedTaskContext(
          id: 'task-$status',
          title: 'Task with status $status',
          status: status,
          statusSince: testDate,
          priority: 'P2',
          estimate: '01:00',
          timeSpent: '00:30',
          createdAt: createdDate,
          labels: [],
        );

        final json = context.toJson();
        expect(json['status'], equals(status));

        final restored = AiLinkedTaskContext.fromJson(json);
        expect(restored.status, equals(status));
      }
    });

    test('handles all priority levels', () {
      final priorities = ['P0', 'P1', 'P2', 'P3'];

      for (final priority in priorities) {
        final context = AiLinkedTaskContext(
          id: 'task-$priority',
          title: 'Task with priority $priority',
          status: 'OPEN',
          statusSince: testDate,
          priority: priority,
          estimate: '01:00',
          timeSpent: '00:00',
          createdAt: createdDate,
          labels: [],
        );

        final json = context.toJson();
        expect(json['priority'], equals(priority));

        final restored = AiLinkedTaskContext.fromJson(json);
        expect(restored.priority, equals(priority));
      }
    });
  });

  // -------------------------------------------------------------------------
  // Glados round-trip property — toJson → jsonEncode → jsonDecode → fromJson
  // must preserve every field value.
  // -------------------------------------------------------------------------
  group('AiLinkedTaskContext — Glados JSON round-trip', () {
    // Deterministic dates to avoid DateTime.now() in tests.
    final fixedStatusSince = DateTime(2025, 6, 1, 12);
    final fixedCreatedAt = DateTime(2024, 1, 10, 8, 30);

    glados.Glados(
      glados.any.linkedTaskContextScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'toJson → jsonDecode(jsonEncode) → fromJson preserves all fields',
      (scenario) {
        final original = AiLinkedTaskContext(
          id: scenario.id,
          title: scenario.title,
          status: scenario.status,
          statusSince: fixedStatusSince,
          priority: scenario.priority,
          estimate: scenario.estimate,
          timeSpent: scenario.timeSpent,
          createdAt: fixedCreatedAt,
          labels: const [],
          languageCode: scenario.languageCode,
          latestSummary: scenario.latestSummary,
        );

        final roundTripped = AiLinkedTaskContext.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        );

        expect(
          roundTripped.id,
          equals(original.id),
          reason: 'id — $scenario',
        );
        expect(
          roundTripped.title,
          equals(original.title),
          reason: 'title — $scenario',
        );
        expect(
          roundTripped.status,
          equals(original.status),
          reason: 'status — $scenario',
        );
        expect(
          roundTripped.statusSince,
          equals(original.statusSince),
          reason: 'statusSince — $scenario',
        );
        expect(
          roundTripped.priority,
          equals(original.priority),
          reason: 'priority — $scenario',
        );
        expect(
          roundTripped.estimate,
          equals(original.estimate),
          reason: 'estimate — $scenario',
        );
        expect(
          roundTripped.timeSpent,
          equals(original.timeSpent),
          reason: 'timeSpent — $scenario',
        );
        expect(
          roundTripped.createdAt,
          equals(original.createdAt),
          reason: 'createdAt — $scenario',
        );
        expect(
          roundTripped.languageCode,
          equals(original.languageCode),
          reason: 'languageCode — $scenario',
        );
        expect(
          roundTripped.latestSummary,
          equals(original.latestSummary),
          reason: 'latestSummary — $scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('AiInputRepository - Linked Task Context', () {
    late MockJournalDb mockDbLinked;
    late _ComputingTaskProgressRepository mockTaskProgressRepositoryLinked;
    late MockPersistenceLogic mockPersistenceLogicLinked;
    late MockEntitiesCacheService mockCacheServiceLinked;
    late MockProjectRepository mockProjectRepositoryLinked;
    late ProviderContainer containerLinked;
    late AiInputRepository repositoryLinked;

    final testDate = DateTime(2025, 12, 20, 14, 30);
    final createdDate = DateTime(2025, 12, 15, 10);
    const taskId = 'task-123';
    const childTaskId = 'child-task-456';
    const parentTaskId = 'parent-task-789';

    setUp(() async {
      mockDbLinked = MockJournalDb();
      mockTaskProgressRepositoryLinked = _ComputingTaskProgressRepository();
      mockPersistenceLogicLinked = MockPersistenceLogic();
      mockCacheServiceLinked = MockEntitiesCacheService();
      mockProjectRepositoryLinked = MockProjectRepository();
      containerLinked = ProviderContainer(
        overrides: [
          taskProgressRepositoryProvider.overrideWithValue(
            mockTaskProgressRepositoryLinked,
          ),
          projectRepositoryProvider.overrideWithValue(
            mockProjectRepositoryLinked,
          ),
        ],
      );

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockDbLinked)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogicLinked)
            ..registerSingleton<EntitiesCacheService>(mockCacheServiceLinked);
        },
      );

      repositoryLinked = containerLinked.read(aiInputRepositoryProvider);

      // Default mocks
      when(
        () => mockTaskProgressRepositoryLinked.getTaskProgressData(
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => (null, <String, TimeRange>{}));
      when(
        () => mockDbLinked.journalEntityById(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockDbLinked.getLinkedEntities(any()),
      ).thenAnswer((_) async => <JournalEntity>[]);
      when(
        () => mockDbLinked.getBulkLinkedEntities(any()),
      ).thenAnswer((_) async => <String, List<JournalEntity>>{});
      when(
        () => mockDbLinked.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(() => mockCacheServiceLinked.getLabelById(any())).thenReturn(null);
      when(
        () => mockProjectRepositoryLinked.getProjectForTask(any()),
      ).thenAnswer((_) async => null);
    });

    tearDown(() async {
      containerLinked.dispose();
      await tearDownTestGetIt();
    });

    Task createTestTask({
      required String id,
      required String title,
      TaskStatus? status,
      DateTime? createdAt,
      List<String>? labelIds,
      Duration? estimate,
      String? languageCode,
      DateTime? deletedAt,
    }) {
      final taskStatus =
          status ??
          TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: createdAt ?? createdDate,
            utcOffset: 0,
          );
      return Task(
        meta: Metadata(
          id: id,
          dateFrom: createdAt ?? createdDate,
          dateTo: createdAt ?? createdDate,
          createdAt: createdAt ?? createdDate,
          updatedAt: createdAt ?? createdDate,
          labelIds: labelIds,
          deletedAt: deletedAt,
        ),
        data: TaskData(
          title: title,
          status: taskStatus,
          statusHistory: [],
          dateFrom: createdAt ?? createdDate,
          dateTo: createdAt ?? createdDate,
          estimate: estimate,
          languageCode: languageCode,
        ),
      );
    }

    JournalDbEntity createDbEntityFromTask(Task task) {
      return JournalDbEntity(
        id: task.id,
        createdAt: task.meta.createdAt,
        updatedAt: task.meta.updatedAt,
        dateFrom: task.meta.dateFrom,
        dateTo: task.meta.dateTo,
        deleted: task.meta.deletedAt != null,
        starred: false,
        private: false,
        task: true,
        flag: 0,
        type: 'Task',
        serialized: jsonEncode(task.toJson()),
        schemaVersion: 1,
        plainText: task.data.title,
        category: '',
      );
    }

    /// Creates a JournalEntry with specified duration for time tracking tests.
    JournalEntity createJournalEntryWithDuration({
      required String id,
      required Duration duration,
      DateTime? dateFrom,
    }) {
      final from = dateFrom ?? createdDate;
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          dateFrom: from,
          dateTo: from.add(duration),
          createdAt: from,
          updatedAt: from,
        ),
      );
    }

    group('buildLinkedFromContext', () {
      test('returns empty list when no tasks link to this task', () async {
        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => []);

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result, isEmpty);
        verify(() => mockDbLinked.getLinkedToEntities(taskId)).called(1);
      });

      test('returns context for child tasks linking to this task', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          estimate: const Duration(hours: 2),
          languageCode: 'en',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        // Create a journal entry with 45 minutes duration for time tracking
        final timeEntry = createJournalEntryWithDuration(
          id: 'time-entry-1',
          duration: const Duration(minutes: 45),
        );

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        // Bulk fetch returns entities for time calculation
        when(
          () => mockDbLinked.getBulkLinkedEntities({childTaskId}),
        ).thenAnswer(
          (_) async => {
            childTaskId: [timeEntry],
          },
        );

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(childTaskId));
        expect(result[0].title, equals('Child Task'));
        expect(result[0].status, equals('IN PROGRESS'));
        expect(result[0].estimate, equals('02:00'));
        expect(result[0].timeSpent, equals('00:45'));
        expect(result[0].languageCode, equals('en'));
      });

      test('filters out deleted tasks', () async {
        final deletedTask = createTestTask(
          id: 'deleted-task',
          title: 'Deleted Task',
          status: TaskStatus.open(
            id: 'status-deleted',
            createdAt: createdDate,
            utcOffset: 0,
          ),
          deletedAt: testDate, // Marked as deleted
        );
        final deletedDbEntity = createDbEntityFromTask(deletedTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [deletedDbEntity]);

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result, isEmpty);
      });

      test('sorts tasks by creation date (oldest first)', () async {
        final olderTask = createTestTask(
          id: 'older-task',
          title: 'Older Task',
          createdAt: DateTime(2025, 12, 10),
        );
        final newerTask = createTestTask(
          id: 'newer-task',
          title: 'Newer Task',
          createdAt: DateTime(2025, 12, 20),
        );
        final olderDbEntity = createDbEntityFromTask(olderTask);
        final newerDbEntity = createDbEntityFromTask(newerTask);

        // Return in reverse order to test sorting
        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [newerDbEntity, olderDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: any(named: 'id'),
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(2));
        expect(result[0].title, equals('Older Task'));
        expect(result[1].title, equals('Newer Task'));
      });
    });

    group('buildLinkedToContext', () {
      test('returns empty list when task has no parent links', () async {
        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        final result = await repositoryLinked.buildLinkedToContext(taskId);

        expect(result, isEmpty);
        verify(() => mockDbLinked.getLinkedEntities(taskId)).called(1);
      });

      test('returns context for parent tasks this task links to', () async {
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Epic',
          status: TaskStatus.inProgress(
            id: 'status-parent',
            createdAt: createdDate,
            utcOffset: 0,
          ),
          estimate: const Duration(hours: 40),
        );

        // Create time entry for 12 hours 30 minutes
        final timeEntry = createJournalEntryWithDuration(
          id: 'work-entry',
          duration: const Duration(hours: 12, minutes: 30),
        );

        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [parentTask]);
        // Bulk fetch returns entities for time calculation
        when(
          () => mockDbLinked.getBulkLinkedEntities({parentTaskId}),
        ).thenAnswer(
          (_) async => {
            parentTaskId: [timeEntry],
          },
        );

        final result = await repositoryLinked.buildLinkedToContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(parentTaskId));
        expect(result[0].title, equals('Parent Epic'));
        expect(result[0].estimate, equals('40:00'));
        expect(result[0].timeSpent, equals('12:30'));
      });

      test('filters out deleted parent tasks', () async {
        final deletedParent = createTestTask(
          id: 'deleted-parent',
          title: 'Deleted Parent',
          deletedAt: testDate, // Marked as deleted
        );

        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [deletedParent]);

        final result = await repositoryLinked.buildLinkedToContext(taskId);

        expect(result, isEmpty);
      });

      test(
        'buildLinkedTasksJson combines both directions in one JSON document',
        () async {
          final childTask = createTestTask(
            id: childTaskId,
            title: 'Child Task',
          );
          final parentTask = createTestTask(
            id: parentTaskId,
            title: 'Parent Epic',
          );

          // linked_from: children linking TO this task (raw DB rows).
          when(
            () => mockDbLinked.getLinkedToEntities(taskId),
          ).thenAnswer((_) async => [createDbEntityFromTask(childTask)]);
          // linked_to: parents this task links to.
          when(
            () => mockDbLinked.getLinkedEntities(taskId),
          ).thenAnswer((_) async => [parentTask]);
          when(
            () => mockDbLinked.getBulkLinkedEntities(any()),
          ).thenAnswer((_) async => {});

          final json = await repositoryLinked.buildLinkedTasksJson(taskId);
          final decoded = jsonDecode(json) as Map<String, dynamic>;

          expect(decoded.keys, containsAll(['linked_from', 'linked_to']));
          final linkedFrom = decoded['linked_from'] as List<dynamic>;
          final linkedTo = decoded['linked_to'] as List<dynamic>;
          expect(
            (linkedFrom.single as Map<String, dynamic>)['id'],
            childTaskId,
          );
          expect(
            (linkedTo.single as Map<String, dynamic>)['id'],
            parentTaskId,
          );
        },
      );

      test('filters non-Task entities from results', () async {
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Task',
        );
        final journalEntry = JournalEntry(
          meta: Metadata(
            id: 'entry-1',
            dateFrom: createdDate,
            dateTo: createdDate,
            createdAt: createdDate,
            updatedAt: createdDate,
          ),
          entryText: const EntryText(plainText: 'Some entry'),
        );

        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [parentTask, journalEntry]);
        when(
          () => mockDbLinked.getLinkedEntities(parentTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: parentTaskId,
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        final result = await repositoryLinked.buildLinkedToContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(parentTaskId));
      });
    });

    group('buildLinkedTasksJson', () {
      test('returns JSON with empty arrays when no linked tasks', () async {
        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        final result = await repositoryLinked.buildLinkedTasksJson(taskId);
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        expect(parsed['linked_from'], isA<List<dynamic>>());
        expect((parsed['linked_from'] as List<dynamic>).isEmpty, isTrue);
        expect(parsed['linked_to'], isA<List<dynamic>>());
        expect((parsed['linked_to'] as List<dynamic>).isEmpty, isTrue);
        expect(parsed['note'], isNull);
      });

      test('does not include note (note is added by prompt builder)', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockDbLinked.getBulkLinkedEntities({childTaskId}),
        ).thenAnswer((_) async => {childTaskId: <JournalEntity>[]});

        final result = await repositoryLinked.buildLinkedTasksJson(taskId);
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        // Note is intentionally NOT included in repository output
        // The prompt builder is responsible for adding contextual notes
        expect(parsed['note'], isNull);
        expect(parsed['linked_from'], isNotEmpty);
      });

      test('produces valid JSON that can be parsed', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          labelIds: ['label-1'],
          languageCode: 'de',
        );
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Epic',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [parentTask]);
        when(
          () => mockDbLinked.getLinkedEntities(childTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockDbLinked.getLinkedEntities(parentTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: any(named: 'id'),
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        // Use cache service for label lookups
        when(() => mockCacheServiceLinked.getLabelById('label-1')).thenReturn(
          LabelDefinition(
            id: 'label-1',
            name: 'Test Label',
            color: '#FF0000',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );

        final result = await repositoryLinked.buildLinkedTasksJson(taskId);

        expect(() => jsonDecode(result), returnsNormally);

        final parsed = jsonDecode(result) as Map<String, dynamic>;
        expect(parsed['linked_from'], isA<List<dynamic>>());
        expect(parsed['linked_to'], isA<List<dynamic>>());
        expect((parsed['linked_from'] as List<dynamic>).length, equals(1));
        expect((parsed['linked_to'] as List<dynamic>).length, equals(1));
      });
    });

    group('_getLatestTaskSummary', () {
      test('returns null when task has no AI summaries', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(childTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: childTaskId,
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNull);
      });

      test('returns latest summary when AI response exists', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final summaryEntry = AiResponseEntry(
          meta: Metadata(
            id: 'summary-1',
            dateFrom: testDate,
            dateTo: testDate,
            createdAt: testDate,
            updatedAt: testDate,
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response:
                'This is the task summary with\n## Links\n- [PR #123](https://github.com/org/repo/pull/123)',
            // ignore: deprecated_member_use_from_same_package
            type: AiResponseType.taskSummary,
          ),
        );

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        // Bulk fetch returns the AI summary entry
        when(
          () => mockDbLinked.getBulkLinkedEntities({childTaskId}),
        ).thenAnswer(
          (_) async => {
            childTaskId: [summaryEntry],
          },
        );

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNotNull);
        expect(result[0].latestSummary, contains('task summary'));
        expect(result[0].latestSummary, contains('[PR #123]'));
      });

      test('returns most recent summary when multiple exist', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final olderSummary = AiResponseEntry(
          meta: Metadata(
            id: 'summary-old',
            dateFrom: DateTime(2025, 12, 10),
            dateTo: DateTime(2025, 12, 10),
            createdAt: DateTime(2025, 12, 10),
            updatedAt: DateTime(2025, 12, 10),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'Old summary',
            // ignore: deprecated_member_use_from_same_package
            type: AiResponseType.taskSummary,
          ),
        );

        final newerSummary = AiResponseEntry(
          meta: Metadata(
            id: 'summary-new',
            dateFrom: DateTime(2025, 12, 20),
            dateTo: DateTime(2025, 12, 20),
            createdAt: DateTime(2025, 12, 20),
            updatedAt: DateTime(2025, 12, 20),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'Newer summary - this is the latest',
            // ignore: deprecated_member_use_from_same_package
            type: AiResponseType.taskSummary,
          ),
        );

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        // Return in wrong order to test sorting
        when(
          () => mockDbLinked.getBulkLinkedEntities({childTaskId}),
        ).thenAnswer(
          (_) async => {
            childTaskId: [olderSummary, newerSummary],
          },
        );

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(
          result[0].latestSummary,
          equals('Newer summary - this is the latest'),
        );
      });

      test('ignores non-taskSummary AI responses', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final imageAnalysis = AiResponseEntry(
          meta: Metadata(
            id: 'image-analysis',
            dateFrom: testDate,
            dateTo: testDate,
            createdAt: testDate,
            updatedAt: testDate,
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'This is image analysis, not a summary',
            type: AiResponseType.imageAnalysis,
          ),
        );

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(childTaskId),
        ).thenAnswer((_) async => [imageAnalysis]);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: childTaskId,
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNull);
      });
    });

    group('label resolution', () {
      test('resolves label IDs to names', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          labelIds: ['label-1', 'label-2'],
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(childTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: childTaskId,
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        // Use cache service for label lookups (O(1) per label)
        when(() => mockCacheServiceLinked.getLabelById('label-1')).thenReturn(
          LabelDefinition(
            id: 'label-1',
            name: 'Frontend',
            color: '#FF0000',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );
        when(() => mockCacheServiceLinked.getLabelById('label-2')).thenReturn(
          LabelDefinition(
            id: 'label-2',
            name: 'Bug',
            color: '#00FF00',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].labels.length, equals(2));
        final labelNames = result[0].labels.map((l) => l['name']).toSet();
        expect(labelNames, contains('Frontend'));
        expect(labelNames, contains('Bug'));
      });

      test('returns empty labels list when task has no labels', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        when(
          () => mockDbLinked.getLinkedToEntities(taskId),
        ).thenAnswer((_) async => [childDbEntity]);
        when(
          () => mockDbLinked.getLinkedEntities(childTaskId),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskProgressRepositoryLinked.getTaskProgressData(
            id: childTaskId,
          ),
        ).thenAnswer((_) async => (null, <String, TimeRange>{}));

        final result = await repositoryLinked.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].labels, isEmpty);
      });
    });
  });
}
