import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
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
    final now = DateTime(2026, 3, 21, 9);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        vectorClock: clock ?? const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'text'),
    );
  }

  Task buildTask({
    required String id,
    required TaskStatus status,
  }) {
    final now = DateTime(2026, 3, 21, 9);
    return JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            status: status,
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'Task $id',
          ),
        )
        as Task;
  }

  ProjectEntry buildProject({required String id}) {
    final now = DateTime(2026, 3, 21, 9);
    return JournalEntity.project(
          meta: Metadata(
            id: id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            categoryId: 'cat-1',
          ),
          data: ProjectData(
            title: 'Project $id',
            status: ProjectStatus.active(
              id: 'project-status-$id',
              createdAt: now,
              utcOffset: 60,
            ),
            dateFrom: now,
            dateTo: now,
          ),
        )
        as ProjectEntry;
  }

  DayPlanEntry buildDayPlan({
    required DayPlanStatus status,
    List<PlannedBlock> plannedBlocks = const [],
    List<PinnedTaskRef> pinnedTasks = const [],
  }) {
    final now = DateTime(2026, 3, 21, 9);
    return JournalEntity.dayPlan(
          meta: Metadata(
            id: 'dayplan-2026-03-21',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: DayPlanData(
            planDate: now,
            status: status,
            plannedBlocks: plannedBlocks,
            pinnedTasks: pinnedTasks,
          ),
        )
        as DayPlanEntry;
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
      () => journalDb.journalEntityById(any<String>()),
    ).thenAnswer((_) async => null);
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

  test(
    'updateDbEntity emits project-agent task-status token for linked task transitions',
    () async {
      final statusTime = DateTime(2026, 3, 21, 9);
      final previousTask = buildTask(
        id: 'task-1',
        status: TaskStatus.open(
          id: 'status-open',
          createdAt: statusTime,
          utcOffset: 60,
        ),
      );
      final updatedTask = buildTask(
        id: 'task-1',
        status: TaskStatus.done(
          id: 'status-done',
          createdAt: statusTime,
          utcOffset: 60,
        ),
      );

      when(
        () => journalDb.journalEntityById('task-1'),
      ).thenAnswer((_) async => previousTask);
      when(
        () => journalDb.getProjectForTask('task-1'),
      ).thenAnswer((_) async => buildProject(id: 'project-1'));
      stubUpdateResult(JournalUpdateResult.applied());

      await logic.updateDbEntity(updatedTask);

      final tokens =
          verify(
                () => updateNotifications.notify(captureAny<Set<String>>()),
              ).captured.single
              as Set<String>;
      expect(tokens, contains(projectAgentTaskStatusChangedToken('project-1')));
    },
  );

  test(
    'updateDbEntity emits day-plan agreement tokens only when plan becomes agreed',
    () async {
      final now = DateTime(2026, 3, 21, 9);
      final previousPlan = buildDayPlan(
        status: const DayPlanStatus.draft(),
      );
      final updatedPlan = buildDayPlan(
        status: DayPlanStatus.agreed(agreedAt: now),
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: now,
            endTime: DateTime(2026, 3, 21, 10),
          ),
        ],
        pinnedTasks: const [
          PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-2'),
        ],
      );

      when(
        () => journalDb.journalEntityById('dayplan-2026-03-21'),
      ).thenAnswer((_) async => previousPlan);
      stubUpdateResult(JournalUpdateResult.applied());

      await logic.updateDbEntity(updatedPlan);

      final tokens =
          verify(
                () => updateNotifications.notify(captureAny<Set<String>>()),
              ).captured.single
              as Set<String>;
      expect(tokens, contains(projectAgentDayPlanAgreedToken('cat-1')));
      expect(tokens, contains(projectAgentDayPlanAgreedToken('cat-2')));
    },
  );

  test(
    'updateDbEntity emits direct project-agent token for project updates',
    () async {
      final project = buildProject(id: 'project-1');

      when(
        () => journalDb.journalEntityById('project-1'),
      ).thenAnswer((_) async => project);
      stubUpdateResult(JournalUpdateResult.applied());

      await logic.updateDbEntity(project);

      final tokens =
          verify(
                () => updateNotifications.notify(captureAny<Set<String>>()),
              ).captured.single
              as Set<String>;
      expect(tokens, contains(projectAgentProjectChangedToken('project-1')));
    },
  );
}
