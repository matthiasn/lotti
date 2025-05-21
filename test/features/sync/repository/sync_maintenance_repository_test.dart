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
  late SyncMaintenanceRepository syncService;
  late MockJournalDb mockJournalDb;
  late MockOutboxService mockOutboxService;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(SyncMessageFake());
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockOutboxService = MockOutboxService();
    mockLoggingService = MockLoggingService();
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<LoggingService>(mockLoggingService);
    syncService = SyncMaintenanceRepository();
  });

  tearDown(getIt.reset);

  group('SyncService Tests', () {
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
          .thenAnswer((_) => Future.value());

      await syncService.syncTags();

      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('syncTags skips deleted tags', () async {
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
          .thenAnswer((_) => Future.value());

      await syncService.syncTags();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;

      // Expect that exactly one message was captured
      expect(capturedMessages.length, 1);

      // Expect that the captured message is the inactiveTag
      final inactiveTagMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              tagEntity: (syncTag) => syncTag.tagEntity.id == inactiveTag.id,
            ) ??
            false,
        orElse: () =>
            null, // Add orElse to handle not found case, though expect will fail if it's null
      );
      expect(
        inactiveTagMessage,
        isNotNull,
        reason: 'Message for inactiveTag was not captured',
      );

      // Expect that no message for the deletedTag was captured
      final deletedTagMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              tagEntity: (syncTag) => syncTag.tagEntity.id == deletedTag.id,
            ) ??
            false,
        orElse: () => null, // Add orElse to return null if not found
      );
      expect(
        deletedTagMessage,
        isNull,
        reason: 'Message for deletedTag was captured but should not have been',
      );
    });
  });

  group('SyncMeasurables Tests', () {
    test('syncMeasurables enqueues measurables for sync', () async {
      final testMeasurable = FakeMeasurableDataType(id: '1');
      // No need to mock id and deletedAt as they are set in constructor
      when(() => mockJournalDb.watchMeasurableDataTypes())
          .thenAnswer((_) => Stream.value([testMeasurable]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncMeasurables();

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncMessage>().having(
              (m) =>
                  m.mapOrNull(
                    entityDefinition: (s) =>
                        (s.entityDefinition as MeasurableDataType).id ==
                        testMeasurable.id,
                  ) ??
                  false,
              'id',
              true,
            ),
          ),
        ),
      ).called(1);
    });

    test('syncMeasurables skips deleted measurables', () async {
      final deletedMeasurable =
          FakeMeasurableDataType(id: '2', deletedAt: DateTime.now());
      final activeMeasurable = FakeMeasurableDataType(id: '3');

      when(() => mockJournalDb.watchMeasurableDataTypes()).thenAnswer(
        (_) => Stream.value([deletedMeasurable, activeMeasurable]),
      );
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncMeasurables();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(capturedMessages.length, 1);

      final activeMeasurableMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as MeasurableDataType).id ==
                  activeMeasurable.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(activeMeasurableMessage, isNotNull);

      final deletedMeasurableMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as MeasurableDataType).id ==
                  deletedMeasurable.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(deletedMeasurableMessage, isNull);
    });
  });

  group('SyncCategories Tests', () {
    test('syncCategories enqueues categories for sync', () async {
      final testCategory = FakeCategoryDefinition(id: '1');
      when(() => mockJournalDb.watchCategories())
          .thenAnswer((_) => Stream.value([testCategory]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncCategories();

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncMessage>().having(
              (m) =>
                  m.mapOrNull(
                    entityDefinition: (s) =>
                        (s.entityDefinition as CategoryDefinition).id ==
                        testCategory.id,
                  ) ??
                  false,
              'id',
              true,
            ),
          ),
        ),
      ).called(1);
    });

    test('syncCategories skips deleted categories', () async {
      final deletedCategory =
          FakeCategoryDefinition(id: '2', deletedAt: DateTime.now());
      final activeCategory = FakeCategoryDefinition(id: '3');

      when(() => mockJournalDb.watchCategories())
          .thenAnswer((_) => Stream.value([deletedCategory, activeCategory]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncCategories();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(capturedMessages.length, 1);

      final activeCategoryMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as CategoryDefinition).id ==
                  activeCategory.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(activeCategoryMessage, isNotNull);

      final deletedCategoryMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as CategoryDefinition).id ==
                  deletedCategory.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(deletedCategoryMessage, isNull);
    });
  });

  group('SyncDashboards Tests', () {
    test('syncDashboards enqueues dashboards for sync', () async {
      final testDashboard = FakeDashboardDefinition(id: '1');
      when(() => mockJournalDb.watchDashboards())
          .thenAnswer((_) => Stream.value([testDashboard]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncDashboards();

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncMessage>().having(
              (m) =>
                  m.mapOrNull(
                    entityDefinition: (s) =>
                        (s.entityDefinition as DashboardDefinition).id ==
                        testDashboard.id,
                  ) ??
                  false,
              'id',
              true,
            ),
          ),
        ),
      ).called(1);
    });

    test('syncDashboards skips deleted dashboards', () async {
      final deletedDashboard =
          FakeDashboardDefinition(id: '2', deletedAt: DateTime.now());
      final activeDashboard = FakeDashboardDefinition(id: '3');

      when(() => mockJournalDb.watchDashboards())
          .thenAnswer((_) => Stream.value([deletedDashboard, activeDashboard]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncDashboards();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(capturedMessages.length, 1);

      final activeDashboardMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as DashboardDefinition).id ==
                  activeDashboard.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(activeDashboardMessage, isNotNull);

      final deletedDashboardMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as DashboardDefinition).id ==
                  deletedDashboard.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(deletedDashboardMessage, isNull);
    });
  });

  group('SyncHabits Tests', () {
    test('syncHabits enqueues habits for sync', () async {
      final testHabit = FakeHabitDefinition(id: '1');
      when(() => mockJournalDb.watchHabitDefinitions())
          .thenAnswer((_) => Stream.value([testHabit]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncHabits();

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncMessage>().having(
              (m) =>
                  m.mapOrNull(
                    entityDefinition: (s) =>
                        (s.entityDefinition as HabitDefinition).id ==
                        testHabit.id,
                  ) ??
                  false,
              'id',
              true,
            ),
          ),
        ),
      ).called(1);
    });

    test('syncHabits skips deleted habits', () async {
      final deletedHabit =
          FakeHabitDefinition(id: '2', deletedAt: DateTime.now());
      final activeHabit = FakeHabitDefinition(id: '3');

      when(() => mockJournalDb.watchHabitDefinitions())
          .thenAnswer((_) => Stream.value([deletedHabit, activeHabit]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncHabits();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;
      expect(capturedMessages.length, 1);

      final activeHabitMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as HabitDefinition).id == activeHabit.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(activeHabitMessage, isNotNull);

      final deletedHabitMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              entityDefinition: (s) =>
                  (s.entityDefinition as HabitDefinition).id == deletedHabit.id,
            ) ??
            false,
        orElse: () => null,
      );
      expect(deletedHabitMessage, isNull);
    });
  });
}
