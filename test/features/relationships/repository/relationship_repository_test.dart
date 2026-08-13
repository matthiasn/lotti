import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/services/db_notification.dart';
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

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockNotifications = MockUpdateNotifications();
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
      when(() => mockDb.getCheckInsForRelationship('rel-001')).thenAnswer(
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
}
