// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
// Get the getIt instance to inject our mocks
import 'package:lotti/get_it.dart' show getIt;
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Base metadata fixture for repository tests — every field defaults to the
/// shared 2023 timestamps; pass only what differs.
Metadata testMeta({
  String id = 'test-id',
  String? categoryId,
  DateTime? deletedAt,
  VectorClock? vectorClock,
  bool starred = false,
  bool private = false,
  EntryFlag flag = EntryFlag.none,
}) {
  return Metadata(
    id: id,
    createdAt: DateTime(2023),
    updatedAt: DateTime(2023),
    dateFrom: DateTime(2023),
    dateTo: DateTime(2023),
    starred: starred,
    private: private,
    flag: flag,
    categoryId: categoryId,
    deletedAt: deletedAt,
    vectorClock: vectorClock,
  );
}

/// Journal-entry fixture wrapping [testMeta]; pass only the fields that differ.
///
/// Defaults to the canonical `'Test content'` / `'test'` text used across the
/// mutation and read tests. Provide [meta] when a non-default metadata shape is
/// needed (e.g. a specific id or non-2023 timestamps).
JournalEntity testJournalEntry({
  Metadata? meta,
  String plainText = 'Test content',
  String markdown = 'test',
}) {
  return JournalEntity.journalEntry(
    entryText: EntryText(plainText: plainText, markdown: markdown),
    meta: meta ?? testMeta(),
  );
}

