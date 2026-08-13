import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  final baseTime = DateTime(2026, 8, 1, 12);

  Metadata meta(
    String id, {
    required DateTime dateFrom,
    bool private = false,
    DateTime? deletedAt,
  }) => Metadata(
    id: id,
    createdAt: dateFrom,
    updatedAt: dateFrom,
    dateFrom: dateFrom,
    dateTo: dateFrom,
    private: private,
    deletedAt: deletedAt,
  );

  JournalEntity relationship(
    String id, {
    required DateTime trackedSince,
    bool private = false,
    DateTime? deletedAt,
  }) => JournalEntity.relationship(
    meta: meta(
      id,
      dateFrom: trackedSince,
      private: private,
      deletedAt: deletedAt,
    ),
    data: RelationshipData(
      title: 'Person $id',
      status: RelationshipStatus.active(
        id: 'status-$id',
        createdAt: trackedSince,
        utcOffset: 0,
      ),
    ),
  );

  JournalEntity checkIn(
    String id, {
    required String relationshipId,
    required DateTime at,
    bool private = false,
    DateTime? deletedAt,
  }) => JournalEntity.checkIn(
    meta: meta(id, dateFrom: at, private: private, deletedAt: deletedAt),
    data: CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.call,
    ),
  );

  group('JournalDb relationship queries -', () {
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
    });

    test(
      'getRelationships returns non-deleted relationships newest first, '
      'ignoring other entity types',
      () async {
        await db!.updateJournalEntity(
          relationship('rel-older', trackedSince: baseTime),
        );
        await db!.updateJournalEntity(
          relationship(
            'rel-newer',
            trackedSince: baseTime.add(const Duration(days: 2)),
          ),
        );
        await db!.updateJournalEntity(
          relationship(
            'rel-deleted',
            trackedSince: baseTime.add(const Duration(days: 3)),
            deletedAt: baseTime.add(const Duration(days: 4)),
          ),
        );
        // A check-in must never appear in the relationship list.
        await db!.updateJournalEntity(
          checkIn('check-1', relationshipId: 'rel-older', at: baseTime),
        );

        final relationships = await db!.getRelationships();

        expect(
          relationships.map((r) => r.id).toList(),
          ['rel-newer', 'rel-older'],
        );
      },
    );

    test(
      "getCheckInsForRelationship returns only that relationship's live "
      'check-ins, newest first',
      () async {
        await db!.updateJournalEntity(
          checkIn('check-old', relationshipId: 'rel-a', at: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-new',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 1)),
          ),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-deleted',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 2)),
            deletedAt: baseTime.add(const Duration(days: 3)),
          ),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-other-rel',
            relationshipId: 'rel-b',
            at: baseTime,
          ),
        );

        final checkIns = await db!.getCheckInsForRelationship('rel-a');

        expect(
          checkIns.map((c) => c.id).toList(),
          ['check-new', 'check-old'],
        );
        expect(
          checkIns.every((c) => c.data.relationshipId == 'rel-a'),
          isTrue,
        );
      },
    );

    test(
      'private relationships and check-ins are hidden when the private flag '
      'is off and visible when it is on',
      () async {
        await db!.updateJournalEntity(
          relationship('rel-public', trackedSince: baseTime),
        );
        await db!.updateJournalEntity(
          relationship(
            'rel-private',
            trackedSince: baseTime.add(const Duration(days: 1)),
            private: true,
          ),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-private',
            relationshipId: 'rel-public',
            at: baseTime,
            private: true,
          ),
        );

        Future<void> setPrivateFlag({required bool status}) =>
            db!.upsertConfigFlag(
              ConfigFlag(
                name: privateFlag,
                description: 'Show private entries?',
                status: status,
              ),
            );

        await setPrivateFlag(status: false);
        expect(
          (await db!.getRelationships()).map((r) => r.id),
          ['rel-public'],
        );
        expect(await db!.getCheckInsForRelationship('rel-public'), isEmpty);

        await setPrivateFlag(status: true);
        expect(
          (await db!.getRelationships()).map((r) => r.id),
          ['rel-private', 'rel-public'],
        );
        expect(
          (await db!.getCheckInsForRelationship('rel-public')).map((c) => c.id),
          ['check-private'],
        );
      },
    );
  });
}
