import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistence;
  late MockUpdateNotifications mockNotifications;
  late RelationshipRepository repository;

  Metadata meta(String id, {DateTime? deletedAt}) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: 'cat-1',
    deletedAt: deletedAt,
  );

  RelationshipData relationshipData({String title = 'Anna Example'}) =>
      RelationshipData(
        title: title,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 60,
        ),
      );

  RelationshipEntry relationshipEntry({
    String id = 'rel-001',
    DateTime? deletedAt,
    bool? private,
  }) => RelationshipEntry(
    meta: meta(id, deletedAt: deletedAt).copyWith(private: private),
    data: relationshipData(),
  );

  CheckInEntry checkInEntry(String id) => CheckInEntry(
    meta: meta(id),
    data: const CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
    ),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockNotifications = MockUpdateNotifications();
    getIt.registerSingleton<DomainLogger>(MockDomainLogger());
    repository = RelationshipRepository(
      journalDb: mockDb,
      persistenceLogic: mockPersistence,
      updateNotifications: mockNotifications,
    );

    // Private entries are hidden unless a test says otherwise; the flag is
    // only read for entities that actually carry `meta.private`.
    when(
      () => mockDb.getConfigFlag(privateFlag),
    ).thenAnswer((_) async => false);
    when(
      () => mockPersistence.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (invocation) async => Metadata(
        id: 'generated-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: invocation.namedArguments[#dateFrom] as DateTime? ?? testDate,
        dateTo: invocation.namedArguments[#dateTo] as DateTime? ?? testDate,
        categoryId: invocation.namedArguments[#categoryId] as String?,
      ),
    );
    when(
      () => mockPersistence.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    ).thenAnswer(
      (invocation) async => Metadata(
        id: 'generated-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: invocation.namedArguments[#dateFrom] as DateTime? ?? testDate,
        dateTo: invocation.namedArguments[#dateTo] as DateTime? ?? testDate,
        categoryId: invocation.namedArguments[#categoryId] as String?,
        private: invocation.namedArguments[#private] as bool?,
      ),
    );
    when(
      () => mockPersistence.updateMetadata(
        any(),
        deletedAt: any(named: 'deletedAt'),
      ),
    ).thenAnswer((invocation) async {
      final original = invocation.positionalArguments.first as Metadata;
      final deletedAt = invocation.namedArguments[#deletedAt] as DateTime?;
      return original.copyWith(
        updatedAt: testDate.add(const Duration(minutes: 1)),
        deletedAt: deletedAt ?? original.deletedAt,
      );
    });
    when(() => mockNotifications.notify(any())).thenReturn(null);
  });

  tearDown(() async {
    await getIt.unregister<DomainLogger>();
  });

  group('createRelationship', () {
    test('persists a RelationshipEntry and returns it', () async {
      when(() => mockPersistence.createDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final result = await repository.createRelationship(
        data: relationshipData(),
        entryText: const EntryText(plainText: 'met at university'),
        categoryId: 'cat-1',
        trackingStartedAt: testDate,
      );

      expect(result, isNotNull);
      expect(result!.data.title, 'Anna Example');
      expect(result.meta.dateFrom, testDate);
      expect(result.entryText?.plainText, 'met at university');

      final captured =
          verify(
                () => mockPersistence.createDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(captured, isA<RelationshipEntry>());
    });

    test('returns null when persistence fails', () async {
      when(() => mockPersistence.createDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      final result = await repository.createRelationship(
        data: relationshipData(),
        trackingStartedAt: testDate,
      );

      expect(result, isNull);
    });

    test(
      'starts tracking now when no explicit start is given — the add-person '
      'form never passes one',
      () async {
        when(() => mockPersistence.createDbEntity(any())).thenAnswer(
          (_) async => true,
        );
        final before = DateTime.now();

        final result = await repository.createRelationship(
          data: relationshipData(),
        );

        expect(result, isNotNull);
        final captured = verify(
          () => mockPersistence.createMetadata(
            dateFrom: captureAny(named: 'dateFrom'),
            dateTo: captureAny(named: 'dateTo'),
            categoryId: captureAny(named: 'categoryId'),
          ),
        ).captured;
        final dateFrom = captured[0] as DateTime;
        expect(
          dateFrom.isBefore(before),
          isFalse,
          reason: 'tracking starts at wall-clock now',
        );
        // dateFrom and dateTo are the same instant, not two `now()` reads.
        expect(captured[1], dateFrom);
      },
    );
  });

  group('createCheckIn', () {
    const checkInData = CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
    );

    test(
      'persists a CheckInEntry and links it with a RelationshipLink',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockPersistence.createDbEntity(any())).thenAnswer(
          (_) async => true,
        );
        when(
          () => mockPersistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenAnswer((_) async => true);

        final result = await repository.createCheckIn(
          data: checkInData,
          entryText: const EntryText(plainText: 'talked about the interview'),
          dateFrom: testDate,
        );

        expect(result, isNotNull);
        expect(result!.data.sentiment, CheckInSentiment.good);
        // Category is inherited from the relationship.
        expect(result.meta.categoryId, 'cat-1');

        verify(
          () => mockPersistence.createLink(
            fromId: 'rel-001',
            toId: result.id,
            linkType: EntryLinkType.relationship,
          ),
        ).called(1);
      },
    );

    test(
      'inherits the relationship private flag, so a note about a hidden '
      'person is not persisted as a public row',
      () async {
        when(() => mockDb.journalEntityById('rel-001')).thenAnswer(
          (_) async => relationshipEntry(private: true),
        );
        when(() => mockDb.getConfigFlag(privateFlag)).thenAnswer(
          (_) async => true,
        );
        when(() => mockPersistence.createDbEntity(any())).thenAnswer(
          (_) async => true,
        );
        when(
          () => mockPersistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenAnswer((_) async => true);

        final result = await repository.createCheckIn(data: checkInData);

        expect(result, isNotNull);
        expect(result!.meta.private, isTrue);
        verify(
          () => mockPersistence.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            private: true,
          ),
        ).called(1);
      },
    );

    test('returns null when the relationship does not exist', () async {
      when(
        () => mockDb.journalEntityById('rel-001'),
      ).thenAnswer((_) async => null);

      final result = await repository.createCheckIn(data: checkInData);

      expect(result, isNull);
      verifyNever(() => mockPersistence.createDbEntity(any()));
    });

    test('returns null when the relationship is soft-deleted', () async {
      when(() => mockDb.journalEntityById('rel-001')).thenAnswer(
        (_) async => relationshipEntry(deletedAt: testDate),
      );

      final result = await repository.createCheckIn(data: checkInData);

      expect(result, isNull);
      verifyNever(() => mockPersistence.createDbEntity(any()));
    });

    test(
      'still returns the check-in when only the link write fails — the '
      'entity is already persisted, so a retry would duplicate it',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockPersistence.createDbEntity(any())).thenAnswer(
          (_) async => true,
        );
        when(
          () => mockPersistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenThrow(Exception('link table locked'));

        final result = await repository.createCheckIn(data: checkInData);

        expect(result, isNotNull);
      },
    );

    test('returns null and creates no link when persistence fails', () async {
      when(
        () => mockDb.journalEntityById('rel-001'),
      ).thenAnswer((_) async => relationshipEntry());
      when(() => mockPersistence.createDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      final result = await repository.createCheckIn(data: checkInData);

      expect(result, isNull);
      verifyNever(
        () => mockPersistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      );
    });
  });

  group('updateRelationship', () {
    test('persists the update and emits the entity notification', () async {
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final result = await repository.updateRelationship(relationshipEntry());

      expect(result, isTrue);
      verify(
        () => mockNotifications.notify(
          {relationshipEntityUpdateNotification('rel-001')},
        ),
      ).called(1);
    });

    test('returns false and stays silent when the update fails', () async {
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      final result = await repository.updateRelationship(relationshipEntry());

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
    });
  });

  group('deleteRelationship', () {
    test('returns false when the relationship does not exist', () async {
      when(
        () => mockDb.journalEntityById('rel-404'),
      ).thenAnswer((_) async => null);

      expect(await repository.deleteRelationship('rel-404'), isFalse);
      verifyNever(() => mockPersistence.updateDbEntity(any()));
    });

    test('soft-deletes the relationship and cascades to check-ins', () async {
      when(
        () => mockDb.journalEntityById('rel-001'),
      ).thenAnswer((_) async => relationshipEntry());
      when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
        (_) async => [checkInEntry('check-1'), checkInEntry('check-2')],
      );
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final result = await repository.deleteRelationship('rel-001');

      expect(result, isTrue);

      final deleted = verify(
        () => mockPersistence.updateDbEntity(captureAny()),
      ).captured.cast<JournalEntity>();
      expect(deleted, hasLength(3));
      expect(
        deleted.map((entity) => entity.id).toSet(),
        {'check-1', 'check-2', 'rel-001'},
      );
      for (final entity in deleted) {
        expect(
          entity.meta.deletedAt,
          isNotNull,
          reason: '${entity.id} must be soft-deleted',
        );
      }

      verify(
        () => mockNotifications.notify({
          relationshipNotification,
          relationshipEntityUpdateNotification('rel-001'),
        }),
      ).called(1);
    });

    test(
      'cascades over the unfiltered check-in query, so private check-ins '
      'cannot survive the person they describe',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
          (_) async => [checkInEntry('private-check-in')],
        );
        // The browsing query hides private check-ins while private mode is
        // off; reading it here would tombstone the person and orphan them.
        when(
          () => mockDb.getCheckInsForRelationship('rel-001'),
        ).thenAnswer((_) async => []);
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => true,
        );

        expect(await repository.deleteRelationship('rel-001'), isTrue);

        final deleted = verify(
          () => mockPersistence.updateDbEntity(captureAny()),
        ).captured.cast<JournalEntity>();
        expect(deleted.map((entity) => entity.id), [
          'private-check-in',
          'rel-001',
        ]);
        verifyNever(() => mockDb.getCheckInsForRelationship(any()));
      },
    );

    test(
      'reports failure and leaves the person live when a check-in tombstone '
      'is rejected',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
          (_) async => [checkInEntry('check-1'), checkInEntry('check-2')],
        );
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as JournalEntity).id !=
              'check-2',
        );

        expect(await repository.deleteRelationship('rel-001'), isFalse);

        final attempted = verify(
          () => mockPersistence.updateDbEntity(captureAny()),
        ).captured.cast<JournalEntity>().map((entity) => entity.id);
        // Both check-ins are attempted, the relationship is not: a person
        // must never be tombstoned over a surviving check-in.
        expect(attempted, ['check-1', 'check-2']);

        // The successful check-in tombstone still changed rows, so the views
        // are told to reload.
        verify(
          () => mockNotifications.notify({
            relationshipNotification,
            relationshipEntityUpdateNotification('rel-001'),
          }),
        ).called(1);
      },
    );

    test(
      'reports failure when the relationship tombstone is rejected',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(
          () => mockDb.getAllCheckInsForRelationship('rel-001'),
        ).thenAnswer((_) async => []);
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => false,
        );

        expect(await repository.deleteRelationship('rel-001'), isFalse);
      },
    );
  });

  group('getRelationshipById', () {
    test('returns the relationship when the id resolves to one', () async {
      when(
        () => mockDb.journalEntityById('rel-001'),
      ).thenAnswer((_) async => relationshipEntry());

      final result = await repository.getRelationshipById('rel-001');

      expect(result, isNotNull);
      expect(result!.data.title, 'Anna Example');
    });

    test('returns null when the id resolves to another type', () async {
      when(() => mockDb.journalEntityById('task-1')).thenAnswer(
        (_) async => JournalEntity.task(
          meta: meta('task-1'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'ts-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: const [],
            title: 'not a relationship',
          ),
        ),
      );

      expect(await repository.getRelationshipById('task-1'), isNull);
    });

    test(
      'hides a private relationship while private entries are hidden — a '
      'direct /people/<id> route must not leak past the list filter',
      () async {
        when(() => mockDb.journalEntityById('rel-secret')).thenAnswer(
          (_) async => relationshipEntry(id: 'rel-secret', private: true),
        );

        expect(await repository.getRelationshipById('rel-secret'), isNull);
        verify(() => mockDb.getConfigFlag(privateFlag)).called(1);
      },
    );

    test('returns a private relationship once private mode is on', () async {
      when(() => mockDb.journalEntityById('rel-secret')).thenAnswer(
        (_) async => relationshipEntry(id: 'rel-secret', private: true),
      );
      when(() => mockDb.getConfigFlag(privateFlag)).thenAnswer(
        (_) async => true,
      );

      final result = await repository.getRelationshipById('rel-secret');

      expect(result, isNotNull);
      expect(result!.id, 'rel-secret');
    });

    test(
      'does not consult the private flag for a public relationship',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());

        expect(await repository.getRelationshipById('rel-001'), isNotNull);
        verifyNever(() => mockDb.getConfigFlag(any()));
      },
    );
  });

  group('getCheckInsForRelationship', () {
    test('delegates to the private-filtered browsing query', () async {
      when(() => mockDb.getCheckInsForRelationship('rel-001')).thenAnswer(
        (_) async => [checkInEntry('check-1'), checkInEntry('check-2')],
      );

      final checkIns = await repository.getCheckInsForRelationship('rel-001');

      expect(checkIns.map((c) => c.id), ['check-1', 'check-2']);
      // Explicitly the filtered query — the unfiltered one is cascade-only.
      verifyNever(() => mockDb.getAllCheckInsForRelationship(any()));
    });
  });

  group('relationshipRepositoryProvider', () {
    test('wires the repository from the registered singletons', () async {
      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<PersistenceLogic>(mockPersistence)
        ..registerSingleton<UpdateNotifications>(mockNotifications);
      addTearDown(() async {
        await getIt.unregister<JournalDb>();
        await getIt.unregister<PersistenceLogic>();
        await getIt.unregister<UpdateNotifications>();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wired = container.read(relationshipRepositoryProvider);

      // Reaching the injected JournalDb proves the wiring, not just that a
      // repository object came back.
      when(
        () => mockDb.journalEntityById('rel-001'),
      ).thenAnswer((_) async => relationshipEntry());
      expect((await wired.getRelationshipById('rel-001'))?.id, 'rel-001');
    });
  });

  group('getRelationshipsByRecency', () {
    RelationshipEntry trackedSince(String id, DateTime dateFrom) =>
        RelationshipEntry(
          meta: Metadata(
            id: id,
            createdAt: dateFrom,
            updatedAt: dateFrom,
            dateFrom: dateFrom,
            dateTo: dateFrom,
          ),
          data: relationshipData(),
        );

    test(
      'orders by last check-in, falling back to tracking start',
      () async {
        // Tracking starts: anna (oldest) < ben < cara (newest).
        final anna = trackedSince('anna', DateTime(2026, 8, 1, 9));
        final ben = trackedSince('ben', DateTime(2026, 8, 5));
        final cara = trackedSince('cara', DateTime(2026, 8, 10));
        when(
          () => mockDb.getRelationships(),
        ).thenAnswer((_) async => [cara, ben, anna]);
        // Anna was checked in on yesterday — she outranks everyone; Ben's
        // last check-in predates Cara's tracking start.
        when(() => mockDb.latestCheckInTimes()).thenAnswer(
          (_) async => {
            'anna': DateTime(2026, 8, 12),
            'ben': DateTime(2026, 8, 7),
          },
        );

        final items = await repository.getRelationshipsByRecency();

        expect(
          items.map((item) => item.relationship.id),
          ['anna', 'cara', 'ben'],
        );
        expect(items.first.lastCheckInAt, DateTime(2026, 8, 12));
        // Cara has no check-in: recency is her tracking start.
        expect(items[1].lastCheckInAt, isNull);
      },
    );
  });

  group('updateCheckIn', () {
    test(
      'bumps metadata, persists, and keeps the edited interaction time',
      () async {
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => true,
        );
        final editedTime = DateTime(2026, 8, 9, 18);
        final edited = checkInEntry('check-1').copyWith(
          meta: meta('check-1').copyWith(
            dateFrom: editedTime,
            dateTo: editedTime,
          ),
        );

        expect(await repository.updateCheckIn(edited), isTrue);

        final persisted =
            verify(
                  () => mockPersistence.updateDbEntity(captureAny()),
                ).captured.single
                as CheckInEntry;
        expect(persisted.meta.dateFrom, editedTime);
        expect(persisted.meta.dateTo, editedTime);
        // updateMetadata ran: the clock-bump stub advances updatedAt.
        expect(persisted.meta.updatedAt, isNot(edited.meta.updatedAt));
      },
    );

    test('returns false when persistence fails', () async {
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      expect(await repository.updateCheckIn(checkInEntry('check-1')), isFalse);
    });
  });

  group('deleteCheckIn', () {
    test('soft-deletes a live check-in', () async {
      when(
        () => mockDb.journalEntityById('check-1'),
      ).thenAnswer((_) async => checkInEntry('check-1'));
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      expect(await repository.deleteCheckIn('check-1'), isTrue);

      final persisted =
          verify(
                () => mockPersistence.updateDbEntity(captureAny()),
              ).captured.single
              as CheckInEntry;
      expect(persisted.meta.deletedAt, isNotNull);
    });

    test(
      'returns false for a missing id, a foreign type, or a tombstone',
      () async {
        when(
          () => mockDb.journalEntityById('check-404'),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        final tombstone = checkInEntry('check-gone').copyWith(
          meta: meta('check-gone', deletedAt: testDate),
        );
        when(
          () => mockDb.journalEntityById('check-gone'),
        ).thenAnswer((_) async => tombstone);

        expect(await repository.deleteCheckIn('check-404'), isFalse);
        expect(await repository.deleteCheckIn('rel-001'), isFalse);
        expect(await repository.deleteCheckIn('check-gone'), isFalse);
        verifyNever(() => mockPersistence.updateDbEntity(any()));
      },
    );

    test('returns false when the tombstone write is rejected', () async {
      when(
        () => mockDb.journalEntityById('check-1'),
      ).thenAnswer((_) async => checkInEntry('check-1'));
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      expect(await repository.deleteCheckIn('check-1'), isFalse);
    });
  });
}
