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
  }) async {
    lastUpdateDbEntity = journalEntity;
    if (updateDbEntityHandler != null) {
      return updateDbEntityHandler!(
        journalEntity,
        linkedId: linkedId,
        enqueueSync: enqueueSync,
        overrideComparison: overrideComparison,
      );
    }
    return super.updateDbEntity(
      journalEntity,
      linkedId: linkedId,
      enqueueSync: enqueueSync,
      overrideComparison: overrideComparison,
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
