import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';

class TestPersistenceLogic extends PersistenceLogic {
  TestPersistenceLogic({this.updateDbEntityHandler});

  final Future<bool?> Function(
    JournalEntity entity, {
    String? linkedId,
    bool enqueueSync,
    bool overrideComparison,
    Future<void> Function()? beforeNotify,
  })?
  updateDbEntityHandler;
  int updateMetadataCalls = 0;
  JournalEntity? lastUpdateDbEntity;

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    List<String>? labelIds,
    bool clearLabelIds = false,
    DateTime? deletedAt,
  }) async {
    updateMetadataCalls++;
    return super.updateMetadata(
      metadata,
      dateFrom: dateFrom,
      dateTo: dateTo,
      categoryId: categoryId,
      clearCategoryId: clearCategoryId,
      labelIds: labelIds,
      clearLabelIds: clearLabelIds,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  }) async {
    lastUpdateDbEntity = journalEntity;
    if (updateDbEntityHandler != null) {
      return updateDbEntityHandler!(
        journalEntity,
        linkedId: linkedId,
        enqueueSync: enqueueSync,
        overrideComparison: overrideComparison,
        beforeNotify: beforeNotify,
      );
    }
    return super.updateDbEntity(
      journalEntity,
      linkedId: linkedId,
      enqueueSync: enqueueSync,
      overrideComparison: overrideComparison,
      beforeNotify: beforeNotify,
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SyncMessage.journalEntity(
        id: 'fallback',
        jsonPath: '/fallback.json',
        vectorClock: VectorClock({'host': 1}),
        status: SyncEntryStatus.update,
      ),
    );
    registerFallbackValue(fallbackJournalEntity);
  });

  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLoggingService loggingService;
  late MockOutboxService outboxService;
  late MockFts5Db fts5Db;
  late MockNotificationService notificationService;
  late MockVectorClockService vectorClockService;
  late TestPersistenceLogic logic;
  void stubUpdateResult(JournalUpdateResult result) {
    when(
      () => journalDb.updateJournalEntity(
        any<JournalEntity>(),
        overrideComparison: any<bool>(named: 'overrideComparison'),
        overwrite: any<bool>(named: 'overwrite'),
      ),
    ).thenAnswer((_) async => result);
  }

  JournalEntity buildEntry({
    String id = 'entry-id',
    VectorClock? clock,
  }) {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        vectorClock: clock ?? const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'text'),
    );
  }

  setUp(() async {
    await getIt.reset();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    loggingService = MockLoggingService();
    outboxService = MockOutboxService();
    fts5Db = MockFts5Db();
    notificationService = MockNotificationService();
    vectorClockService = MockVectorClockService();

    when(
      () => fts5Db.insertText(
        any<JournalEntity>(),
        removePrevious: any<bool>(named: 'removePrevious'),
      ),
    ).thenAnswer((_) async {});
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(() => updateNotifications.notify(any<Set<String>>())).thenReturn(null);
    when(
      () => outboxService.enqueueMessage(any<SyncMessage>()),
    ).thenAnswer((_) async {});
    when(
      () => vectorClockService.getNextVectorClock(),
    ).thenAnswer((_) async => const VectorClock({'host': 1}));
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any<VectorClock?>(named: 'previous'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host': 1}));
    when(
      () => vectorClockService.getHost(),
    ).thenAnswer((_) async => 'test-host-id');
    when(
      () => journalDb.addLabeled(any<JournalEntity>()),
    ).thenAnswer((_) async {});
    when(
      () => journalDb.parentLinkedEntityIds(any<String>()),
    ).thenReturn(MockSelectable<String>([]));
    when(
      () => journalDb.updateTaskPriorityColumn(
        id: any(named: 'id'),
        priority: any(named: 'priority'),
        rank: any(named: 'rank'),
      ),
    ).thenAnswer((_) async {});

    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LoggingService>(loggingService)
      ..registerSingleton<OutboxService>(outboxService)
      ..registerSingleton<Fts5Db>(fts5Db)
      ..registerSingleton<NotificationService>(notificationService)
      ..registerSingleton<VectorClockService>(vectorClockService)
      ..registerSingleton<MetadataService>(
        MetadataService(vectorClockService: vectorClockService),
      );

    logic = TestPersistenceLogic();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('updateDbEntity returns true when update applied', () async {
    stubUpdateResult(JournalUpdateResult.applied());

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isTrue);
    verify(() => outboxService.enqueueMessage(any<SyncMessage>())).called(1);
    verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
  });

  test(
    'updateDbEntity logs beforeNotify failures and still propagates changes',
    () async {
      stubUpdateResult(JournalUpdateResult.applied());

      final result = await logic.updateDbEntity(
        buildEntry(),
        beforeNotify: () async => throw Exception('beforeNotify failed'),
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'persistence_logic',
          subDomain: 'updateDbEntity.beforeNotify',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
      verify(() => outboxService.enqueueMessage(any<SyncMessage>())).called(1);
      verify(
        () => fts5Db.insertText(
          any<JournalEntity>(),
          removePrevious: true,
        ),
      ).called(1);
      verify(notificationService.updateBadge).called(1);
    },
  );

  test('updateDbEntity returns false when update skipped', () async {
    stubUpdateResult(
      JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isFalse);
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  test('updateDbEntity returns null on exception', () async {
    when(
      () => journalDb.updateJournalEntity(
        any<JournalEntity>(),
        overrideComparison: any<bool>(named: 'overrideComparison'),
        overwrite: any<bool>(named: 'overwrite'),
      ),
    ).thenThrow(Exception('db down'));

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isNull);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'persistence_logic',
        subDomain: 'updateDbEntity',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('updateDbEntity does not enqueue when enqueueSync is false', () async {
    stubUpdateResult(JournalUpdateResult.applied());

    final result = await logic.updateDbEntity(buildEntry(), enqueueSync: false);

    expect(result, isTrue);
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  test('createDbEntity skips addLabeled when update skipped', () async {
    stubUpdateResult(
      JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );

    final entity = buildEntry(clock: const VectorClock({'host': 5}));
    final saved = await logic.createDbEntity(
      entity,
      shouldAddGeolocation: false,
    );

    expect(saved, isFalse);
    verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  group('updateJournalEntity', () {
    test(
      'adds labels only when update applies and reuses metadata',
      () async {
        final labeledCaptures = <JournalEntity>[];
        when(() => journalDb.addLabeled(captureAny())).thenAnswer((
          invocation,
        ) async {
          labeledCaptures.add(
            invocation.positionalArguments.first as JournalEntity,
          );
        });

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => true,
        );

        final baseEntry = buildEntry();
        final result = await logic.updateJournalEntity(
          baseEntry,
          baseEntry.meta,
        );

        expect(result, isTrue);
        expect(labeledCaptures, hasLength(1));
        final labeledEntity = labeledCaptures.first;
        expect(
          identical(labeledEntity.meta, logic.lastUpdateDbEntity?.meta),
          isTrue,
        );
        expect(logic.updateMetadataCalls, 1);

        clearInteractions(journalDb);
        labeledCaptures.clear();

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => false,
        );

        final skipped = await logic.updateJournalEntity(
          baseEntry,
          baseEntry.meta,
        );

        expect(skipped, isFalse);
        verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
      },
    );

    test(
      'updates task priority columns before notifying listeners for task updates',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final callOrder = <String>[];
        Set<String>? notifiedIds;
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p0Urgent,
          ),
        );

        when(() => journalDb.journalEntityById('task-id')).thenAnswer(
          (_) async => task,
        );
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.updateTaskPriorityColumn(
            id: 'task-id',
            priority: 'P1',
            rank: 1,
          ),
        ).thenAnswer((_) async {
          callOrder.add('priority-column');
        });
        when(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        ).thenAnswer((invocation) {
          callOrder.add('notify');
          notifiedIds = invocation.positionalArguments.first as Set<String>;
        });

        final updatedTask = task.copyWith(
          data: task.data.copyWith(priority: TaskPriority.p1High),
        );
        final result = await logic.updateJournalEntity(
          updatedTask,
          updatedTask.meta,
        );

        expect(result, isTrue);
        expect(callOrder, equals(['priority-column', 'notify']));
        expect(notifiedIds, contains('task-id'));
      },
    );

    test(
      'skips task priority column updates when updateJournalEntity keeps priority unchanged',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p1High,
          ),
        );

        when(
          () => journalDb.journalEntityById('task-id'),
        ).thenAnswer((_) async => task);
        stubUpdateResult(JournalUpdateResult.applied());

        final result = await logic.updateJournalEntity(task, task.meta);

        expect(result, isTrue);
        verifyNever(
          () => journalDb.updateTaskPriorityColumn(
            id: any(named: 'id'),
            priority: any(named: 'priority'),
            rank: any(named: 'rank'),
          ),
        );
      },
    );
  });

  group('agent execution zone routing', () {
    test(
      'updateDbEntity calls notify when outside agent execution zone',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());

        await logic.updateDbEntity(buildEntry());

        verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
        verifyNever(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        );
      },
    );

    test(
      'updateDbEntity calls notifyUiOnly when inside agent execution zone',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        ).thenReturn(null);

        await runZoned(
          () => logic.updateDbEntity(buildEntry()),
          zoneValues: {agentExecutionZoneKey: true},
        );

        verify(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        ).called(1);
        verifyNever(() => updateNotifications.notify(any<Set<String>>()));
      },
    );
  });

  group('updateJournalEntityText - entity type branches', () {
    test('updates MeasurementEntry with new text and metadata', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final measurementEntry = JournalEntity.measurement(
        meta: Metadata(
          id: 'measurement-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        data: MeasurementData(
          dateFrom: testDate,
          dateTo: testDate,
          value: 500,
          dataTypeId: 'water-type-id',
        ),
        entryText: const EntryText(plainText: 'original text'),
      );

      when(
        () => journalDb.journalEntityById('measurement-id'),
      ).thenAnswer((_) async => measurementEntry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      const newText = EntryText(plainText: 'updated measurement notes');
      final result = await logic.updateJournalEntityText(
        'measurement-id',
        newText,
        DateTime(2024, 3, 15, 10, 35),
      );

      expect(result, isTrue);
      expect(logic.lastUpdateDbEntity, isA<MeasurementEntry>());
      final updated = logic.lastUpdateDbEntity! as MeasurementEntry;
      expect(updated.entryText?.plainText, 'updated measurement notes');
      expect(updated.data.value, 500);
      expect(updated.data.dataTypeId, 'water-type-id');
      expect(logic.updateMetadataCalls, 1);
    });

    test('updates HabitCompletionEntry with new text and metadata', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final habitEntry = JournalEntity.habitCompletion(
        meta: Metadata(
          id: 'habit-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        data: HabitCompletionData(
          dateFrom: testDate,
          dateTo: testDate,
          habitId: 'flossing-habit-id',
        ),
        entryText: const EntryText(plainText: 'original habit text'),
      );

      when(
        () => journalDb.journalEntityById('habit-id'),
      ).thenAnswer((_) async => habitEntry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      const newText = EntryText(plainText: 'updated habit notes');
      final result = await logic.updateJournalEntityText(
        'habit-id',
        newText,
        DateTime(2024, 3, 15, 10, 35),
      );

      expect(result, isTrue);
      expect(logic.lastUpdateDbEntity, isA<HabitCompletionEntry>());
      final updated = logic.lastUpdateDbEntity! as HabitCompletionEntry;
      expect(updated.entryText?.plainText, 'updated habit notes');
      expect(updated.data.habitId, 'flossing-habit-id');
      expect(logic.updateMetadataCalls, 1);
    });
  });

  group('updateTask - orElse path', () {
    test('logs captureException when entity is not a Task', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'not-a-task-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'just a journal entry'),
      );

      when(
        () => journalDb.journalEntityById('not-a-task-id'),
      ).thenAnswer((_) async => journalEntry);

      final taskData = TaskData(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 60,
        ),
        title: 'test task',
        statusHistory: [],
        dateTo: testDate,
        dateFrom: testDate,
      );

      final result = await logic.updateTask(
        journalEntityId: 'not-a-task-id',
        taskData: taskData,
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          'not a task',
          domain: 'persistence_logic',
          subDomain: 'updateTask',
        ),
      ).called(1);
    });
  });

  group('updateTask', () {
    test(
      'updates priority columns before notifying listeners for priority changes',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final callOrder = <String>[];
        Set<String>? notifiedIds;
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p1High,
          ),
        );

        when(
          () => journalDb.journalEntityById('task-id'),
        ).thenAnswer((_) async => task);
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.updateTaskPriorityColumn(
            id: 'task-id',
            priority: 'P0',
            rank: 0,
          ),
        ).thenAnswer((_) async {
          callOrder.add('priority-column');
        });
        when(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        ).thenAnswer((invocation) {
          callOrder.add('notify');
          notifiedIds = invocation.positionalArguments.first as Set<String>;
        });

        final updatedTaskData = task.data.copyWith(
          priority: TaskPriority.p0Urgent,
        );

        await logic.updateTask(
          journalEntityId: 'task-id',
          taskData: updatedTaskData,
        );

        expect(callOrder, equals(['priority-column', 'notify']));
        expect(notifiedIds, contains('task-id'));
      },
    );
  });

  group('updateEvent - orElse path', () {
    test('logs captureException when entity is not an Event', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'not-an-event-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'just a journal entry'),
      );

      when(
        () => journalDb.journalEntityById('not-an-event-id'),
      ).thenAnswer((_) async => journalEntry);

      const eventData = EventData(
        status: EventStatus.tentative,
        title: 'Test Event',
        stars: 3,
      );

      final result = await logic.updateEvent(
        journalEntityId: 'not-an-event-id',
        data: eventData,
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          'not an event',
          domain: 'persistence_logic',
          subDomain: 'updateEvent',
        ),
      ).called(1);
    });
  });
}
