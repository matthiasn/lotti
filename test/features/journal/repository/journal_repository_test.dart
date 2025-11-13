// ignore_for_file: inference_failure_on_function_invocation

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
// Get the getIt instance to inject our mocks
import 'package:lotti/get_it.dart' show getIt;
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockTaskSummaryRefreshService extends Mock
    implements TaskSummaryRefreshService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockNotificationService extends Mock implements NotificationService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockOutboxService extends Mock implements OutboxService {}

class MockRef extends Mock implements Ref {}

class MockTimeService extends Mock implements TimeService {}

class MockSelectableLinkedDbEntry extends Mock
    implements drift.Selectable<LinkedDbEntry> {}

class MockSelectableString extends Mock implements drift.Selectable<String> {}

class MockSelectableJournalDbEntity extends Mock
    implements drift.Selectable<JournalDbEntity> {}

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockNotificationService mockNotificationService;
  late MockLoggingService mockLoggingService;
  late MockVectorClockService mockVectorClockService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockOutboxService mockOutboxService;
  late MockTimeService mockTimeService;
  late JournalRepository repository;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockNotificationService = MockNotificationService();
    mockLoggingService = MockLoggingService();
    mockVectorClockService = MockVectorClockService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockOutboxService = MockOutboxService();
    mockTimeService = MockTimeService();

    // Register our mock services
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<VectorClockService>(mockVectorClockService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<TimeService>(mockTimeService);

    // Create repository instance with mock ref
    final mockRef = MockRef();
    repository = JournalRepository(mockRef);

    // Register fallback values for any complex types
    registerFallbackValue(
      Metadata(
        id: 'test-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        dateFrom: DateTime(2023),
        dateTo: DateTime(2023),
        starred: false,
        private: false,
        flag: EntryFlag.none,
      ),
    );
    registerFallbackValue(
      JournalEntity.journalEntry(
        entryText: const EntryText(
          plainText: 'Test content',
          markdown: 'test',
        ),
        meta: Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
          private: false,
          flag: EntryFlag.none,
        ),
      ),
    );
    registerFallbackValue(
      SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          updatedAt: DateTime(2023),
          createdAt: DateTime(2023),
          vectorClock: null,
        ),
        status: SyncEntryStatus.update,
      ),
    );
    registerFallbackValue(
      EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        updatedAt: DateTime(2023),
        createdAt: DateTime(2023),
        vectorClock: null,
      ),
    );
  });

  tearDown(getIt.reset);

  group('JournalRepository', () {
    group('updateCategoryId', () {
      test('returns true when successfully updating category ID', () async {
        // Arrange
        const journalEntityId = 'test-id';
        const categoryId = 'category-id';

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          categoryId: categoryId,
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call to return our test entity
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
      });

      test('returns false when journal entity not found', () async {
        // Arrange
        const journalEntityId = 'non-existent-id';
        const categoryId = 'category-id';

        // Mock the journalEntityById call to return null
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isFalse);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verifyNever(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            categoryId: any(named: 'categoryId'),
          ),
        );
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('clears category ID when passed null', () async {
        // Arrange
        const journalEntityId = 'test-id';
        const String? categoryId = null;

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
            categoryId: 'existing-category',
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          categoryId: null,
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call to return our test entity
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call with clearCategoryId: true
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            clearCategoryId: true,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            clearCategoryId: true,
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
      });

      test('handles exceptions gracefully', () async {
        // Arrange
        const journalEntityId = 'test-id';
        const categoryId = 'category-id';

        // Mock the journalEntityById call to throw an exception
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenThrow(Exception('Test exception'));

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(
          result,
          isTrue,
        ); // The method catches the exception and returns true
        verify(
          () => mockLoggingService.captureException(
            any(),
            domain: 'JournalRepository',
            subDomain: 'updateCategoryId',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('deleteJournalEntity', () {
      test('marks the entity as deleted and returns true on success', () async {
        // Arrange
        const journalEntityId = 'test-id';

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(() => mockNotificationService.updateBadge())
            .thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);
      });

      test('returns false when journal entity not found', () async {
        // Arrange
        const journalEntityId = 'non-existent-id';

        // Mock the journalEntityById call to return null
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isFalse);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verifyNever(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        );
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
        verifyNever(() => mockNotificationService.updateBadge());
      });

      test('stops timer when deleting an active timer entry', () async {
        // Arrange
        const journalEntityId = 'active-timer-id';

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Timer entry',
            markdown: 'timer',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(() => mockNotificationService.updateBadge())
            .thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return the current timer entry
        when(() => mockTimeService.getCurrent()).thenReturn(testEntity);

        // Mock TimeService.stop
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was stopped
        verify(() => mockTimeService.getCurrent()).called(1);
        verify(() => mockTimeService.stop()).called(1);
      });

      test('does not stop timer when deleting a non-active entry', () async {
        // Arrange
        const journalEntityId = 'non-active-timer-id';
        const activeTimerId = 'different-active-timer-id';

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Non-active entry',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final activeTimer = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Active timer',
            markdown: 'timer',
          ),
          meta: Metadata(
            id: activeTimerId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(() => mockNotificationService.updateBadge())
            .thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return a DIFFERENT active timer
        when(() => mockTimeService.getCurrent()).thenReturn(activeTimer);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was NOT stopped (different ID)
        verify(() => mockTimeService.getCurrent()).called(1);
        verifyNever(() => mockTimeService.stop());
      });

      test('handles null timer when deleting entry', () async {
        // Arrange
        const journalEntityId = 'test-id';

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(() => mockNotificationService.updateBadge())
            .thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return null (no active timer)
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was NOT stopped (no active timer)
        verify(() => mockTimeService.getCurrent()).called(1);
        verifyNever(() => mockTimeService.stop());
      });
    });

    group('updateJournalEntityDate', () {
      test('updates date and returns true on success', () async {
        // Arrange
        const journalEntityId = 'test-id';
        final dateFrom = DateTime(2023);
        final dateTo = DateTime(2023, 1, 2);

        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2022),
            dateTo: DateTime(2022),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        final updatedMeta = testEntity.meta.copyWith(
          dateFrom: dateFrom,
          dateTo: dateTo,
          updatedAt: DateTime.now(),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the TimeService updateCurrent call
        when(() => mockTimeService.updateCurrent(any())).thenReturn(null);

        // Act
        final result = await repository.updateJournalEntityDate(
          journalEntityId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockTimeService.updateCurrent(any())).called(1);
      });

      test('returns false when journal entity not found', () async {
        // Arrange
        const journalEntityId = 'non-existent-id';
        final dateFrom = DateTime(2023);
        final dateTo = DateTime(2023, 1, 2);

        // Mock the journalEntityById call to return null
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.updateJournalEntityDate(
          journalEntityId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Assert
        expect(result, isFalse);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verifyNever(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        );
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('handles exceptions gracefully', () async {
        // Arrange
        const journalEntityId = 'test-id';
        final dateFrom = DateTime(2023);
        final dateTo = DateTime(2023, 1, 2);

        // Mock the journalEntityById call to throw an exception
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenThrow(Exception('Test exception'));

        // Act
        final result = await repository.updateJournalEntityDate(
          journalEntityId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Assert
        expect(result, isTrue);

        verify(
          () => mockLoggingService.captureException(
            any(),
            domain: 'JournalRepository',
            subDomain: 'updateJournalEntityDate',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('updateJournalEntity', () {
      test('delegates to PersistenceLogic and returns the result', () async {
        // Arrange
        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: 'test-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        // Mock the updateJournalEntity call
        when(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.updateJournalEntity(testEntity);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).called(1);
      });

      test('handles exceptions and returns false', () async {
        // Arrange
        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: 'test-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        // Mock the updateJournalEntity call to throw an exception
        when(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await repository.updateJournalEntity(testEntity);

        // Assert
        expect(result, isFalse);
        verify(
          () => mockLoggingService.captureException(
            any(),
            domain: 'JournalRepository',
            subDomain: 'updateJournalEntity',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('updateLink', () {
      test('updates the link and enqueues a sync message', () async {
        // Arrange
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        // Mock VectorClockService
        when(() => mockVectorClockService.getNextVectorClock())
            .thenAnswer((_) async => const VectorClock({'node1': 1}));

        // Mock JournalDb
        when(() => mockJournalDb.upsertEntryLink(any()))
            .thenAnswer((_) async => 1);

        // Mock UpdateNotifications
        when(() => mockUpdateNotifications.notify(any()))
            .thenAnswer((_) async {});

        // Mock OutboxService
        when(() => mockOutboxService.enqueueMessage(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.updateLink(testLink);

        // Assert
        expect(result, isTrue);
        verify(() => mockVectorClockService.getNextVectorClock()).called(1);
        verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
        verify(
          () =>
              mockUpdateNotifications.notify({testLink.fromId, testLink.toId}),
        ).called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });
    });

    group('removeLink', () {
      test('successfully removes a link and returns the result', () async {
        // Arrange
        const fromId = 'from-id';
        const toId = 'to-id';

        // Mock JournalDb
        when(() => mockJournalDb.deleteLink(fromId, toId))
            .thenAnswer((_) async => 1);

        // Mock UpdateNotifications
        when(() => mockUpdateNotifications.notify(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.removeLink(
          fromId: fromId,
          toId: toId,
        );

        // Assert
        expect(result, equals(1));
        verify(() => mockJournalDb.deleteLink(fromId, toId)).called(1);
        verify(() => mockUpdateNotifications.notify({fromId, toId})).called(1);
      });
    });

    group('getLinkedToEntities', () {
      test('returns entities linked to the specified entity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';
        final mockSelectableJournalDbEntities = MockSelectableJournalDbEntity();

        final testEntities = [
          JournalEntity.journalEntry(
            entryText: const EntryText(
              plainText: 'Entry 1',
              markdown: 'Entry 1',
            ),
            meta: Metadata(
              id: 'entry-1',
              createdAt: DateTime(2023),
              updatedAt: DateTime(2023),
              dateFrom: DateTime(2023),
              dateTo: DateTime(2023),
              starred: false,
              private: false,
              flag: EntryFlag.none,
            ),
          ),
          JournalEntity.journalEntry(
            entryText: const EntryText(
              plainText: 'Entry 2',
              markdown: 'Entry 2',
            ),
            meta: Metadata(
              id: 'entry-2',
              createdAt: DateTime(2023),
              updatedAt: DateTime(2023),
              dateFrom: DateTime(2023),
              dateTo: DateTime(2023),
              starred: false,
              private: false,
              flag: EntryFlag.none,
            ),
          ),
        ];

        // Mock JournalDb
        when(() => mockJournalDb.linkedToJournalEntities(linkedTo))
            .thenReturn(mockSelectableJournalDbEntities);

        // Skip the actual Future conversion and just mock getLinkedEntities directly
        when(() => mockJournalDb.getLinkedEntities(linkedTo))
            .thenAnswer((_) async => testEntities);

        // Act
        final result = await repository.getLinkedEntities(linkedTo: linkedTo);

        // Assert
        expect(result, equals(testEntities));
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });
    });

    group('getLinkedEntities', () {
      test('returns all linked entities for the specified entity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';

        final testEntities = [
          JournalEntity.journalEntry(
            entryText: const EntryText(
              plainText: 'Entry 1',
              markdown: 'Entry 1',
            ),
            meta: Metadata(
              id: 'entry-1',
              createdAt: DateTime(2023),
              updatedAt: DateTime(2023),
              dateFrom: DateTime(2023),
              dateTo: DateTime(2023),
            ),
          ),
          JournalEntity.journalEntry(
            entryText: const EntryText(
              plainText: 'Entry 2',
              markdown: 'Entry 2',
            ),
            meta: Metadata(
              id: 'entry-2',
              createdAt: DateTime(2023),
              updatedAt: DateTime(2023),
              dateFrom: DateTime(2023),
              dateTo: DateTime(2023),
            ),
          ),
        ];

        // Mock JournalDb
        when(() => mockJournalDb.getLinkedEntities(linkedTo))
            .thenAnswer((_) async => testEntities);

        // Act
        final result = await repository.getLinkedEntities(linkedTo: linkedTo);

        // Assert
        expect(result, equals(testEntities));
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });
    });

    group('getJournalEntityById', () {
      test('returns the journal entity when found', () async {
        // Arrange
        const entityId = 'test-entity-id';
        final testEntity = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Test content',
            markdown: 'test',
          ),
          meta: Metadata(
            id: entityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        // Mock the journalEntityById call
        when(() => mockJournalDb.journalEntityById(entityId))
            .thenAnswer((_) async => testEntity);

        // Act
        final result = await repository.getJournalEntityById(entityId);

        // Assert
        expect(result, equals(testEntity));
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });

      test('returns null when entity not found', () async {
        // Arrange
        const entityId = 'non-existent-id';

        // Mock the journalEntityById call to return null
        when(() => mockJournalDb.journalEntityById(entityId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getJournalEntityById(entityId);

        // Assert
        expect(result, isNull);
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });
    });

    group('getLinksFromId', () {
      test('returns links from a specific ID with sorted order', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink1 = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final entryLink2 = EntryLink.basic(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final mockDbEntry1 = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink1),
        );

        final mockDbEntry2 = LinkedDbEntry(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink2),
        );

        final mockEntries = [mockDbEntry1, mockDbEntry2];
        final mockLinksQuery = MockSelectableLinkedDbEntry();
        final mockIdsQuery = MockSelectableString();

        // Mock the linksFromId query
        when(() => mockJournalDb.linksFromId(fromId, [false]))
            .thenReturn(mockLinksQuery);
        when(mockLinksQuery.get).thenAnswer((_) async => mockEntries);

        // Mock the journalEntityIdsByDateFromDesc query
        when(
          () => mockJournalDb
              .journalEntityIdsByDateFromDesc(['to-id-1', 'to-id-2']),
        ).thenReturn(mockIdsQuery);
        when(mockIdsQuery.get).thenAnswer((_) async => ['to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(result, hasLength(2));
        // The order should match what was returned by journalEntityIdsByDateFromDesc
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb
              .journalEntityIdsByDateFromDesc(['to-id-1', 'to-id-2']),
        ).called(1);
      });

      test('includes hidden links when includeHidden is true', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
          hidden: true,
        );

        final mockDbEntry = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: true,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink),
        );

        final mockEntries = [mockDbEntry];
        final mockLinksQuery = MockSelectableLinkedDbEntry();
        final mockIdsQuery = MockSelectableString();

        // Mock the linksFromId query
        when(() => mockJournalDb.linksFromId(fromId, [false, true]))
            .thenReturn(mockLinksQuery);
        when(mockLinksQuery.get).thenAnswer((_) async => mockEntries);

        // Mock the journalEntityIdsByDateFromDesc query
        when(() => mockJournalDb.journalEntityIdsByDateFromDesc(['to-id-1']))
            .thenReturn(mockIdsQuery);
        when(mockIdsQuery.get).thenAnswer((_) async => ['to-id-1']);

        // Act
        final result =
            await repository.getLinksFromId(fromId, includeHidden: true);

        // Assert
        expect(result, hasLength(1));
        expect(result[0].toId, equals('to-id-1'));
        expect(result[0].hidden, isTrue);
        verify(() => mockJournalDb.linksFromId(fromId, [false, true]))
            .called(1);
      });

      test('filters out null links when some IDs do not have links', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink1 = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final entryLink2 = EntryLink.basic(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final mockDbEntry1 = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink1),
        );

        final mockDbEntry2 = LinkedDbEntry(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink2),
        );

        final mockEntries = [mockDbEntry1, mockDbEntry2];
        final mockLinksQuery = MockSelectableLinkedDbEntry();
        final mockIdsQuery = MockSelectableString();

        // Mock the linksFromId query
        when(() => mockJournalDb.linksFromId(fromId, [false]))
            .thenReturn(mockLinksQuery);
        when(mockLinksQuery.get).thenAnswer((_) async => mockEntries);

        // Mock the journalEntityIdsByDateFromDesc query to return an ID that doesn't exist
        // in our links map to test the nonNulls filtering
        when(
          () => mockJournalDb
              .journalEntityIdsByDateFromDesc(['to-id-1', 'to-id-2']),
        ).thenReturn(mockIdsQuery);
        when(mockIdsQuery.get)
            .thenAnswer((_) async => ['to-id-3', 'to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(
            result,
            hasLength(
                2)); // Only 2 links exist, even though 3 IDs were returned
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb
              .journalEntityIdsByDateFromDesc(['to-id-1', 'to-id-2']),
        ).called(1);
      });
    });

    group('deleteJournalEntity with ChecklistItem', () {
      test('triggers task summary refresh when deleting a ChecklistItem',
          () async {
        // Arrange
        const journalEntityId = 'checklist-item-id';
        const checklistId1 = 'checklist-1';
        const checklistId2 = 'checklist-2';

        final checklistItem = JournalEntity.checklistItem(
          meta: Metadata(
            id: journalEntityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2023),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: false,
            linkedChecklists: [checklistId1, checklistId2],
          ),
        );

        final updatedMeta = checklistItem.meta.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Create mock for task summary refresh service
        final mockTaskSummaryRefreshService = MockTaskSummaryRefreshService();

        // Mock the ref to return the mock service
        final mockRef = MockRef();
        when(() => mockRef.read(taskSummaryRefreshServiceProvider))
            .thenReturn(mockTaskSummaryRefreshService);

        // Create repository with mocked ref
        final testRepository = JournalRepository(mockRef);

        // Mock the journalEntityById call to return a ChecklistItem
        when(() => mockJournalDb.journalEntityById(journalEntityId))
            .thenAnswer((_) async => checklistItem);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            checklistItem.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(() => mockPersistenceLogic.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(() => mockNotificationService.updateBadge())
            .thenAnswer((_) async {});

        // Mock the task summary refresh service call
        when(() =>
            mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
              checklistId: any(named: 'checklistId'),
              callingDomain: any(named: 'callingDomain'),
            )).thenAnswer((_) async {});

        // Act
        final result =
            await testRepository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.journalEntityById(journalEntityId))
            .called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            checklistItem.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify task summary refresh was called for each linked checklist
        verify(() =>
            mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
              checklistId: checklistId1,
              callingDomain: 'JournalRepository',
            )).called(1);
        verify(() =>
            mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
              checklistId: checklistId2,
              callingDomain: 'JournalRepository',
            )).called(1);
      });
    });

    group('createTextEntry', () {
      test('successfully creates a text entry', () async {
        // Arrange
        const entryText = EntryText(
          plainText: 'Test content',
          markdown: 'Test content',
        );
        final started = DateTime(2023);
        const id = 'test-id';
        const linkedId = 'linked-id';
        const categoryId = 'category-id';

        final testMetadata = Metadata(
          id: id,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: started,
          dateTo: started,
          starred: false,
          private: false,
          flag: EntryFlag.none,
          categoryId: categoryId,
        );

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: started,
            categoryId: categoryId,
          ),
        ).thenAnswer((_) async => testMetadata);

        // Mock the createDbEntity call
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await JournalRepository.createTextEntry(
          entryText,
          started: started,
          id: id,
          linkedId: linkedId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isNotNull);
        expect(result, isA<JournalEntry>());
        expect((result as JournalEntry?)?.entryText, equals(entryText));
        expect(result?.meta.categoryId, equals(categoryId));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: started,
            categoryId: categoryId,
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
          ),
        ).called(1);
      });

      test('handles exceptions and returns null', () async {
        // Arrange
        const entryText = EntryText(
          plainText: 'Test content',
          markdown: 'Test content',
        );
        final started = DateTime(2023);
        const id = 'test-id';

        // Mock the createMetadata call to throw an exception
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await JournalRepository.createTextEntry(
          entryText,
          started: started,
          id: id,
        );

        // Assert
        expect(result, isNull);
        verify(
          () => mockLoggingService.captureException(
            any(),
            domain: 'JournalRepository',
            subDomain: 'createTextEntry',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('createImageEntry', () {
      test('successfully creates an image entry', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
          geolocation: Geolocation(
            createdAt: DateTime(2023),
            latitude: 37.7749,
            longitude: -122.4194,
            geohashString: 'test-geohash',
            accuracy: 10,
            altitude: 0,
          ),
        );
        const linkedId = 'linked-id';
        const categoryId = 'category-id';

        final testMetadata = Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          starred: false,
          private: false,
          flag: EntryFlag.import,
          categoryId: categoryId,
        );

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: imageData.capturedAt,
            dateTo: imageData.capturedAt,
            uuidV5Input: json.encode(imageData),
            flag: EntryFlag.import,
            categoryId: categoryId,
          ),
        ).thenAnswer((_) async => testMetadata);

        // Mock the createDbEntity call
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await JournalRepository.createImageEntry(
          imageData,
          linkedId: linkedId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isNotNull);
        expect(result, isA<JournalImage>());
        expect((result as JournalImage?)?.data, equals(imageData));
        expect(result?.geolocation, equals(imageData.geolocation));
        expect(result?.meta.categoryId, equals(categoryId));
        expect(result?.meta.flag, equals(EntryFlag.import));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: imageData.capturedAt,
            dateTo: imageData.capturedAt,
            uuidV5Input: json.encode(imageData),
            flag: EntryFlag.import,
            categoryId: categoryId,
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
            shouldAddGeolocation: false,
          ),
        ).called(1);
      });

      test('handles exceptions and returns null', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );

        // Mock the createMetadata call to throw an exception
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await JournalRepository.createImageEntry(imageData);

        // Assert
        expect(result, isNull);
        verify(
          () => mockLoggingService.captureException(
            any(),
            domain: 'JournalRepository',
            subDomain: 'createImageEntry',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('getLinkedToEntities', () {
      test('converts db entities using fromDbEntity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';
        final dateTime2023 = DateTime(2023);

        // Create mock db entities
        final dbEntity1 = JournalDbEntity(
          id: 'entity-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'JournalEntry',
          subtype: '',
          task: false,
          taskStatus: '',
          starred: false,
          private: false,
          flag: 0,
          category: 'journal',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(
            JournalEntity.journalEntry(
              entryText: const EntryText(
                plainText: 'Entry 1',
                markdown: 'Entry 1',
              ),
              meta: Metadata(
                id: 'entity-1',
                createdAt: dateTime2023,
                updatedAt: dateTime2023,
                dateFrom: dateTime2023,
                dateTo: dateTime2023,
                starred: false,
                private: false,
                flag: EntryFlag.none,
              ),
            ).toJson(),
          ),
        );

        final dbEntity2 = JournalDbEntity(
          id: 'entity-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'JournalEntry',
          subtype: '',
          task: false,
          taskStatus: '',
          starred: false,
          private: false,
          flag: 0,
          category: 'journal',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(
            JournalEntity.journalEntry(
              entryText: const EntryText(
                plainText: 'Entry 2',
                markdown: 'Entry 2',
              ),
              meta: Metadata(
                id: 'entity-2',
                createdAt: dateTime2023,
                updatedAt: dateTime2023,
                dateFrom: dateTime2023,
                dateTo: dateTime2023,
                starred: false,
                private: false,
                flag: EntryFlag.none,
              ),
            ).toJson(),
          ),
        );

        final mockSelectableJournalDbEntities = MockSelectableJournalDbEntity();
        final mockDbEntities = [dbEntity1, dbEntity2];

        // Mock JournalDb
        when(() => mockJournalDb.linkedToJournalEntities(linkedTo))
            .thenReturn(mockSelectableJournalDbEntities);
        when(mockSelectableJournalDbEntities.get)
            .thenAnswer((_) async => mockDbEntities);

        // Act
        final result = await repository.getLinkedToEntities(linkedTo: linkedTo);

        // Assert
        expect(result, hasLength(2));
        expect(result[0], isA<JournalEntry>());
        expect(result[1], isA<JournalEntry>());
        expect((result[0] as JournalEntry).meta.id, equals('entity-1'));
        expect((result[1] as JournalEntry).meta.id, equals('entity-2'));

        verify(() => mockJournalDb.linkedToJournalEntities(linkedTo)).called(1);
        verify(mockSelectableJournalDbEntities.get).called(1);
      });
    });
  });
}
