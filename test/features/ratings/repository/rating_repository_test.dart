import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late RatingRepository repository;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistence;
  late MockVectorClockService mockVectorClock;
  late MockUpdateNotifications mockNotifications;
  late MockOutboxService mockOutbox;
  late MockDomainLogger mockDomainLogger;

  const testTimeEntryId = 'time-entry-1';
  final testDate = DateTime(2024, 3, 15, 10);

  const testDimensions = [
    RatingDimension(key: 'productivity', value: 0.8),
    RatingDimension(key: 'energy', value: 0.6),
    RatingDimension(key: 'focus', value: 0.9),
    RatingDimension(key: 'challenge_skill', value: 0.5),
  ];

  final testMetadata = Metadata(
    id: 'rating-1',
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  final testRatingEntry = RatingEntry(
    meta: testMetadata,
    data: const RatingData(
      targetId: testTimeEntryId,
      dimensions: testDimensions,
      note: 'Good session',
    ),
  );

  const testVectorClock = VectorClock({'node1': 1});

  final fallbackLink = EntryLink.rating(
    id: 'fallback',
    fromId: 'from',
    toId: 'to',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: testVectorClock,
  );

  setUpAll(() {
    registerFallbackValue(testRatingEntry);
    registerFallbackValue(fallbackLink);
    registerFallbackValue(
      SyncMessage.entryLink(
        entryLink: fallbackLink,
        status: SyncEntryStatus.initial,
      ),
    );
    registerFallbackValue(StackTrace.current);
  });

  setUp(() async {
    await getIt.reset();

    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockVectorClock = MockVectorClockService();
    mockNotifications = MockUpdateNotifications();
    mockOutbox = MockOutboxService();
    mockDomainLogger = MockDomainLogger();

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistence)
      ..registerSingleton<VectorClockService>(mockVectorClock)
      ..registerSingleton<UpdateNotifications>(mockNotifications)
      ..registerSingleton<OutboxService>(mockOutbox)
      ..registerSingleton<DomainLogger>(mockDomainLogger);

    repository = RatingRepository();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('RatingRepository', () {
    group('getRatingForTargetEntry', () {
      // Stubs and verifies must pass `catalogId` explicitly because the
      // repository always passes it to the JournalDb call: noSuchMethod
      // forwarders for mixin-declared methods do not reliably fill in
      // omitted optional parameters, so a stub that omits a parameter the
      // production call passes never matches.
      test('delegates to JournalDb', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => testRatingEntry);

        final result = await repository.getRatingForTargetEntry(
          testTimeEntryId,
        );

        expect(result, equals(testRatingEntry));
        verify(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            // ignore: avoid_redundant_argument_values
            catalogId: 'session',
          ),
        ).called(1);
      });

      test('returns null when no rating exists', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);

        final result = await repository.getRatingForTargetEntry(
          testTimeEntryId,
        );

        expect(result, isNull);
      });

      test('passes catalogId to JournalDb', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: 'day_morning',
          ),
        ).thenAnswer((_) async => null);

        final result = await repository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'day_morning',
        );

        expect(result, isNull);
        verify(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: 'day_morning',
          ),
        ).called(1);
      });
    });

    group('createOrUpdateRating', () {
      test('creates new rating when none exists', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
          note: 'Test note',
        );

        expect(result, isA<RatingEntry>());
        expect(result!.data.targetId, equals(testTimeEntryId));
        expect(result.data.dimensions, equals(testDimensions));
        expect(result.data.note, equals('Test note'));

        // Verify entity was persisted
        verify(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).called(1);

        // Verify link was created
        verify(() => mockDb.upsertEntryLink(any())).called(1);

        // Verify sync was enqueued
        verify(() => mockOutbox.enqueueMessage(any())).called(1);

        // Verify notifications were sent
        verify(() => mockNotifications.notify(any())).called(1);
      });

      test('updates existing rating', () async {
        final updatedMeta = testMetadata.copyWith(
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => testRatingEntry);
        when(
          () => mockPersistence.updateMetadata(testMetadata),
        ).thenAnswer((_) async => updatedMeta);
        when(
          () => mockPersistence.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        const newDimensions = [
          RatingDimension(key: 'productivity', value: 0.9),
          RatingDimension(key: 'energy', value: 0.7),
          RatingDimension(key: 'focus', value: 1),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ];

        final result = await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: newDimensions,
          note: 'Updated note',
        );

        expect(result, isA<RatingEntry>());
        expect(result!.data.dimensions, equals(newDimensions));
        expect(result.data.note, equals('Updated note'));
        expect(result.meta.updatedAt, equals(updatedMeta.updatedAt));

        // Should update, not create
        verify(() => mockPersistence.updateDbEntity(any())).called(1);
        verifyNever(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          ),
        );

        // Should not create a new link
        verifyNever(() => mockDb.upsertEntryLink(any()));
      });

      test('creates rating without note', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        expect(result, isA<RatingEntry>());
        expect(result!.data.note, isNull);
      });

      test('inherits categoryId from time entry', () async {
        const timeEntryCategoryId = 'category-work';
        final timeEntryMeta = Metadata(
          id: testTimeEntryId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          categoryId: timeEntryCategoryId,
        );
        final timeEntry = JournalEntity.journalEntry(
          meta: timeEntryMeta,
          entryText: const EntryText(plainText: 'Work session'),
        );

        final metadataWithCategory = testMetadata.copyWith(
          categoryId: timeEntryCategoryId,
        );

        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => timeEntry);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: timeEntryCategoryId,
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => metadataWithCategory);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        expect(result, isA<RatingEntry>());
        expect(result!.meta.categoryId, equals(timeEntryCategoryId));

        // Verify the time entry was looked up
        verify(() => mockDb.journalEntityById(testTimeEntryId)).called(1);

        // Verify createMetadata was called with the category
        verify(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: timeEntryCategoryId,
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).called(1);
      });

      test('returns null and logs on exception', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenThrow(Exception('DB error'));
        when(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        expect(result, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.ratings,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'createOrUpdateRating',
          ),
        ).called(1);
      });
    });

    group('link creation', () {
      test('creates RatingLink with correct from/to IDs', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        // Verify the link has correct structure
        final captured =
            verify(() => mockDb.upsertEntryLink(captureAny())).captured.single
                as EntryLink;

        expect(captured, isA<RatingLink>());
        final ratingLink = captured as RatingLink;
        expect(ratingLink.fromId, equals(testMetadata.id));
        expect(ratingLink.toId, equals(testTimeEntryId));
        expect(ratingLink.hidden, isFalse);
      });

      test('enqueues sync message for link', () async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        final captured =
            verify(
                  () => mockOutbox.enqueueMessage(captureAny()),
                ).captured.single
                as SyncMessage;

        expect(captured, isA<SyncEntryLink>());
        final syncLink = captured as SyncEntryLink;
        expect(syncLink.entryLink, isA<RatingLink>());
        expect(syncLink.status, equals(SyncEntryStatus.initial));
      });
    });

    group('sequence-log integration', () {
      late MockSyncSequenceLogService mockSequenceLog;
      late MockDomainLogger mockDomainLogger;

      setUpAll(() => registerFallbackValue(testVectorClock));

      setUp(() {
        mockSequenceLog = MockSyncSequenceLogService();
        mockDomainLogger = MockDomainLogger();
        when(
          () => mockSequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            message: any<String>(named: 'message'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenReturn(null);
        if (getIt.isRegistered<DomainLogger>()) {
          getIt.unregister<DomainLogger>();
        }
        getIt
          ..registerSingleton<SyncSequenceLogService>(mockSequenceLog)
          ..registerSingleton<DomainLogger>(mockDomainLogger);
      });

      Future<void> stubCreateRatingFlow() async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});
      }

      test('records the new rating link sequence on create', () async {
        await stubCreateRatingFlow();

        await repository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        );

        verify(
          () => mockSequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: testVectorClock,
          ),
        ).called(1);
      });

      test(
        'sequence-record failure is swallowed and routed through DomainLogger',
        () async {
          await stubCreateRatingFlow();
          when(
            () => mockSequenceLog.recordSentEntryLink(
              linkId: any(named: 'linkId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));

          final result = await repository.createOrUpdateRating(
            targetId: testTimeEntryId,
            dimensions: testDimensions,
          );

          expect(result, isA<RatingEntry>());
          verify(
            () => mockDomainLogger.error(
              LogDomain.sync,
              any<Object>(),
              message: any<String>(
                named: 'message',
                that: contains('sequence record failed after rating link'),
              ),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: '_createRatingLink.recordSent',
            ),
          ).called(1);
          // Outbox sync still enqueued — sequence failure must not block it.
          verify(() => mockOutbox.enqueueMessage(any())).called(1);
        },
      );
    });

    group('error and rollback paths', () {
      setUpAll(() {
        registerFallbackValue(testMetadata);
      });

      Future<void> stubBaseCreateFlow({
        Future<int> Function()? upsertResult,
      }) async {
        when(
          () => mockDb.getRatingForTimeEntry(
            testTimeEntryId,
            catalogId: any(named: 'catalogId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById(testTimeEntryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((invocation) async {
          final meta = invocation.positionalArguments.first as Metadata;
          return meta.copyWith(
            deletedAt: invocation.namedArguments[#deletedAt] as DateTime?,
          );
        });
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockPersistence.updateDbEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockVectorClock.getNextVectorClock(),
        ).thenAnswer((_) async => testVectorClock);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});
        if (upsertResult != null) {
          when(() => mockDb.upsertEntryLink(any())).thenAnswer(
            (_) => upsertResult(),
          );
        }
      }

      test(
        'soft-deletes the orphaned rating entity and logs when '
        '_createRatingLink throws',
        () async {
          await stubBaseCreateFlow();
          when(
            () => mockDb.upsertEntryLink(any()),
          ).thenThrow(StateError('boom from link upsert'));

          final result = await repository.createOrUpdateRating(
            targetId: testTimeEntryId,
            dimensions: testDimensions,
          );

          expect(result, isNull);
          verify(
            () => mockDomainLogger.error(
              LogDomain.ratings,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: '_createRating.linkCleanup',
            ),
          ).called(1);
          // _softDeleteEntity issued the compensating updateDbEntity with a
          // deletedAt-stamped metadata.
          final captured =
              verify(
                    () => mockPersistence.updateDbEntity(captureAny()),
                  ).captured.single
                  as JournalEntity;
          expect(captured.meta.deletedAt, isNotNull);
        },
      );

      test(
        '_softDeleteEntity logs and swallows when the compensating '
        'updateDbEntity itself throws',
        () async {
          await stubBaseCreateFlow();
          when(
            () => mockDb.upsertEntryLink(any()),
          ).thenThrow(StateError('boom from link upsert'));
          when(
            () => mockPersistence.updateDbEntity(any()),
          ).thenThrow(StateError('boom from soft delete'));

          final result = await repository.createOrUpdateRating(
            targetId: testTimeEntryId,
            dimensions: testDimensions,
          );

          expect(result, isNull);
          verify(
            () => mockDomainLogger.error(
              LogDomain.ratings,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: '_softDeleteEntity',
            ),
          ).called(1);
        },
      );

      test(
        '_createRatingLink swallows outbox enqueue failures and routes them '
        'through DomainLogger so the already-persisted link is not rolled '
        'back by a transient outbox error',
        () async {
          final mockSequenceLog = MockSyncSequenceLogService();
          final mockDomainLogger = MockDomainLogger();
          when(
            () => mockSequenceLog.recordSentEntryLink(
              linkId: any(named: 'linkId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockDomainLogger.error(
              any<LogDomain>(),
              any<Object>(),
              message: any<String>(named: 'message'),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenReturn(null);
          if (getIt.isRegistered<DomainLogger>()) {
            getIt.unregister<DomainLogger>();
          }
          getIt
            ..registerSingleton<SyncSequenceLogService>(mockSequenceLog)
            ..registerSingleton<DomainLogger>(mockDomainLogger);

          await stubBaseCreateFlow();
          when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
          when(
            () => mockOutbox.enqueueMessage(any()),
          ).thenThrow(StateError('outbox boom'));

          final result = await repository.createOrUpdateRating(
            targetId: testTimeEntryId,
            dimensions: testDimensions,
          );

          // The rating itself is still considered created — the outbox
          // failure must not propagate into the caller.
          expect(result, isA<RatingEntry>());
          verify(
            () => mockDomainLogger.error(
              LogDomain.sync,
              any<Object>(),
              message: any<String>(
                named: 'message',
                that: contains('outbox enqueue failed after _createRatingLink'),
              ),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: '_createRatingLink.enqueue',
            ),
          ).called(1);
        },
      );

      test(
        '_createRatingLink commitWhen returns false when upsert reports 0 '
        'rows so the reserved VC counter is released through the scope and '
        'no sync message is enqueued',
        () async {
          await stubBaseCreateFlow();
          when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 0);

          final result = await repository.createOrUpdateRating(
            targetId: testTimeEntryId,
            dimensions: testDimensions,
          );

          // Link upsert was a no-op → _createRatingLink returns early; the
          // rating itself is still considered created (the link row exists,
          // just not modified). Crucially, no outbox/notify side-effects fire
          // because the scope's commitWhen=false short-circuits them.
          expect(result, isA<RatingEntry>());
          verifyNever(() => mockOutbox.enqueueMessage(any()));
          verifyNever(() => mockNotifications.notify(any()));
        },
      );
    });
  });

  group('ratingRepository riverpod provider', () {
    test('provides a RatingRepository instance', () {
      // GetIt is already populated by the outer setUp with JournalDb +
      // PersistenceLogic mocks, so the provider can construct the repo
      // without registering anything new here.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(ratingRepositoryProvider);
      expect(repo, isA<RatingRepository>());
    });
  });
}