void main() {
  group('JournalRepository', () {
    late MockJournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockNotificationService mockNotificationService;
    late MockDomainLogger mockDomainLogger;
    late MockVectorClockService mockVectorClockService;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockOutboxService mockOutboxService;
    late MockTimeService mockTimeService;
    late JournalRepository repository;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      mockJournalDb = MockJournalDb();
      mockPersistenceLogic = MockPersistenceLogic();
      mockNotificationService = MockNotificationService();
      mockDomainLogger = MockDomainLogger();
      mockVectorClockService = MockVectorClockService();
      mockUpdateNotifications = MockUpdateNotifications();
      mockOutboxService = MockOutboxService();
      mockTimeService = MockTimeService();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockDomainLogger)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..registerSingleton<NotificationService>(mockNotificationService)
            ..registerSingleton<VectorClockService>(mockVectorClockService)
            ..registerSingleton<OutboxService>(mockOutboxService)
            ..registerSingleton<TimeService>(mockTimeService);
        },
      );

      repository = JournalRepository();
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    group('updateCategoryId', () {
      test('returns true when successfully updating category ID', () async {
        // Arrange
        const journalEntityId = 'test-id';
        const categoryId = 'category-id';

        final testEntity = testJournalEntry();

        final updatedMeta = testEntity.meta.copyWith(
          categoryId: categoryId,
          updatedAt: DateTime(2024, 3, 15, 10, 30),
        );

        // Mock the journalEntityById call to return our test entity
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
            clearCategoryId: false,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
            clearCategoryId: false,
          ),
        ).called(1);
        verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
      });

      test('returns false when journal entity not found', () async {
        // Arrange
        const journalEntityId = 'non-existent-id';
        const categoryId = 'category-id';

        // Mock the journalEntityById call to return null
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isFalse);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
        verifyNever(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            categoryId: any(named: 'categoryId'),
            clearCategoryId: any(named: 'clearCategoryId'),
          ),
        );
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('clears category ID when passed null', () async {
        // Arrange
        const journalEntityId = 'test-id';
        const String? categoryId = null;

        final testEntity = testJournalEntry(
          meta: testMeta(categoryId: 'existing-category'),
        );

        final updatedMeta = testEntity.meta.copyWith(
          categoryId: null,
          updatedAt: DateTime(2024, 3, 15, 10, 30),
        );

        // Mock the journalEntityById call to return our test entity
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call with clearCategoryId: true
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
            clearCategoryId: true,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.updateCategoryId(
          journalEntityId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            categoryId: categoryId,
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
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenThrow(Exception('Test exception'));

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
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateCategoryId',
          ),
        ).called(1);
      });
    });

    group('deleteJournalEntity', () {
      test(
        'logs to DomainLogger and returns true when the lookup throws',
        () async {
          when(
            () => mockJournalDb.journalEntityById(any()),
          ).thenThrow(Exception('db exploded'));

          final result = await repository.deleteJournalEntity('boom-id');

          // The method catches, logs, and reports success like its siblings.
          expect(result, isTrue);
          verify(
            () => mockDomainLogger.error(
              LogDomain.persistence,
              any(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'deleteJournalEntity',
            ),
          ).called(1);
        },
      );

      test('marks the entity as deleted and returns true on success', () async {
        // Arrange
        const journalEntityId = 'test-id';

        final testEntity = testJournalEntry();

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isFalse);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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

        final testEntity = testJournalEntry(
          plainText: 'Timer entry',
          markdown: 'timer',
          meta: testMeta(id: journalEntityId),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return the current timer entry
        when(() => mockTimeService.getCurrent()).thenReturn(testEntity);

        // Mock TimeService.stop
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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

        final testEntity = testJournalEntry(
          plainText: 'Non-active entry',
          meta: testMeta(id: journalEntityId),
        );

        final activeTimer = testJournalEntry(
          plainText: 'Active timer',
          markdown: 'timer',
          meta: testMeta(id: activeTimerId),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return a DIFFERENT active timer
        when(() => mockTimeService.getCurrent()).thenReturn(activeTimer);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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

        final testEntity = testJournalEntry();

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return null (no active timer)
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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

        final testEntity = testJournalEntry(
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
          updatedAt: DateTime(2024, 3, 15, 10, 30),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

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
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.updateJournalEntityDate(
          journalEntityId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Assert
        expect(result, isFalse);
        verify(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).called(1);
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
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await repository.updateJournalEntityDate(
          journalEntityId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        // Assert
        expect(result, isTrue);

        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateJournalEntityDate',
          ),
        ).called(1);
      });
    });

    group('updateJournalEntity', () {
      test('delegates to PersistenceLogic and returns the result', () async {
        // Arrange
        final testEntity = testJournalEntry();

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
        final testEntity = testJournalEntry();

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
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateJournalEntity',
          ),
        ).called(1);
      });
    });

    group('updateLink', () {
      test(
        'returns false without notifying when upsertEntryLink writes 0 rows '
        '(identical row already exists inside the VC scope)',
        () async {
          final testLink = EntryLink.basic(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final changed = testLink.copyWith(hidden: true);

          when(
            () => mockJournalDb.entryLinkById(changed.id),
          ).thenAnswer((_) async => testLink);
          when(
            () => mockVectorClockService.getNextVectorClock(),
          ).thenAnswer((_) async => const VectorClock({'node1': 1}));
          // Identical row already on disk: zero rows written.
          when(
            () => mockJournalDb.upsertEntryLink(any()),
          ).thenAnswer((_) async => 0);

          final result = await repository.updateLink(changed);

          expect(result, isFalse);
          verifyNever(() => mockUpdateNotifications.notify(any()));
          verifyNever(() => mockOutboxService.enqueueMessage(any()));
        },
      );

      test(
        'logs the outbox failure and still returns true when enqueueMessage '
        'throws after the row was written',
        () async {
          final testLink = EntryLink.basic(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final changed = testLink.copyWith(hidden: true);

          when(
            () => mockJournalDb.entryLinkById(changed.id),
          ).thenAnswer((_) async => testLink);
          when(
            () => mockVectorClockService.getNextVectorClock(),
          ).thenAnswer((_) async => const VectorClock({'node1': 1}));
          when(
            () => mockJournalDb.upsertEntryLink(any()),
          ).thenAnswer((_) async => 1);
          when(
            () => mockUpdateNotifications.notify(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(Exception('outbox unavailable'));

          final result = await repository.updateLink(changed);

          // The local write landed; an outbox failure must not undo it.
          expect(result, isTrue);
          verify(
            () => mockDomainLogger.error(
              LogDomain.sync,
              any(),
              message: any(named: 'message'),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'updateLink.enqueue',
            ),
          ).called(1);
        },
      );

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
        final updatedLink = testLink.copyWith(hidden: true);

        when(
          () => mockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);

        // Mock VectorClockService
        when(
          () => mockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));

        // Mock JournalDb
        when(
          () => mockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);

        // Mock UpdateNotifications
        when(
          () => mockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});

        // Mock OutboxService
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.updateLink(updatedLink);

        // Assert
        expect(result, isTrue);
        verify(() => mockJournalDb.entryLinkById(updatedLink.id)).called(1);
        verify(() => mockVectorClockService.getNextVectorClock()).called(1);
        verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
        verify(
          () => mockUpdateNotifications.notify({
            testLink.fromId,
            testLink.toId,
            linkNotification,
          }),
        ).called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });

      test('skips update when the link is unchanged', () async {
        // Arrange
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final existingLink = testLink.copyWith(hidden: false);

        when(
          () => mockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => existingLink);

        // Act
        final result = await repository.updateLink(testLink);

        // Assert
        expect(result, isFalse);
        verify(() => mockJournalDb.entryLinkById(testLink.id)).called(1);
        verifyNever(() => mockVectorClockService.getNextVectorClock());
        verifyNever(() => mockJournalDb.upsertEntryLink(any()));
        verifyNever(() => mockUpdateNotifications.notify(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });
    });

    group('removeLink', () {
      test(
        'returns 0 when the link did not exist and still notifies',
        () async {
          when(
            () => mockJournalDb.deleteLink('from-id', 'to-id'),
          ).thenAnswer((_) async => 0);
          when(
            () => mockUpdateNotifications.notify(any()),
          ).thenAnswer((_) async {});

          final result = await repository.removeLink(
            fromId: 'from-id',
            toId: 'to-id',
          );

          expect(result, 0);
          // Notification fires unconditionally — by design.
          verify(
            () => mockUpdateNotifications.notify({
              'from-id',
              'to-id',
              linkNotification,
            }),
          ).called(1);
        },
      );

      test('successfully removes a link and returns the result', () async {
        // Arrange
        const fromId = 'from-id';
        const toId = 'to-id';

        // Mock JournalDb
        when(
          () => mockJournalDb.deleteLink(fromId, toId),
        ).thenAnswer((_) async => 1);

        // Mock UpdateNotifications
        when(
          () => mockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.removeLink(
          fromId: fromId,
          toId: toId,
        );

        // Assert
        expect(result, equals(1));
        verify(() => mockJournalDb.deleteLink(fromId, toId)).called(1);
        verify(
          () => mockUpdateNotifications.notify({
            fromId,
            toId,
            linkNotification,
          }),
        ).called(1);
      });
    });

    group('getLinkedEntities', () {
      test('returns all linked entities for the specified entity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';

        final testEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
          testJournalEntry(
            plainText: 'Entry 2',
            markdown: 'Entry 2',
            meta: testMeta(id: 'entry-2'),
          ),
        ];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => testEntities);

        // Act
        final result = await repository.getLinkedEntities(linkedTo: linkedTo);

        // Assert
        expect(result, equals(testEntities));
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });

      test('concurrent lookups each hit the DB', () async {
        const linkedTo = 'linked-to-id';
        final testEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
        ];

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => testEntities);

        final futureA = repository.getLinkedEntities(linkedTo: linkedTo);
        final futureB = repository.getLinkedEntities(linkedTo: linkedTo);

        expect(await futureA, testEntities);
        expect(await futureB, testEntities);
        // Without caching, each call hits the DB independently
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(2);
      });

      test('fetches from DB on each call', () async {
        const linkedTo = 'linked-to-id';
        final initialEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
        ];
        final refreshedEntities = [
          ...initialEntities,
          testJournalEntry(
            plainText: 'Entry 2',
            markdown: 'Entry 2',
            meta: Metadata(
              id: 'entry-2',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          ),
        ];

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => initialEntities);

        final first = await repository.getLinkedEntities(linkedTo: linkedTo);
        expect(first, initialEntities);
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => refreshedEntities);

        final refreshed = await repository.getLinkedEntities(
          linkedTo: linkedTo,
        );
        expect(refreshed.map((entity) => entity.meta.id), [
          'entry-1',
          'entry-2',
        ]);
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });
    });

    group('getJournalEntityById', () {
      test('returns the journal entity when found', () async {
        // Arrange
        const entityId = 'test-entity-id';
        final testEntity = testJournalEntry(meta: testMeta(id: entityId));

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => testEntity);

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
        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getJournalEntityById(entityId);

        // Assert
        expect(result, isNull);
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });

      test('fetches from DB on each call without caching', () async {
        const entityId = 'test-entity-id';
        final initialEntity = testJournalEntry(
          plainText: 'Initial content',
          markdown: 'initial',
          meta: testMeta(id: entityId),
        );
        final updatedEntity = testJournalEntry(
          plainText: 'Updated content',
          markdown: 'updated',
          meta: Metadata(
            id: entityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2024),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => initialEntity);

        expect(await repository.getJournalEntityById(entityId), initialEntity);
        expect(await repository.getJournalEntityById(entityId), initialEntity);
        // Without caching, each call hits the DB
        verify(() => mockJournalDb.journalEntityById(entityId)).called(2);

        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => updatedEntity);

        expect(await repository.getJournalEntityById(entityId), updatedEntity);
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });
    });

    group('getLinksFromId', () {
      test(
        'returns empty list without sorting when there are no links',
        () async {
          const fromId = 'from-id';
          final mockLinksQuery = MockSelectable<LinkedDbEntry>(
            <LinkedDbEntry>[],
          );

          when(
            () => mockJournalDb.linksFromId(fromId, [false]),
          ).thenReturn(mockLinksQuery);

          final result = await repository.getLinksFromId(fromId);

          expect(result, isEmpty);
          verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
          verifyNever(
            () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc(any()),
          );
        },
      );

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
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).thenAnswer((_) async => ['to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(result, hasLength(2));
        // The order should match what was returned by journalEntityIdsByDateFromDesc
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
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
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false, true]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
          ]),
        ).thenAnswer((_) async => ['to-id-1']);

        // Act
        final result = await repository.getLinksFromId(
          fromId,
          includeHidden: true,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].toId, equals('to-id-1'));
        expect(result[0].hidden, isTrue);
        verify(
          () => mockJournalDb.linksFromId(fromId, [false, true]),
        ).called(1);
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
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query to return an ID that doesn't exist
        // in our links map to test the nonNulls filtering
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).thenAnswer((_) async => ['to-id-3', 'to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(
          result,
          hasLength(2),
        ); // Only 2 links exist, even though 3 IDs were returned
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).called(1);
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
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createTextEntry',
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
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createImageEntry',
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
            testJournalEntry(
              plainText: 'Entry 1',
              markdown: 'Entry 1',
              meta: testMeta(id: 'entity-1'),
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
            testJournalEntry(
              plainText: 'Entry 2',
              markdown: 'Entry 2',
              meta: testMeta(id: 'entity-2'),
            ).toJson(),
          ),
        );

        final mockDbEntities = [dbEntity1, dbEntity2];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedToEntities(linkedTo),
        ).thenAnswer((_) async => mockDbEntities);

        // Act
        final result = await repository.getLinkedToEntities(linkedTo: linkedTo);

        // Assert
        expect(result, hasLength(2));
        expect(result[0], isA<JournalEntry>());
        expect(result[1], isA<JournalEntry>());
        expect((result[0] as JournalEntry).meta.id, equals('entity-1'));
        expect((result[1] as JournalEntry).meta.id, equals('entity-2'));

        verify(() => mockJournalDb.getLinkedToEntities(linkedTo)).called(1);
      });

      test(
        'fetches reverse-linked entities from DB on each call',
        () async {
          const linkedTo = 'linked-to-id';
          final dateTime2023 = DateTime(2023);
          final dbEntity = JournalDbEntity(
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
              testJournalEntry(
                plainText: 'Entry 1',
                markdown: 'Entry 1',
                meta: testMeta(id: 'entity-1'),
              ).toJson(),
            ),
          );

          when(
            () => mockJournalDb.getLinkedToEntities(linkedTo),
          ).thenAnswer((_) async => [dbEntity]);

          final result = await repository.getLinkedToEntities(
            linkedTo: linkedTo,
          );

          expect(result.single.meta.id, 'entity-1');
          verify(() => mockJournalDb.getLinkedToEntities(linkedTo)).called(1);
        },
      );
    });

    group('getLinkedImagesForTask', () {
      test('returns only JournalImage entities from linked entities', () async {
        // Arrange
        const taskId = 'task-id';
        final dateTime2023 = DateTime(2023);

        // Create a mix of entity types
        final journalEntry = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
          ),
          meta: Metadata(
            id: 'entry-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
        );

        final journalImage1 = JournalEntity.journalImage(
          meta: Metadata(
            id: 'image-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-1',
            imageFile: 'image1.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        final journalImage2 = JournalEntity.journalImage(
          meta: Metadata(
            id: 'image-2',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-2',
            imageFile: 'image2.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        final linkedEntities = [journalEntry, journalImage1, journalImage2];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => linkedEntities);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, hasLength(2));
        expect(result[0], isA<JournalImage>());
        expect(result[1], isA<JournalImage>());
        expect(result[0].meta.id, equals('image-1'));
        expect(result[1].meta.id, equals('image-2'));

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });

      test('returns empty list when no images are linked', () async {
        // Arrange
        const taskId = 'task-id';
        final dateTime2023 = DateTime(2023);

        // Create only non-image entities
        final journalEntry = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
          ),
          meta: Metadata(
            id: 'entry-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
        );

        final audioEntry = JournalEntity.journalAudio(
          meta: Metadata(
            id: 'audio-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: AudioData(
            audioFile: 'audio.m4a',
            audioDirectory: '/path/to/audio',
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            duration: const Duration(minutes: 2),
          ),
        );

        final linkedEntities = [journalEntry, audioEntry];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => linkedEntities);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, isEmpty);

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });

      test('returns empty list when no linked entities exist', () async {
        // Arrange
        const taskId = 'task-id';

        // Mock JournalDb to return empty list
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, isEmpty);

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });
    });

    group('deleteJournalEntity with JournalImage cover art', () {
      test('clears coverArtId from tasks that reference deleted image', () async {
        // Arrange
        const imageId = 'image-to-delete';
        final dateTime2023 = DateTime(2023);

        // Create the image entity to be deleted
        final imageEntity = JournalEntity.journalImage(
          meta: Metadata(
            id: imageId,
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-uuid',
            imageFile: 'test.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        // Create tasks that reference this image as cover art
        final taskWithCoverArt = JournalEntity.task(
          meta: Metadata(
            id: 'task-with-cover',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's',
              createdAt: dateTime2023,
              utcOffset: 0,
            ),
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            statusHistory: const [],
            title: 'Task with cover art',
            coverArtId: imageId, // References the image being deleted
          ),
        );

        // Create a task without the coverArtId (should not be updated)
        final taskWithoutCoverArt = JournalEntity.task(
          meta: Metadata(
            id: 'task-without-cover',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's2',
              createdAt: dateTime2023,
              utcOffset: 0,
            ),
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            statusHistory: const [],
            title: 'Task without cover art',
          ),
        );

        final updatedMeta = imageEntity.meta.copyWith(
          deletedAt: dateTime2023,
          updatedAt: dateTime2023,
        );

        // Create JournalDbEntity representations for the tasks
        final taskDbEntity1 = JournalDbEntity(
          id: 'task-with-cover',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'Task',
          subtype: '',
          task: true,
          taskStatus: 'open',
          starred: false,
          private: false,
          flag: 0,
          category: '',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(taskWithCoverArt.toJson()),
        );

        final taskDbEntity2 = JournalDbEntity(
          id: 'task-without-cover',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'Task',
          subtype: '',
          task: true,
          taskStatus: 'open',
          starred: false,
          private: false,
          flag: 0,
          category: '',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(taskWithoutCoverArt.toJson()),
        );

        // Mock the journalEntityById call for the image
        when(
          () => mockJournalDb.journalEntityById(imageId),
        ).thenAnswer((_) async => imageEntity);

        // Mock linkedToJournalEntities to return tasks that link to this image
        when(
          () => mockJournalDb.getLinkedToEntities(imageId),
        ).thenAnswer((_) async => [taskDbEntity1, taskDbEntity2]);

        // Mock updateTask for clearing coverArtId
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateMetadata call for the image deletion
        when(
          () => mockPersistenceLogic.updateMetadata(
            imageEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call for the image
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return null
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        // Act
        final result = await repository.deleteJournalEntity(imageId);

        // Assert
        expect(result, isTrue);

        // Verify the image was looked up
        verify(() => mockJournalDb.journalEntityById(imageId)).called(1);

        // Verify that we looked for tasks that link to this image
        verify(() => mockJournalDb.getLinkedToEntities(imageId)).called(1);

        // Verify updateTask was called once (only for the task with coverArtId)
        verify(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: 'task-with-cover',
            taskData: any(named: 'taskData'),
          ),
        ).called(1);

        // Verify the image entity was soft-deleted
        verify(
          () => mockPersistenceLogic.updateMetadata(
            imageEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
      });
    });

    group('createImageEntry - callback behavior', () {
      test('invokes onCreated callback after successful creation', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );
        const linkedId = 'linked-id';

        final testMetadata = Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          starred: false,
          private: false,
          flag: EntryFlag.import,
        );

        JournalEntity? callbackEntity;

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
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
          onCreated: (entity) {
            callbackEntity = entity;
          },
        );

        // Assert
        expect(result, isNotNull);
        expect(result, isA<JournalImage>());

        // Verify callback was invoked with the created entity
        expect(callbackEntity, isNotNull);
        expect(callbackEntity, isA<JournalImage>());
        expect(callbackEntity!.meta.id, equals(result!.meta.id));
      });

      test('does not invoke onCreated callback when creation fails', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );

        var callbackInvoked = false;

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
        final result = await JournalRepository.createImageEntry(
          imageData,
          onCreated: (entity) {
            callbackInvoked = true;
          },
        );

        // Assert
        expect(result, isNull);
        expect(callbackInvoked, isFalse);
      });
    });

    group('getJournalEntitiesByIds', () {
      test(
        'returns exactly what the DB yields when some ids resolve to '
        'no entity',
        () async {
          final onlyFound = testJournalEntry(
            plainText: 'found',
            markdown: 'found',
            meta: testMeta(id: 'found-id'),
          );
          when(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered(
              {'found-id', 'missing-id'},
            ),
          ).thenAnswer((_) async => [onlyFound]);

          final result = await repository.getJournalEntitiesByIds(
            {'found-id', 'missing-id'},
          );

          expect(result, [onlyFound]);
        },
      );

      test(
        'returns empty list without hitting the DB for an empty input',
        () async {
          final result = await repository.getJournalEntitiesByIds(
            const <String>[],
          );

          expect(result, isEmpty);
          // Crucially: the bulk fetch must NOT be called for the empty
          // case — otherwise we issue an unnecessary `id IN ()` query
          // that drift would reject.
          verifyNever(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
          );
        },
      );

      test('delegates to the bulk fetcher and dedupes the input set', () async {
        final entity = testJournalEntry(
          plainText: 'bulk-fetch',
          markdown: 'bulk',
          meta: Metadata(
            id: 'a',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );
        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => [entity]);

        final result = await repository.getJournalEntitiesByIds(
          ['a', 'a', 'b'],
        );

        expect(result, [entity]);
        final captured =
            verify(
                  () => mockJournalDb.getJournalEntitiesForIdsUnordered(
                    captureAny(),
                  ),
                ).captured.single
                as Set<String>;
        expect(captured, {'a', 'b'});
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Tests from journal_repository_collapsed_test.dart — collapsed-link logic
  // Uses LoggingService (instead of DomainLogger) so setUp/tearDown are
  // isolated inside this group.
  // ---------------------------------------------------------------------------
  group('updateLink collapsed', () {
    late MockJournalDb collapsedMockJournalDb;
    late MockVectorClockService collapsedMockVectorClockService;
    late MockUpdateNotifications collapsedMockUpdateNotifications;
    late MockOutboxService collapsedMockOutboxService;
    late JournalRepository collapsedRepository;

    setUp(() {
      collapsedMockJournalDb = MockJournalDb();
      collapsedMockVectorClockService = MockVectorClockService();
      collapsedMockUpdateNotifications = MockUpdateNotifications();
      collapsedMockOutboxService = MockOutboxService();

      getIt
        ..registerSingleton<JournalDb>(collapsedMockJournalDb)
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<NotificationService>(MockNotificationService())
        ..registerSingleton<VectorClockService>(collapsedMockVectorClockService)
        ..registerSingleton<UpdateNotifications>(
          collapsedMockUpdateNotifications,
        )
        ..registerSingleton<OutboxService>(collapsedMockOutboxService)
        ..registerSingleton<TimeService>(MockTimeService());

      collapsedRepository = JournalRepository();

      registerFallbackValue(
        testMeta(),
      );
      registerFallbackValue(
        testJournalEntry(plainText: 'test'),
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
      registerFallbackValue(
        TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: DateTime(2023),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          statusHistory: const [],
          title: 'Test Task',
        ),
      );
      registerFallbackValue(EntryFlag.none);
      registerFallbackValue(DateTime(2023));
    });

    tearDown(() async {
      await getIt.reset();
    });

    group('updateLink with collapsed', () {
      test('syncs collapsed change to other devices', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final updatedLink = testLink.copyWith(collapsed: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(updatedLink);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        verify(() => collapsedMockUpdateNotifications.notify(any())).called(1);
        verify(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).called(1);
        verify(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).called(1);
      });

      test('skips update when collapsed is unchanged (both null)', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => testLink);

        final result = await collapsedRepository.updateLink(testLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
        verifyNever(() => collapsedMockOutboxService.enqueueMessage(any()));
      });

      test('skips update when collapsed is unchanged (both false)', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: false,
        );
        final existing = testLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => existing);

        final result = await collapsedRepository.updateLink(testLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('treats null and false collapsed as equivalent', () async {
        final existingLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          // collapsed is null
        );
        final incomingLink = existingLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(incomingLink.id),
        ).thenAnswer((_) async => existingLink);

        final result = await collapsedRepository.updateLink(incomingLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('syncs collapsed true -> false to other devices', () async {
        final existingLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: true,
        );
        final incomingLink = existingLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(incomingLink.id),
        ).thenAnswer((_) async => existingLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incomingLink);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        verify(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).called(1);
        verify(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).called(1);
      });

      test('notifies affected IDs after collapsed update', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final updatedLink = testLink.copyWith(collapsed: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await collapsedRepository.updateLink(updatedLink);

        verify(
          () => collapsedMockUpdateNotifications.notify({
            'from-id',
            'to-id',
            linkNotification,
          }),
        ).called(1);
      });
    });

    group('debugHasChange (pure comparator properties)', () {
      EntryLink buildLink({
        String id = 'link-id',
        String fromId = 'from-id',
        String toId = 'to-id',
        DateTime? createdAt,
        DateTime? updatedAt,
        DateTime? deletedAt,
        bool? hidden,
        bool? collapsed,
      }) => EntryLink.basic(
        id: id,
        fromId: fromId,
        toId: toId,
        createdAt: createdAt ?? DateTime(2023),
        updatedAt: updatedAt ?? DateTime(2023),
        vectorClock: null,
        hidden: hidden,
        collapsed: collapsed,
      ).copyWith(deletedAt: deletedAt);

      glados.Glados(
        glados.IntAnys(glados.any).intInRange(0, 36),
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'identical-by-compared-fields pairs are no-change; any compared-field '
        'mutation is a change; non-compared fields never count',
        (seed) {
          final hidden = const [null, false, true][seed % 3];
          final collapsed = const [null, false, true][(seed ~/ 3) % 3];
          final deletedAt = (seed ~/ 9).isEven ? null : DateTime(2024);
          final base = buildLink(
            hidden: hidden,
            collapsed: collapsed,
            deletedAt: deletedAt,
          );
          final reason = 'seed=$seed';

          // Reflexivity: a structurally identical link is no change.
          expect(
            collapsedRepository.debugHasChange(
              base,
              buildLink(
                hidden: hidden,
                collapsed: collapsed,
                deletedAt: deletedAt,
              ),
            ),
            isFalse,
            reason: reason,
          );

          // null and false are equivalent for hidden/collapsed.
          if (hidden != true) {
            expect(
              collapsedRepository.debugHasChange(
                base,
                buildLink(
                  hidden: hidden == null ? false : null,
                  collapsed: collapsed,
                  deletedAt: deletedAt,
                ),
              ),
              isFalse,
              reason: '$reason hidden null<->false',
            );
          }

          // Every compared-field mutation flips the verdict.
          final mutations = <String, EntryLink>{
            'fromId': base.copyWith(fromId: 'other-from'),
            'toId': base.copyWith(toId: 'other-to'),
            'createdAt': base.copyWith(createdAt: DateTime(2025)),
            'deletedAt': base.copyWith(
              deletedAt: deletedAt == null ? DateTime(2025) : null,
            ),
            'hidden': base.copyWith(hidden: hidden != true),
            'collapsed': base.copyWith(collapsed: collapsed != true),
          };
          for (final MapEntry(key: field, value: mutated)
              in mutations.entries) {
            expect(
              collapsedRepository.debugHasChange(base, mutated),
              isTrue,
              reason: '$reason mutated=$field',
            );
          }

          // Non-compared fields (id, updatedAt, vectorClock) never count.
          expect(
            collapsedRepository.debugHasChange(
              base,
              base.copyWith(
                id: 'different-id',
                updatedAt: DateTime(2030),
                vectorClock: const VectorClock({'host': 9}),
              ),
            ),
            isFalse,
            reason: '$reason non-compared fields',
          );
        },
        tags: 'glados',
      );
    });

    group('_hasChange via updateLink', () {
      test('detects fromId change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-1',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-2',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });

      test('detects toId change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-1',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-2',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });

      test('detects createdAt change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test('detects deletedAt change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          deletedAt: DateTime(2024),
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test('includes collapsed in sync payload', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: true,
        );
        // Change hidden while collapsed is true
        final incoming = existing.copyWith(hidden: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await collapsedRepository.updateLink(incoming);

        // Verify the sync message includes collapsed state
        final captured =
            verify(
                  () => collapsedMockOutboxService.enqueueMessage(captureAny()),
                ).captured.single
                as SyncEntryLink;
        expect(captured.entryLink.collapsed, isTrue);
      });

      test('detects hidden change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          hidden: true,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test('skips update when no fields changed', () async {
        final link = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          hidden: true,
          collapsed: true,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(link.id),
        ).thenAnswer((_) async => link);

        final result = await collapsedRepository.updateLink(link);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('proceeds when existing link is null (new link)', () async {
        final link = EntryLink.basic(
          id: 'new-link',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(link.id),
        ).thenAnswer((_) async => null);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(link);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });
    });
  });
}
