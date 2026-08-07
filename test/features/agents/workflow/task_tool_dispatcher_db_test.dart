import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
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
}
