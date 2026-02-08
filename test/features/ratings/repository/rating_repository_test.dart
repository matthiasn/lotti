import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
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
  late MockLoggingService mockLogging;

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
      timeEntryId: testTimeEntryId,
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
    mockLogging = MockLoggingService();

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistence)
      ..registerSingleton<VectorClockService>(mockVectorClock)
      ..registerSingleton<UpdateNotifications>(mockNotifications)
      ..registerSingleton<OutboxService>(mockOutbox)
      ..registerSingleton<LoggingService>(mockLogging);

    repository = RatingRepository();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('RatingRepository', () {
    group('getRatingForTimeEntry', () {
      test('delegates to JournalDb', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => testRatingEntry);

        final result = await repository.getRatingForTimeEntry(testTimeEntryId);

        expect(result, equals(testRatingEntry));
        verify(() => mockDb.getRatingForTimeEntry(testTimeEntryId)).called(1);
      });

      test('returns null when no rating exists', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => null);

        final result = await repository.getRatingForTimeEntry(testTimeEntryId);

        expect(result, isNull);
      });
    });

    group('createOrUpdateRating', () {
      test('creates new rating when none exists', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(() => mockVectorClock.getNextVectorClock())
            .thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
          dimensions: testDimensions,
          note: 'Test note',
        );

        expect(result, isA<RatingEntry>());
        expect(result!.data.timeEntryId, equals(testTimeEntryId));
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

        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => testRatingEntry);
        when(() => mockPersistence.updateMetadata(testMetadata))
            .thenAnswer((_) async => updatedMeta);
        when(() => mockPersistence.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        const newDimensions = [
          RatingDimension(key: 'productivity', value: 0.9),
          RatingDimension(key: 'energy', value: 0.7),
          RatingDimension(key: 'focus', value: 1),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ];

        final result = await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
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
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(() => mockVectorClock.getNextVectorClock())
            .thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        final result = await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
          dimensions: testDimensions,
        );

        expect(result, isA<RatingEntry>());
        expect(result!.data.note, isNull);
      });

      test('returns null and logs on exception', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenThrow(Exception('DB error'));
        when(
          () => mockLogging.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final result = await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
          dimensions: testDimensions,
        );

        expect(result, isNull);
        verify(
          () => mockLogging.captureException(
            any<dynamic>(),
            domain: 'RatingRepository',
            subDomain: 'createOrUpdateRating',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('link creation', () {
      test('creates RatingLink with correct from/to IDs', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(() => mockVectorClock.getNextVectorClock())
            .thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
          dimensions: testDimensions,
        );

        // Verify the link has correct structure
        final captured = verify(() => mockDb.upsertEntryLink(captureAny()))
            .captured
            .single as EntryLink;

        expect(captured, isA<RatingLink>());
        final ratingLink = captured as RatingLink;
        expect(ratingLink.fromId, equals(testMetadata.id));
        expect(ratingLink.toId, equals(testTimeEntryId));
        expect(ratingLink.hidden, isFalse);
      });

      test('enqueues sync message for link', () async {
        when(() => mockDb.getRatingForTimeEntry(testTimeEntryId))
            .thenAnswer((_) async => null);
        when(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistence.createDbEntity(
            any(),
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);
        when(() => mockVectorClock.getNextVectorClock())
            .thenAnswer((_) async => testVectorClock);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(() => mockOutbox.enqueueMessage(any())).thenAnswer((_) async {});

        await repository.createOrUpdateRating(
          timeEntryId: testTimeEntryId,
          dimensions: testDimensions,
        );

        final captured = verify(() => mockOutbox.enqueueMessage(captureAny()))
            .captured
            .single as SyncMessage;

        expect(captured, isA<SyncEntryLink>());
        final syncLink = captured as SyncEntryLink;
        expect(syncLink.entryLink, isA<RatingLink>());
        expect(syncLink.status, equals(SyncEntryStatus.initial));
      });
    });
  });
}
