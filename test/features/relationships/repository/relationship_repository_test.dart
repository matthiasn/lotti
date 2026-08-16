import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
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
  }) => RelationshipEntry(
    meta: meta(id, deletedAt: deletedAt),
    data: relationshipData(),
  );

  CheckInEntry checkInEntry(String id) => CheckInEntry(
    meta: meta(id),
    data: const CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
    ),
  );

  Task taskEntry(String id, {DateTime? dateFrom, DateTime? deletedAt}) {
    final date = dateFrom ?? testDate;
    return JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: date,
            updatedAt: date,
            dateFrom: date,
            dateTo: date,
            deletedAt: deletedAt,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'ts-$id',
              createdAt: date,
              utcOffset: 0,
            ),
            dateFrom: date,
            dateTo: date,
            statusHistory: const [],
            title: 'Task $id',
          ),
        )
        as Task;
  }

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
    test(
      'persists the update without emitting a manual notification — '
      'updateDbEntity already emits the entity affectedIds',
      () async {
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => true,
        );

        final result = await repository.updateRelationship(relationshipEntry());

        expect(result, isTrue);
        verifyNever(() => mockNotifications.notify(any()));
      },
    );

    test('returns false when the update is rejected', () async {
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => false,
      );

      expect(
        await repository.updateRelationship(relationshipEntry()),
        isFalse,
      );
    });

    test('returns false when the update throws and is swallowed', () async {
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => null,
      );

      expect(
        await repository.updateRelationship(relationshipEntry()),
        isFalse,
      );
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

      // The tombstones' own affectedIds carry the relationship id and
      // RELATIONSHIP/CHECK_IN, so no manual notification is needed.
      verifyNever(() => mockNotifications.notify(any()));
    });

    test(
      'returns false and skips the cascade when the relationship tombstone '
      'is rejected',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
          (_) async => [checkInEntry('check-1')],
        );
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => false,
        );

        expect(await repository.deleteRelationship('rel-001'), isFalse);

        // Only the relationship was attempted — reporting success here would
        // navigate the caller away from a person who is still there.
        final attempted = verify(
          () => mockPersistence.updateDbEntity(captureAny()),
        ).captured.cast<JournalEntity>();
        expect(attempted.map((entity) => entity.id), ['rel-001']);
      },
    );

    test(
      'returns false when the relationship tombstone throws and is swallowed',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(
          () => mockDb.getAllCheckInsForRelationship('rel-001'),
        ).thenAnswer((_) async => []);
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => null,
        );

        expect(await repository.deleteRelationship('rel-001'), isFalse);
      },
    );

    test(
      'still reports success when only a check-in tombstone is rejected — '
      'the person is already unreachable',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
          (_) async => [checkInEntry('check-1')],
        );
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as JournalEntity).id ==
              'rel-001',
        );

        final mockLogger = getIt<DomainLogger>() as MockDomainLogger;
        when(
          () => mockLogger.error(
            any(),
            any(),
            message: any(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        expect(await repository.deleteRelationship('rel-001'), isTrue);
        verify(() => mockPersistence.updateDbEntity(any())).called(2);
        verify(
          () => mockLogger.error(
            LogDomain.persistence,
            any(),
            message: 'orphaned check-in left behind by relationship cascade',
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'deleteRelationship',
          ),
        ).called(1);
      },
    );

    test(
      'cascades to private check-ins the display filter hides — a deletion '
      'must not be scoped by "Show private entries"',
      () async {
        when(
          () => mockDb.journalEntityById('rel-001'),
        ).thenAnswer((_) async => relationshipEntry());
        // Exactly what the two queries answer with private entries hidden:
        // the display query sees nothing, the cascade query sees the row.
        when(
          () => mockDb.getCheckInsForRelationship('rel-001'),
        ).thenAnswer((_) async => []);
        when(() => mockDb.getAllCheckInsForRelationship('rel-001')).thenAnswer(
          (_) async => [checkInEntry('private-check-1')],
        );
        when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
          (_) async => true,
        );

        expect(await repository.deleteRelationship('rel-001'), isTrue);

        final deleted = verify(
          () => mockPersistence.updateDbEntity(captureAny()),
        ).captured.cast<JournalEntity>();
        expect(
          deleted.map((entity) => entity.id).toSet(),
          {'rel-001', 'private-check-1'},
          reason:
              'a private check-in left live would keep syncing the deleted '
              "person's data with no relationship left to reach it from",
        );
        verifyNever(() => mockDb.getCheckInsForRelationship(any()));
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

    test('returns false when the tombstone throws and is swallowed', () async {
      when(
        () => mockDb.journalEntityById('check-1'),
      ).thenAnswer((_) async => checkInEntry('check-1'));
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => null,
      );

      expect(await repository.deleteCheckIn('check-1'), isFalse);
    });
  });

  group('getLinkedTasks', () {
    EntryLink relationshipLink(
      String id, {
      required String fromId,
      required String toId,
      DateTime? deletedAt,
      bool? hidden,
    }) => EntryLink.relationship(
      id: id,
      fromId: fromId,
      toId: toId,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      deletedAt: deletedAt,
      hidden: hidden,
    );

    test(
      'resolves both link directions, dedupes and orders newest task first',
      () async {
        final older = taskEntry('task-older', dateFrom: DateTime(2026, 8, 2));
        final newer = taskEntry('task-newer', dateFrom: DateTime(2026, 8, 9));
        when(
          () => mockDb.typedLinksForTaskIds(
            {'rel-001'},
            types: {'RelationshipLink'},
          ),
        ).thenAnswer(
          (_) async => [
            relationshipLink('l1', fromId: 'rel-001', toId: 'task-older'),
            // The reverse direction repeats `task-older`; it must not double up.
            relationshipLink('l2', fromId: 'task-older', toId: 'rel-001'),
            relationshipLink('l3', fromId: 'task-newer', toId: 'rel-001'),
          ],
        );
        when(
          () => mockDb.getLiveTasksByIds({'task-older', 'task-newer'}),
        ).thenAnswer((_) async => [older, newer]);

        final tasks = await repository.getLinkedTasks('rel-001');

        expect(tasks.map((task) => task.id), ['task-newer', 'task-older']);
      },
    );

    test('excludes link tombstones and hidden links', () async {
      when(
        () => mockDb.typedLinksForTaskIds(
          {'rel-001'},
          types: {'RelationshipLink'},
        ),
      ).thenAnswer(
        (_) async => [
          relationshipLink('l1', fromId: 'rel-001', toId: 'task-live'),
          relationshipLink(
            'l2',
            fromId: 'rel-001',
            toId: 'task-unlinked',
            deletedAt: testDate,
          ),
          relationshipLink(
            'l3',
            fromId: 'rel-001',
            toId: 'task-hidden',
            hidden: true,
          ),
        ],
      );
      when(() => mockDb.getLiveTasksByIds({'task-live'})).thenAnswer(
        (_) async => [taskEntry('task-live', dateFrom: testDate)],
      );

      final tasks = await repository.getLinkedTasks('rel-001');

      expect(tasks.map((task) => task.id), ['task-live']);
      // Nothing but the live endpoint is ever looked up.
      verify(() => mockDb.getLiveTasksByIds({'task-live'})).called(1);
    });

    test(
      'scopes the link query to RelationshipLink, so a task reachable only '
      'through another link type never renders an unlink that would fail',
      () async {
        when(
          () => mockDb.typedLinksForTaskIds(
            {'rel-001'},
            types: {'RelationshipLink'},
          ),
        ).thenAnswer((_) async => []);

        expect(await repository.getLinkedTasks('rel-001'), isEmpty);
        // No entity lookup at all when there is nothing linked.
        verifyNever(() => mockDb.getLiveTasksByIds(any()));
      },
    );
  });

  group('linkTask', () {
    test('writes a RelationshipLink from relationship to task', () async {
      when(
        () => mockPersistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.linkTask(
        relationshipId: 'rel-001',
        taskId: 'task-1',
      );

      expect(result, isTrue);
      verify(
        () => mockPersistence.createLink(
          fromId: 'rel-001',
          toId: 'task-1',
          linkType: EntryLinkType.relationship,
        ),
      ).called(1);
    });
  });

  group('unlinkTask', () {
    test(
      'removes the typed link in whichever direction it exists and '
      'notifies both endpoints',
      () async {
        when(
          () => mockDb.deleteTypedLink('rel-001', 'task-1', 'RelationshipLink'),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.deleteTypedLink('task-1', 'rel-001', 'RelationshipLink'),
        ).thenAnswer((_) async => 0);

        final result = await repository.unlinkTask(
          relationshipId: 'rel-001',
          taskId: 'task-1',
        );

        expect(result, isTrue);
        verify(
          () => mockNotifications.notify(
            {'rel-001', 'task-1', linkNotification},
          ),
        ).called(1);
      },
    );

    test('returns false and stays silent when no link exists', () async {
      when(
        () => mockDb.deleteTypedLink(any(), any(), any()),
      ).thenAnswer((_) async => 0);

      final result = await repository.unlinkTask(
        relationshipId: 'rel-001',
        taskId: 'task-1',
      );

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
    });
  });
}
