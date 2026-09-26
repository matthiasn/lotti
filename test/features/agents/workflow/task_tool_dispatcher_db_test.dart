import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_action_service.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../query/query_test_utils.dart';

part 'task_tool_dispatcher_idempotency.dart';

/// Dispatcher behaviour against real databases rather than mocks.
///
/// The inference eval records tool calls without executing them, so it cannot
/// answer whether a call actually changes stored data. These tests run
/// [TaskToolDispatcher] over a real in-memory [JournalDb] with the real
/// [ChecklistRepository] and [PersistenceLogic], and assert on rows read back
/// afterwards — which is the only way to prove that the argument recovery added
/// for small models reaches persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockOutboxService = MockOutboxService();
  final mockTimeService = MockTimeService();
  final mockNavService = MockNavService();

  late JournalDb journalDb;
  late SettingsDb settingsDb;
  late TaskToolDispatcher dispatcher;
  late Task task;
  late String checklistItemId;
  late String checklistId;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    setFakeDocumentsPath();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    await initConfigFlags(journalDb, inMemoryDatabase: true);

    when(mockNotificationService.updateBadge).thenAnswer((_) async {});
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(
      () => mockFts5Db.insertText(any(), removePrevious: true),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationService.cancelNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});

    final documentsDirectory = await getApplicationDocumentsDirectory();
    await setUpTestGetIt(
      additionalSetup: () {
        // setUpTestGetIt already provides several of these, so replace rather
        // than register: the point of this suite is real databases behind the
        // same service locator the app uses.
        void put<T extends Object>(T instance) {
          if (getIt.isRegistered<T>()) getIt.unregister<T>();
          getIt.registerSingleton<T>(instance);
        }

        put<UpdateNotifications>(mockUpdateNotifications);
        put<Directory>(documentsDirectory);
        put<SettingsDb>(settingsDb);
        put<Fts5Db>(mockFts5Db);
        put<JournalDb>(journalDb);
        put<OutboxService>(mockOutboxService);
        put<NotificationService>(mockNotificationService);
        put<VectorClockService>(VectorClockService());
        put<TimeService>(mockTimeService);
        put<NavService>(mockNavService);
        put<EntitiesCacheService>(MockEntitiesCacheService());
        put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
        put<MetadataService>(
          MetadataService(vectorClockService: getIt<VectorClockService>()),
        );
        put<GeolocationService>(MockGeolocationService());
        put<PersistenceLogic>(PersistenceLogic());
      },
    );

    // A real task with a real checklist, stored in the real database.
    task = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'db-eval-task',
        categoryId: 'db-eval-category',
      ),
      data: testTask.data.copyWith(title: 'Rotate signing certificate'),
    );
    await getIt<PersistenceLogic>().createDbEntity(task);
    expect(
      await journalDb.journalEntityById(task.meta.id),
      isA<Task>(),
      reason: 'seed task must be retrievable before the dispatcher runs',
    );

    final created = await ChecklistRepository().createChecklist(
      taskId: task.meta.id,
      items: [
        const ChecklistItemData(
          title: 'Interview five customers',
          isChecked: false,
          linkedChecklists: [],
        ),
      ],
      title: 'Launch checks',
    );
    expect(
      created.createdItems,
      isNotEmpty,
      reason: 'seed checklist must have a real item to toggle',
    );
    checklistItemId = created.createdItems.first.id;
    checklistId = created.checklist!.meta.id;

    dispatcher = TaskToolDispatcher(
      journalDb: journalDb,
      journalRepository: JournalRepository(),
      checklistRepository: ChecklistRepository(),
      labelsRepository: LabelsRepository(
        getIt<PersistenceLogic>(),
        journalDb,
        getIt<EntitiesCacheService>(),
        getIt<DomainLogger>(),
        getIt<UpdateNotifications>(),
      ),
      persistenceLogic: getIt<PersistenceLogic>(),
      timeService: mockTimeService,
    );
  });

  tearDown(() async {
    await tearDownTestGetIt();
    await journalDb.close();
    await settingsDb.close();
  });

  group('TaskToolDispatcher against a real database', () {
    test('a double-encoded items array still checks the item off', () async {
      // Verbatim shape from Qwen3.6 35B A3B: correct contents, wrong encoding.
      // Before argument recovery this died on `items is! List` and the user's
      // checkbox never moved.
      final result = await dispatcher.dispatch(
        TaskAgentToolNames.updateChecklistItems,
        {
          'items':
              '[{"id": "$checklistItemId", "isChecked": true, '
              '"reason": "Log from 2026-07-10 states interviews are complete"}]',
        },
        task.meta.id,
      );

      expect(result.success, isTrue, reason: result.errorMessage);

      final stored = await journalDb.journalEntityById(checklistItemId);
      expect(
        stored,
        isA<ChecklistItem>().having(
          (item) => item.data.isChecked,
          'isChecked',
          isTrue,
        ),
        reason: 'The checkbox must actually move in the database',
      );
    });

    test('a properly encoded items array behaves identically', () async {
      final result = await dispatcher.dispatch(
        TaskAgentToolNames.updateChecklistItems,
        {
          'items': [
            {
              'id': checklistItemId,
              'isChecked': true,
              // Checklist sovereignty requires a reason to override an item;
              // without one the change is rejected, which is correct.
              'reason': 'Log from 2026-07-10 states interviews are complete',
            },
          ],
        },
        task.meta.id,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      final stored = await journalDb.journalEntityById(checklistItemId);
      expect((stored! as ChecklistItem).data.isChecked, isTrue);
    });

    test('a fabricated tool name reaches the real handler', () async {
      // DeepSeek V4 Flash 0731 called `update_task_status`; the real tool is
      // `set_task_status`. Without alias resolution the status never changed.
      final result = await dispatcher.dispatch(
        'update_task_status',
        {'status': 'BLOCKED', 'reason': 'Waiting on the supplier'},
        task.meta.id,
      );

      expect(
        result.output,
        isNot(contains('Unknown tool')),
        reason: 'The alias must route to set_task_status',
      );
      // Routing to the handler is not the point — the status actually moving
      // is. Read the task back rather than trusting the dispatch result.
      final stored = await journalDb.journalEntityById(task.meta.id);
      expect(
        (stored! as Task).data.status,
        isA<TaskBlocked>(),
        reason: 'The aliased call must persist the requested status',
      );
    });

    test('an unrelated unknown tool is still rejected', () async {
      final result = await dispatcher.dispatch(
        'delete_everything',
        const <String, dynamic>{},
        task.meta.id,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Unknown tool'));
    });

    test('malformed JSON in items is reported, not silently dropped', () async {
      final result = await dispatcher.dispatch(
        TaskAgentToolNames.updateChecklistItems,
        {'items': '[{"id": broken'},
        task.meta.id,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('items'));
      final stored = await journalDb.journalEntityById(checklistItemId);
      expect((stored! as ChecklistItem).data.isChecked, isFalse);
    });
  });

  _registerIdempotency(
    () => (
      db: journalDb,
      dispatcher: dispatcher,
      task: task,
      checklistId: checklistId,
      checklistItemId: checklistItemId,
    ),
  );

  group('chat approval end to end', () {
    late QueryPersistenceBench bench;
    late QueryChatActionService service;
    late String chat;
    late String question;
    late String memoItemId;

    Future<ChecklistItem> stored(String id) async =>
        (await journalDb.journalEntityById(id))! as ChecklistItem;

    /// The builder a task-agent wake creates, with the wake's own resolver.
    ChangeSetBuilder wakeBuilder() => ChangeSetBuilder(
      agentId: 'agent',
      taskId: task.meta.id,
      threadId: 'wake',
      runKey: 'wake-run',
      approvedChecklistItemResolver: journalChecklistItemResolver(journalDb),
    );

    setUp(() async {
      memoItemId = (await ChecklistRepository().addItemToChecklist(
        checklistId: checklistId,
        title: 'Draft the launch memo',
        isChecked: false,
        categoryId: task.meta.categoryId,
      ))!.id;

      // The chat's own authorization reads the task through query access.
      bench = QueryPersistenceBench();
      bench.entries[task.meta.id] = task.copyWith(
        meta: task.meta.copyWith(categoryId: null, private: false),
      );
      const scope = QueryScope(kind: QueryScopeKind.task, id: 'db-eval-task');
      chat = await bench.store.create('agent', scope, 'Launch');
      final asked = await bench.store.ask(
        'agent',
        chat,
        'Interviews are done and the memo is really a send-out, update both.',
      );
      question = asked.id;
      await bench.store.publish(
        'agent',
        chat,
        QueryBuiltAnswer(
          answer: QueryChatAnswer(
            questionId: question,
            text: 'Review these changes.',
            coverage: const QueryCoverage(),
            dependencies: (asked.data as QueryChatQuestion).dependencies,
            proposedActions: [
              ChangeItem(
                toolName: TaskAgentToolNames.updateChecklistItem,
                args: {'id': checklistItemId, 'isChecked': true},
                humanSummary: 'Check interviews',
              ),
              ChangeItem(
                toolName: TaskAgentToolNames.updateChecklistItem,
                args: {'id': memoItemId, 'title': 'Send the launch memo'},
                humanSummary: 'Rename memo',
              ),
            ],
          ),
        ),
      );
      service = QueryChatActionService(
        store: bench.store,
        enabled: () => true,
        labels: MockLabelsRepository(),
        readContext: (taskId, _) async => QueryTaskActionContext(
          taskId: taskId,
          input: const <String, dynamic>{},
          dependencies: const <QuerySourceRef>[],
          // Despite its name, the set of checklist item ids the chat may edit.
          checklistIds: {checklistItemId, memoItemId},
        ),
        // Production wiring: the real dispatcher over the real journal.
        dispatch: dispatcher.dispatchApproved,
      );
    });
    tearDown(() => bench.close());

    test(
      'approved changes carry their provenance and bind the task agent',
      () async {
        // One change confirmed on its own row, the rest with Accept all.
        final first = await service.resolveItem(
          agentId: 'agent',
          chatId: chat,
          questionId: question,
          itemIndex: 0,
          approved: true,
        );
        expect(first?.success, isTrue, reason: first?.errorMessage);
        final rest = await service.resolve(
          agentId: 'agent',
          chatId: chat,
          questionId: question,
          approved: true,
        );
        expect(rest.map((r) => r.success), [true]);

        // 1. The journal holds the change and who authorised it.
        final interviews = (await stored(checklistItemId)).data;
        expect(interviews.isChecked, isTrue);
        expect(interviews.checkedBy, ChangeSource.user);
        final checkApproval = interviews.checkedStateApproval!;
        expect(checkApproval.approvedBy, 'user');
        expect(checkApproval.approvalMode, ChecklistApprovalMode.individual);
        expect(checkApproval.originatingMessageId, question);
        expect(checkApproval.conversationId, chat);
        expect(checkApproval.changeSetId, 'query-chat:$question:actions');
        final memo = (await stored(memoItemId)).data;
        expect(memo.title, 'Send the launch memo');
        expect(
          memo.titleApproval?.approvalMode,
          ChecklistApprovalMode.confirmAll,
        );
        expect(memo.currentChatApproval, isNotNull);

        // 2. A later wake cannot propose reversing either change, however it
        //    argues — and says why, so the model does not retry.
        final wake = wakeBuilder();
        final batch = await wake.addBatchItem(
          toolName: TaskAgentToolNames.updateChecklistItems,
          args: {
            'items': [
              {
                'id': checklistItemId,
                'isChecked': false,
                'reason':
                    'No evidence of completed interviews in the task log.',
              },
              {'id': memoItemId, 'title': 'Draft the launch memo'},
            ],
          },
          summaryPrefix: 'Update',
        );
        expect(batch.added, 0);
        expect(batch.rejected, 2);
        expect(wake.items, isEmpty);

        // 3. Even a reversal that reached execution is refused and retracted.
        final stale = await dispatcher.dispatch(
          TaskAgentToolNames.updateChecklistItems,
          {
            'items': [
              {
                'id': checklistItemId,
                'isChecked': false,
                'reason':
                    'No evidence of completed interviews in the task log.',
              },
            ],
          },
          task.meta.id,
        );
        expect(stale.success, isFalse);
        expect(stale.nonRetryable, isTrue);
        expect((await stored(checklistItemId)).data.isChecked, isTrue);

        // 4. The user's own later edit — even back to the approved title —
        //    ends the approval, and the agent may propose again.
        final repository = ChecklistRepository();
        for (final title in ['Send the memo', 'Send the launch memo']) {
          await repository.updateChecklistItem(
            checklistItemId: memoItemId,
            change: (stored) => stored.copyWith(title: title),
            taskId: task.meta.id,
          );
        }
        expect((await stored(memoItemId)).data.titleApproval, isNull);
        expect(
          await wakeBuilder().addItem(
            toolName: TaskAgentToolNames.updateChecklistItem,
            args: {'id': memoItemId, 'title': 'Draft the launch memo'},
            humanSummary: 'Rename memo',
          ),
          isNull,
        );
      },
    );
  });
}
