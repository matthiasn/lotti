import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockLoggingService extends Mock implements LoggingService {}

class MockOutboxService extends Mock implements OutboxService {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockNotificationService extends Mock implements NotificationService {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockTagsService extends Mock implements TagsService {}

class TestPersistenceLogic extends PersistenceLogic {
  TestPersistenceLogic({this.updateDbEntityHandler});

  final Future<bool?> Function(JournalEntity entity,
      {String? linkedId, bool enqueueSync})? updateDbEntityHandler;
  int updateMetadataCalls = 0;
  JournalEntity? lastUpdateDbEntity;

  @override
  Future<void> init() async {
    // Skip location initialization for unit tests.
  }

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
  }) async {
    updateMetadataCalls++;
    return super.updateMetadata(
      metadata,
      dateFrom: dateFrom,
      dateTo: dateTo,
      categoryId: categoryId,
      clearCategoryId: clearCategoryId,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
  }) async {
    lastUpdateDbEntity = journalEntity;
    if (updateDbEntityHandler != null) {
      return updateDbEntityHandler!(
        journalEntity,
        linkedId: linkedId,
        enqueueSync: enqueueSync,
      );
    }
    return super.updateDbEntity(
      journalEntity,
      linkedId: linkedId,
      enqueueSync: enqueueSync,
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
  late MockTagsService tagsService;
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
    final now = DateTime.now();
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

  setUp(() {
    getIt.reset();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    loggingService = MockLoggingService();
    outboxService = MockOutboxService();
    fts5Db = MockFts5Db();
    notificationService = MockNotificationService();
    vectorClockService = MockVectorClockService();
    tagsService = MockTagsService();

    when(
      () => fts5Db.insertText(
        any<JournalEntity>(),
        removePrevious: any<bool>(named: 'removePrevious'),
      ),
    ).thenAnswer((_) async {});
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(() => updateNotifications.notify(any<Set<String>>())).thenReturn(null);
    when(() => outboxService.enqueueMessage(any<SyncMessage>()))
        .thenAnswer((_) async {});
    when(() => vectorClockService.getNextVectorClock())
        .thenAnswer((_) async => const VectorClock({'host': 1}));
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any<VectorClock?>(named: 'previous'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host': 1}));
    when(() => tagsService.getFilteredStoryTagIds(any<List<String>?>()))
        .thenReturn(<String>[]);

    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LoggingService>(loggingService)
      ..registerSingleton<OutboxService>(outboxService)
      ..registerSingleton<Fts5Db>(fts5Db)
      ..registerSingleton<NotificationService>(notificationService)
      ..registerSingleton<VectorClockService>(vectorClockService)
      ..registerSingleton<TagsService>(tagsService);

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

  test('createDbEntity skips addTagged when update skipped', () async {
    stubUpdateResult(
      JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );
    when(() => journalDb.addTagged(any<JournalEntity>()))
        .thenAnswer((_) async {});

    final entity = buildEntry(clock: const VectorClock({'host': 5}));
    final saved = await logic.createDbEntity(
      entity,
      shouldAddGeolocation: false,
    );

    expect(saved, isFalse);
    verifyNever(() => journalDb.addTagged(any<JournalEntity>()));
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  group('updateJournalEntity', () {
    test('adds tags only when update applies and reuses metadata', () async {
      final taggedCaptures = <JournalEntity>[];
      when(() => journalDb.addTagged(captureAny()))
          .thenAnswer((invocation) async {
        taggedCaptures
            .add(invocation.positionalArguments.first as JournalEntity);
      });

      logic = TestPersistenceLogic(
        updateDbEntityHandler: (
          entity, {
          linkedId,
          enqueueSync = true,
        }) async =>
            true,
      );

      final baseEntry = buildEntry();
      final result = await logic.updateJournalEntity(baseEntry, baseEntry.meta);

      expect(result, isTrue);
      expect(taggedCaptures, hasLength(1));
      final updatedEntity = taggedCaptures.first;
      expect(identical(updatedEntity.meta, logic.lastUpdateDbEntity?.meta),
          isTrue);
      expect(logic.updateMetadataCalls, 1);

      clearInteractions(journalDb);
      taggedCaptures.clear();

      logic = TestPersistenceLogic(
        updateDbEntityHandler: (
          entity, {
          linkedId,
          enqueueSync = true,
        }) async =>
            false,
      );

      final skipped =
          await logic.updateJournalEntity(baseEntry, baseEntry.meta);

      expect(skipped, isFalse);
      verifyNever(() => journalDb.addTagged(any<JournalEntity>()));
    });
  });
}
