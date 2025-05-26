import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockJournalDb extends Mock implements JournalDb {}

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

class SyncMessageFake extends Fake implements SyncMessage {}

class ExceptionFake extends Fake implements Exception {}

// Fake classes for EntityDefinition parts
class FakeMeasurableDataType extends Fake implements MeasurableDataType {
  FakeMeasurableDataType({required this.id, this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {
  FakeCategoryDefinition({required this.id, this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {
  FakeDashboardDefinition({required this.id, this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeHabitDefinition extends Fake implements HabitDefinition {
  FakeHabitDefinition({required this.id, this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

void main() {
  late MockJournalDb mockJournalDb;
  late MockOutboxService mockOutboxService;
  late MockLoggingService mockLoggingService;
  late SyncMaintenanceRepository syncMaintenanceRepository;

  setUpAll(() {
    registerFallbackValue(SyncMessageFake());
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(ExceptionFake());
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockOutboxService = MockOutboxService();
    mockLoggingService = MockLoggingService();

    // Clear previous registrations if any, to avoid conflicts during re-runs.
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<LoggingService>(mockLoggingService);

    syncMaintenanceRepository = SyncMaintenanceRepository();
  });

  tearDown(getIt.reset);

  group('SyncMaintenanceRepository - Original Tests', () {
    test('syncTags enqueues tags for sync', () async {
      final testTag = TagEntity.genericTag(
        id: '1',
        tag: 'test',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        inactive: false,
      );
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value([testTag]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncTags();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          tagEntity: (syncTag) => syncTag.tagEntity.id,
        ),
        testTag.id,
      );
      expect(
        capturedMessage.mapOrNull(tagEntity: (syncTag) => syncTag.status),
        SyncEntryStatus.update,
      );
    });

    test('syncTags skips deleted tags but syncs inactive tags', () async {
      final deletedTag = TagEntity.genericTag(
        id: '2',
        tag: 'deleted',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        deletedAt: DateTime.now(),
        inactive: false,
      );
      final inactiveTag = TagEntity.genericTag(
        id: '3',
        tag: 'inactive',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        inactive: true,
      );
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value([deletedTag, inactiveTag]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncTags();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;

      // Should only capture the inactive tag
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          tagEntity: (syncTag) => syncTag.tagEntity.id,
        ),
        inactiveTag.id,
      );
      expect(
        capturedMessage.mapOrNull(tagEntity: (syncTag) => syncTag.status),
        SyncEntryStatus.update,
      );

      // Verify that the deleted tag was never enqueued by checking all captured messages.
      // This is a more robust way than verifyNever if other messages could have been sent.
      for (final msg in captured) {
        final id = (msg as SyncMessage)
            .mapOrNull(tagEntity: (syncTag) => syncTag.tagEntity.id);
        expect(id, isNot(deletedTag.id));
      }
    });

    test('syncMeasurables enqueues measurables for sync', () async {
      final testMeasurable = FakeMeasurableDataType(id: '1');
      when(() => mockJournalDb.watchMeasurableDataTypes())
          .thenAnswer((_) => Stream.value([testMeasurable]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncMeasurables();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as MeasurableDataType).id,
        ),
        testMeasurable.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );
    });

    test('syncMeasurables skips deleted measurables', () async {
      final deletedMeasurable =
          FakeMeasurableDataType(id: '2', deletedAt: DateTime.now());
      final activeMeasurable = FakeMeasurableDataType(id: '3');

      when(() => mockJournalDb.watchMeasurableDataTypes()).thenAnswer(
        (_) => Stream.value([deletedMeasurable, activeMeasurable]),
      );
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncMeasurables();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as MeasurableDataType).id,
        ),
        activeMeasurable.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );

      for (final msg in captured) {
        final id = (msg as SyncMessage).mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as MeasurableDataType).id,
        );
        expect(id, isNot(deletedMeasurable.id));
      }
    });

    test('syncCategories enqueues categories for sync', () async {
      final testCategory = FakeCategoryDefinition(id: '1');
      when(() => mockJournalDb.watchCategories())
          .thenAnswer((_) => Stream.value([testCategory]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncCategories();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as CategoryDefinition).id,
        ),
        testCategory.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );
    });

    test('syncCategories skips deleted categories', () async {
      final deletedCategory =
          FakeCategoryDefinition(id: '2', deletedAt: DateTime.now());
      final activeCategory = FakeCategoryDefinition(id: '3');

      when(() => mockJournalDb.watchCategories())
          .thenAnswer((_) => Stream.value([deletedCategory, activeCategory]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncCategories();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as CategoryDefinition).id,
        ),
        activeCategory.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );

      for (final msg in captured) {
        final id = (msg as SyncMessage).mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as CategoryDefinition).id,
        );
        expect(id, isNot(deletedCategory.id));
      }
    });

    test('syncDashboards enqueues dashboards for sync', () async {
      final testDashboard = FakeDashboardDefinition(id: '1');
      when(() => mockJournalDb.watchDashboards())
          .thenAnswer((_) => Stream.value([testDashboard]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncDashboards();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as DashboardDefinition).id,
        ),
        testDashboard.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );
    });

    test('syncDashboards skips deleted dashboards', () async {
      final deletedDashboard =
          FakeDashboardDefinition(id: '2', deletedAt: DateTime.now());
      final activeDashboard = FakeDashboardDefinition(id: '3');

      when(() => mockJournalDb.watchDashboards())
          .thenAnswer((_) => Stream.value([deletedDashboard, activeDashboard]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncDashboards();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as DashboardDefinition).id,
        ),
        activeDashboard.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );

      for (final msg in captured) {
        final id = (msg as SyncMessage).mapOrNull(
          entityDefinition: (s) =>
              (s.entityDefinition as DashboardDefinition).id,
        );
        expect(id, isNot(deletedDashboard.id));
      }
    });

