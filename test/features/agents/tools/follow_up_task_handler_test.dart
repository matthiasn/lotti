import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/follow_up_task_handler.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late FollowUpTaskHandler handler;

  const sourceTaskId = 'source-task-001';
  const categoryId = 'cat-001';
  final testDate = DateTime(2024, 6, 15, 12);

  Task makeSourceTask({String? taskCategoryId = categoryId}) {
    return Task(
      meta: Metadata(
        id: sourceTaskId,
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        categoryId: taskCategoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: sourceTaskId,
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        statusHistory: [],
        title: 'Source Task',
      ),
    );
  }

  Task makeNewTask(String id) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: testDate,
        dateTo: testDate,
        createdAt: testDate,
        updatedAt: testDate,
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Follow-Up Task',
      ),
    );
  }

  late MockDomainLogger mockDomainLogger;

  late MockEntitiesCacheService mockEntitiesCache;

  setUp(() async {
    await getIt.reset();
    mockEntitiesCache = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCache);

    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockDomainLogger = MockDomainLogger();

    handler = FollowUpTaskHandler(
      persistenceLogic: mockPersistenceLogic,
      journalDb: mockJournalDb,
      domainLogger: mockDomainLogger,
    );

    // Stub the verify-lookup that follow_up_task_handler performs after
    // creating a task. Individual tests override for specific IDs.
    when(
      () => mockJournalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);

    // Stub EntitiesCacheService.getCategoryById — returns a category with
    // defaultProfileId for the known categoryId, null otherwise.
    when(() => mockEntitiesCache.getCategoryById(categoryId)).thenReturn(
      CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        color: '#0000FFFF',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        active: true,
        private: false,
        defaultProfileId: 'profile-from-category',
      ),
    );
    when(
      () => mockEntitiesCache.getCategoryById(
        any(that: isNot(equals(categoryId))),
      ),
    ).thenReturn(null);

    // Stub DomainLogger methods so verification works.
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.error(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('FollowUpTaskHandler', () {
    group('validation', () {
      test('returns failure when title is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          <String, dynamic>{},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
        expect(result.errorMessage, 'Missing or empty title');
      });

      test('returns failure when title is empty', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'title': '   '},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
      });

      test('returns failure when title is non-string', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'title': 42},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
      });

      test('returns failure when priority is malformed string', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        final result = await handler.handle(
          sourceTaskId,
          {'title': 'Follow-Up', 'priority': 'URGENT'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('must be one of P0, P1, P2, P3'));
        expect(result.errorMessage, 'Invalid priority');
      });

      test('returns failure when priority is non-string type', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        final result = await handler.handle(
          sourceTaskId,
          {'title': 'Follow-Up', 'priority': 42},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('must be one of P0, P1, P2, P3'));
        expect(result.errorMessage, 'Invalid priority');
      });

      test('returns failure when dueDate is malformed', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        final result = await handler.handle(
          sourceTaskId,
          {'title': 'Follow-Up', 'dueDate': 'not-a-date'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('must be a valid YYYY-MM-DD date'));
        expect(result.errorMessage, 'Invalid dueDate');
      });

      test('returns failure when source task not found', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'title': 'Follow-Up'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('not found or not a Task'));
        expect(result.errorMessage, 'Source task lookup failed');
      });
    });

    group('task creation', () {
      test('creates task with correct title and default priority', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-001');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Follow-Up'},
          );

          expect(result.success, isTrue);
          expect(result.output, contains('Follow-Up'));
          expect(result.output, contains('new-task-001'));
          expect(result.mutatedEntityId, 'new-task-001');

          // Verify task data passed to createTaskEntry.
          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.title, 'Follow-Up');
          expect(taskData.priority, TaskPriority.p2Medium);

          // Category inherited from source.
          expect(captured[1], categoryId);
        });
      });

      test('creates task with custom priority and due date', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-002');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'title': 'Urgent Follow-Up',
              'priority': 'P1',
              'dueDate': '2024-12-31',
              'description': 'Some details',
            },
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: captureAny(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.priority, TaskPriority.p1High);
          expect(taskData.due, DateTime(2024, 12, 31));
        });
      });

      test('returns failure when createTaskEntry returns null', () async {
        final sourceTask = makeSourceTask();

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Will Fail'},
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, 'Task creation failed');
        });
      });
    });

    group('link creation', () {
      test('creates link from source to new task', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-003');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'Linked Task'},
          );

          verify(
            () => mockPersistenceLogic.createLink(
              fromId: sourceTaskId,
              toId: 'new-task-003',
            ),
          ).called(1);
        });
      });
    });

    group('link failure warnings', () {
      test('surfaces link failure warning in output', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-link-fail');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenThrow(Exception('DB connection lost'));

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Link Fail Task'},
          );

          // Task creation still succeeds — link failure is a warning.
          expect(result.success, isTrue);
          expect(result.mutatedEntityId, 'new-task-link-fail');
          expect(result.output, contains('Warning'));
          expect(result.output, contains('failed to link source task'));
        });
      });

      test('surfaces warning when createLink returns false', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-link-false');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        // createLink returns false instead of throwing.
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => false);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Bool Fail Task'},
          );

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, 'new-task-link-false');
          expect(result.output, contains('Warning'));
          expect(result.output, contains('failed to link source task'));
        });
      });
    });

    group('domain logging', () {
      test('logs verify-lookup after task creation', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-log');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'Logged Task'},
          );

          verify(
            () => mockDomainLogger.log(
              LogDomains.agentWorkflow,
              any(that: contains('Created task new-task-log')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });

      test('logs error when source link throws exception', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-err');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenThrow(Exception('DB error'));

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'Error Task'},
          );

          verify(
            () => mockDomainLogger.error(
              LogDomains.agentWorkflow,
              any(
                that: contains(
                  'Failed to link source $sourceTaskId',
                ),
              ),
              error: any(named: 'error'),
              subDomain: any(named: 'subDomain'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);
        });
      });
    });

    group('category inheritance', () {
      test('inherits profileId from category defaults', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-profile');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Profile Inherited'},
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.profileId, 'profile-from-category');
        });
      });

      test('sets null profileId when source has no category', () async {
        final sourceTask = makeSourceTask(taskCategoryId: null);
        final newTask = makeNewTask('new-task-no-profile');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'No Profile'},
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.profileId, isNull);
        });
      });

      test('does not auto-assign when no taskAgentService provided', () async {
        // handler is constructed without taskAgentService (default setUp).
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-no-autoassign');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'No Auto-Assign'},
          );

          expect(result.success, isTrue);
          // No warnings about auto-assign since there's no service.
          expect(result.output, isNot(contains('auto-assign')));
        });
      });

      test('inherits null category when source has none', () async {
        final sourceTask = makeSourceTask(taskCategoryId: null);
        final newTask = makeNewTask('new-task-006');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'No Category'},
          );

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;

          expect(captured[0], isNull);
        });
      });
    });

    group('agent auto-assignment', () {
      late MockTaskAgentService mockTaskAgentService;
      late FollowUpTaskHandler handlerWithAgent;

      setUp(() {
        mockTaskAgentService = MockTaskAgentService();

        handlerWithAgent = FollowUpTaskHandler(
          persistenceLogic: mockPersistenceLogic,
          journalDb: mockJournalDb,
          domainLogger: mockDomainLogger,
          taskAgentService: mockTaskAgentService,
        );

        when(
          () => mockTaskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.agent(
                    id: 'agent-id',
                    agentId: 'agent-id',
                    kind: 'task_agent',
                    displayName: 'Auto-Assigned Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: {},
                    currentStateId: 'state-1',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    vectorClock: null,
                  )
                  as AgentIdentityEntity,
        );
      });

      test('calls createTaskAgent with category defaults', () async {
        // Override the category stub to include a defaultTemplateId.
        when(() => mockEntitiesCache.getCategoryById(categoryId)).thenReturn(
          CategoryDefinition(
            id: categoryId,
            name: 'Test Category',
            color: '#0000FFFF',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
            active: true,
            private: false,
            defaultProfileId: 'profile-from-category',
            defaultTemplateId: 'template-from-category',
          ),
        );

        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-autoassign');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithAgent.handle(
            sourceTaskId,
            {'title': 'Auto-Assigned Task'},
          );

          expect(result.success, isTrue);
          expect(result.output, isNot(contains('auto-assign')));

          verify(
            () => mockTaskAgentService.createTaskAgent(
              taskId: 'new-task-autoassign',
              templateId: 'template-from-category',
              profileId: 'profile-from-category',
              allowedCategoryIds: {categoryId},
              awaitContent: true,
            ),
          ).called(1);
        });
      });

      test(
        'skips auto-assign when category has no defaultTemplateId',
        () async {
          // Default stub has no defaultTemplateId.
          final sourceTask = makeSourceTask();
          final newTask = makeNewTask('new-task-no-template');

          when(
            () => mockJournalDb.journalEntityById(sourceTaskId),
          ).thenAnswer((_) async => sourceTask);

          when(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => newTask);

          when(
            () => mockPersistenceLogic.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          ).thenAnswer((_) async => true);

          await withClock(Clock.fixed(testDate), () async {
            final result = await handlerWithAgent.handle(
              sourceTaskId,
              {'title': 'No Template Task'},
            );

            expect(result.success, isTrue);

            verifyNever(
              () => mockTaskAgentService.createTaskAgent(
                taskId: any(named: 'taskId'),
                templateId: any(named: 'templateId'),
                profileId: any(named: 'profileId'),
                allowedCategoryIds: any(named: 'allowedCategoryIds'),
                awaitContent: any(named: 'awaitContent'),
              ),
            );
          });
        },
      );

      test('surfaces warning when createTaskAgent throws', () async {
        when(() => mockEntitiesCache.getCategoryById(categoryId)).thenReturn(
          CategoryDefinition(
            id: categoryId,
            name: 'Test Category',
            color: '#0000FFFF',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
            active: true,
            private: false,
            defaultProfileId: 'profile-from-category',
            defaultTemplateId: 'template-from-category',
          ),
        );

        when(
          () => mockTaskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenThrow(Exception('Agent creation failed'));

        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-agent-fail');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithAgent.handle(
            sourceTaskId,
            {'title': 'Agent Fail Task'},
          );

          // Task creation still succeeds — agent failure is a warning.
          expect(result.success, isTrue);
          expect(result.mutatedEntityId, 'new-task-agent-fail');
          expect(result.output, contains('failed to auto-assign agent'));
        });
      });

      test('skips auto-assign when source has no category', () async {
        final sourceTask = makeSourceTask(taskCategoryId: null);
        final newTask = makeNewTask('new-task-no-cat-agent');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithAgent.handle(
            sourceTaskId,
            {'title': 'No Cat Agent Task'},
          );

          expect(result.success, isTrue);

          verifyNever(
            () => mockTaskAgentService.createTaskAgent(
              taskId: any(named: 'taskId'),
              templateId: any(named: 'templateId'),
              profileId: any(named: 'profileId'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              awaitContent: any(named: 'awaitContent'),
            ),
          );
        });
      });
    });

    group('project inheritance', () {
      late MockProjectRepository mockProjectRepo;
      late FollowUpTaskHandler handlerWithProject;

      final testProject = ProjectEntry(
        meta: Metadata(
          id: 'project-001',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          categoryId: categoryId,
        ),
        data: ProjectData(
          title: 'Test Project',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      setUp(() {
        mockProjectRepo = MockProjectRepository();
        handlerWithProject = FollowUpTaskHandler(
          persistenceLogic: mockPersistenceLogic,
          journalDb: mockJournalDb,
          domainLogger: mockDomainLogger,
          projectRepository: mockProjectRepo,
        );
      });

      test('inherits project from source task', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-proj');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockProjectRepo.getProjectForTask(sourceTaskId),
        ).thenAnswer((_) async => testProject);

        when(
          () => mockProjectRepo.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithProject.handle(
            sourceTaskId,
            {'title': 'Inherits Project'},
          );

          expect(result.success, isTrue);
          expect(result.output, isNot(contains('failed to inherit project')));

          verify(
            () => mockProjectRepo.linkTaskToProject(
              projectId: 'project-001',
              taskId: 'new-task-proj',
            ),
          ).called(1);
        });
      });

      test('skips project inheritance when source has no project', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-no-proj');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockProjectRepo.getProjectForTask(sourceTaskId),
        ).thenAnswer((_) async => null);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithProject.handle(
            sourceTaskId,
            {'title': 'No Project Source'},
          );

          expect(result.success, isTrue);

          verifyNever(
            () => mockProjectRepo.linkTaskToProject(
              projectId: any(named: 'projectId'),
              taskId: any(named: 'taskId'),
            ),
          );
        });
      });

      test('surfaces warning when project linking fails', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-proj-fail');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockProjectRepo.getProjectForTask(sourceTaskId),
        ).thenAnswer((_) async => testProject);

        when(
          () => mockProjectRepo.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenThrow(Exception('DB error'));

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithProject.handle(
            sourceTaskId,
            {'title': 'Project Link Fail'},
          );

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, 'new-task-proj-fail');
          expect(result.output, contains('failed to inherit project'));
        });
      });

      test('surfaces warning when linkTaskToProject returns false', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-proj-false');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockProjectRepo.getProjectForTask(sourceTaskId),
        ).thenAnswer((_) async => testProject);

        when(
          () => mockProjectRepo.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => false);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handlerWithProject.handle(
            sourceTaskId,
            {'title': 'Project Link False'},
          );

          expect(result.success, isTrue);
          expect(result.output, contains('failed to inherit project'));
        });
      });

      test('does not inherit project when no repository provided', () async {
        // Default handler has no projectRepository.
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-no-repo');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'No Repo Task'},
          );

          expect(result.success, isTrue);
          // No project-related warnings since there's no repository.
          expect(result.output, isNot(contains('project')));
        });
      });
    });
  });
}