    test('syncHabits enqueues habits for sync', () async {
      final testHabit = FakeHabitDefinition(id: '1');
      when(() => mockJournalDb.watchHabitDefinitions())
          .thenAnswer((_) => Stream.value([testHabit]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncHabits();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) => (s.entityDefinition as HabitDefinition).id,
        ),
        testHabit.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );
    });

    test('syncHabits skips deleted habits', () async {
      final deletedHabit =
          FakeHabitDefinition(id: '2', deletedAt: DateTime.now());
      final activeHabit = FakeHabitDefinition(id: '3');

      when(() => mockJournalDb.watchHabitDefinitions())
          .thenAnswer((_) => Stream.value([deletedHabit, activeHabit]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncHabits();

      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) => (s.entityDefinition as HabitDefinition).id,
        ),
        activeHabit.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );

      for (final msg in captured) {
        final id = (msg as SyncMessage).mapOrNull(
          entityDefinition: (s) => (s.entityDefinition as HabitDefinition).id,
        );
        expect(id, isNot(deletedHabit.id));
      }
    });
  });

  group('SyncMaintenanceRepository - Logging Tests', () {
    final testException = Exception('Test DB Error');

    group('syncTags', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.watchTags())
            .thenAnswer((_) => Stream.fromFuture(Future.error(testException)));

        await expectLater(
          () => syncMaintenanceRepository.syncTags(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'SYNC_SERVICE',
            subDomain: 'syncTags',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('syncMeasurables', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.watchMeasurableDataTypes())
            .thenAnswer((_) => Stream.fromFuture(Future.error(testException)));

        await expectLater(
          () => syncMaintenanceRepository.syncMeasurables(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'SYNC_SERVICE',
            subDomain: 'syncMeasurables',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('syncCategories', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.watchCategories())
            .thenAnswer((_) => Stream.fromFuture(Future.error(testException)));

        await expectLater(
          () => syncMaintenanceRepository.syncCategories(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'SYNC_SERVICE',
            subDomain: 'syncCategories',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('syncDashboards', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.watchDashboards())
            .thenAnswer((_) => Stream.fromFuture(Future.error(testException)));

        await expectLater(
          () => syncMaintenanceRepository.syncDashboards(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'SYNC_SERVICE',
            subDomain: 'syncDashboards',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('syncHabits', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.watchHabitDefinitions())
            .thenAnswer((_) => Stream.fromFuture(Future.error(testException)));

        await expectLater(
          () => syncMaintenanceRepository.syncHabits(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'SYNC_SERVICE',
            subDomain: 'syncHabits',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });

  group('syncEntities', () {
    test('reports progress correctly for multiple entities', () async {
      // Create test entities
      final testTags = [
        TagEntity.genericTag(
          id: '1',
          tag: 'Tag 1',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '2',
          tag: 'Tag 2',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '3',
          tag: 'Tag 3',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '4',
          tag: 'Tag 4',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '5',
          tag: 'Tag 5',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
      ];

      // Track progress updates
      final progressUpdates = <double>[];

      // Mock the fetch function
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value(testTags));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      // Test the sync
      await syncMaintenanceRepository.syncTags(
        onProgress: progressUpdates.add,
      );

      // Verify progress updates
      expect(progressUpdates.length, 5); // One update per entity
      expect(progressUpdates[0], 0.2); // 1/5 = 0.2
      expect(progressUpdates[1], 0.4); // 2/5 = 0.4
      expect(progressUpdates[2], 0.6); // 3/5 = 0.6
      expect(progressUpdates[3], 0.8); // 4/5 = 0.8
      expect(progressUpdates[4], 1.0); // 5/5 = 1.0
    });

    test(
        'handles deleted entities correctly (progress for all, sync only non-deleted)',
        () async {
      // Create test entities with some deleted ones
      final testTags = [
        TagEntity.genericTag(
          id: '1',
          tag: 'Tag 1',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '2',
          tag: 'Tag 2',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          deletedAt: DateTime.now(),
          inactive: false,
        ),
        TagEntity.genericTag(
          id: '3',
          tag: 'Tag 3',
          private: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          inactive: false,
        ),
      ];

      // Track progress updates
      final progressUpdates = <double>[];

      // Mock the fetch function
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value(testTags));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      // Test the sync
      await syncMaintenanceRepository.syncTags(
        onProgress: progressUpdates.add,
      );

      // Progress should be reported for all entities
      expect(progressUpdates.length, 3); // 3 entities, including deleted
      expect(progressUpdates[0], closeTo(1 / 3, 0.001));
      expect(progressUpdates[1], closeTo(2 / 3, 0.001));
      expect(progressUpdates[2], closeTo(1.0, 0.001));

      // Only non-deleted entities should be synced
      verify(() => mockOutboxService.enqueueMessage(any())).called(2);
    });

    test('skips syncing deleted entities', () async {
      final deletedTag = TagEntity.genericTag(
        id: '2',
        tag: 'Tag 2',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        deletedAt: DateTime.now(),
        inactive: false,
      );
      final activeTag = TagEntity.genericTag(
        id: '1',
        tag: 'Tag 1',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        inactive: false,
      );
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value([deletedTag, activeTag]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncMaintenanceRepository.syncTags();
      // Only the active tag should be synced
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('handles empty entity list', () async {
      // Create empty test list
      final testTags = <TagEntity>[];

      // Track progress updates
      final progressUpdates = <double>[];

      // Mock the fetch function
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value(testTags));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      // Test the sync
      await syncMaintenanceRepository.syncTags(
        onProgress: progressUpdates.add,
      );

      // Verify no progress updates for empty list
      expect(progressUpdates.isEmpty, true);
    });

    test('handles errors correctly', () async {
      // Mock the fetch function to throw an error
      when(() => mockJournalDb.watchTags()).thenThrow(Exception('Test error'));

      // Test the sync
      expect(
        () => syncMaintenanceRepository.syncTags(),
        throwsException,
      );

      // Verify error was logged
      verify(
        () => mockLoggingService.captureException(
          any<Exception>(),
          domain: 'SYNC_SERVICE',
          subDomain: 'syncTags',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
