import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
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
    CheckInInteractionType interactionType = CheckInInteractionType.call,
    Duration length = Duration.zero,
  }) => JournalEntity.checkIn(
    meta: meta(
      id,
      dateFrom: at,
      private: private,
      deletedAt: deletedAt,
    ).copyWith(dateTo: at.add(length)),
    data: CheckInData(
      relationshipId: relationshipId,
      interactionType: interactionType,
    ),
  );

  JournalEntity task(
    String id, {
    required DateTime at,
    bool private = false,
    DateTime? deletedAt,
  }) => JournalEntity.task(
    meta: meta(id, dateFrom: at, private: private, deletedAt: deletedAt),
    data: TaskData(
      title: 'Task $id',
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: at,
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: at,
      dateTo: at,
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

    test(
      'getAllCheckInsForRelationship ignores the private filter — the delete '
      'cascade must reach every check-in',
      () async {
        await db!.updateJournalEntity(
          relationship('rel-a', trackedSince: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn('check-public', relationshipId: 'rel-a', at: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-private',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(hours: 1)),
            private: true,
          ),
        );
        await db!.updateJournalEntity(
          checkIn(
            'check-deleted',
            relationshipId: 'rel-a',
            at: baseTime,
            deletedAt: baseTime,
          ),
        );
        await db!.updateJournalEntity(
          checkIn('check-other-rel', relationshipId: 'rel-b', at: baseTime),
        );
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: false,
          ),
        );

        // The display query is scoped by the flag…
        expect(
          (await db!.getCheckInsForRelationship('rel-a')).map((c) => c.id),
          ['check-public'],
        );
        // …the cascade query is not, but still skips tombstones. Other
        // people's check-ins stay out of both.
        expect(
          (await db!.getAllCheckInsForRelationship('rel-a')).map((c) => c.id),
          ['check-private', 'check-public'],
        );
      },
    );

    test(
      'latestCheckIns resolves the newest live check-in row per relationship '
      'in one further query and respects the private filter',
      () async {
        await db!.updateJournalEntity(
          checkIn('a-old', relationshipId: 'rel-a', at: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn(
            'a-new',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 2)),
          ),
        );
        // A deleted newer row must not shadow the live one.
        await db!.updateJournalEntity(
          checkIn(
            'a-deleted',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 5)),
            deletedAt: baseTime.add(const Duration(days: 6)),
          ),
        );
        // rel-b's newest is private; its older one is public — with private
        // entries hidden the OLDER public row is the newest visible one.
        await db!.updateJournalEntity(
          checkIn('b-public', relationshipId: 'rel-b', at: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn(
            'b-private',
            relationshipId: 'rel-b',
            at: baseTime.add(const Duration(days: 1)),
            private: true,
          ),
        );
        // The same instant as a-new on ANOTHER person: the pair must be
        // matched, not only the instant.
        await db!.updateJournalEntity(
          checkIn(
            'c-same-instant',
            relationshipId: 'rel-c',
            at: baseTime.add(const Duration(days: 2)),
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

        await setPrivateFlag(status: true);
        final shown = await db!.latestCheckIns();
        expect(
          shown.map((id, entry) => MapEntry(id, entry.meta.id)),
          {'rel-a': 'a-new', 'rel-b': 'b-private', 'rel-c': 'c-same-instant'},
        );
        expect(shown['rel-a']!.data.relationshipId, 'rel-a');

        await setPrivateFlag(status: false);
        final hidden = await db!.latestCheckIns();
        expect(
          hidden.map((id, entry) => MapEntry(id, entry.meta.id)),
          {'rel-a': 'a-new', 'rel-b': 'b-public', 'rel-c': 'c-same-instant'},
        );
      },
    );

    test(
      'latestCheckIns breaks a same-instant tie by id, so the interaction a '
      'People row shows does not change between loads',
      () async {
        final at = baseTime.add(const Duration(days: 3));
        // The message is inserted first so that natural (insertion) order
        // and id order disagree — only a deterministic ORDER BY picks the
        // call both times.
        await db!.updateJournalEntity(
          checkIn(
            'd-2-message',
            relationshipId: 'rel-d',
            at: at,
            interactionType: CheckInInteractionType.message,
          ),
        );
        await db!.updateJournalEntity(
          checkIn('d-1-call', relationshipId: 'rel-d', at: at),
        );

        final first = await db!.latestCheckIns();
        final again = await db!.latestCheckIns();

        expect(first['rel-d']!.meta.id, 'd-1-call');
        expect(
          first['rel-d']!.data.interactionType,
          CheckInInteractionType.call,
        );
        expect(again['rel-d']!.meta.id, 'd-1-call');
      },
    );

    test(
      'latestCheckInTimes aggregates the newest live check-in per '
      'relationship and respects the private filter',
      () async {
        await db!.updateJournalEntity(
          checkIn('a-old', relationshipId: 'rel-a', at: baseTime),
        );
        await db!.updateJournalEntity(
          checkIn(
            'a-new',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 2)),
          ),
        );
        // Deleted check-ins never count toward recency.
        await db!.updateJournalEntity(
          checkIn(
            'a-deleted',
            relationshipId: 'rel-a',
            at: baseTime.add(const Duration(days: 5)),
            deletedAt: baseTime.add(const Duration(days: 6)),
          ),
        );
        // rel-b's only check-in is private.
        await db!.updateJournalEntity(
          checkIn(
            'b-private',
            relationshipId: 'rel-b',
            at: baseTime.add(const Duration(days: 1)),
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

        await setPrivateFlag(status: true);
        expect(await db!.latestCheckInTimes(), {
          'rel-a': baseTime.add(const Duration(days: 2)),
          'rel-b': baseTime.add(const Duration(days: 1)),
        });

        // With private entries hidden, rel-b's recency must not leak.
        await setPrivateFlag(status: false);
        expect(await db!.latestCheckInTimes(), {
          'rel-a': baseTime.add(const Duration(days: 2)),
        });
      },
    );

    test(
      'getLiveTasksByIds keeps only live tasks — a check-in sharing the '
      'RelationshipLink type is filtered out by the type column',
      () async {
        await db!.updateJournalEntity(
          task('task-live', at: baseTime),
        );
        await db!.updateJournalEntity(
          task(
            'task-deleted',
            at: baseTime,
            deletedAt: baseTime.add(const Duration(days: 1)),
          ),
        );
        // Bound to the same relationship by the same link type.
        await db!.updateJournalEntity(
          checkIn('check-1', relationshipId: 'rel-a', at: baseTime),
        );
        await db!.updateJournalEntity(
          relationship('rel-a', trackedSince: baseTime),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(task('task-without-marker', at: baseTime)).copyWith(
            task: false,
          ),
        );

        final tasks = await db!.getLiveTasksByIds({
          'task-live',
          'task-deleted',
          'task-without-marker',
          'check-1',
          'rel-a',
          'never-existed',
        });

        expect(tasks.map((t) => t.id), ['task-live']);
      },
    );

    group('getRankedCheckInDurations -', () {
      Future<void> seed(
        String id, {
        required Duration length,
        DateTime? at,
        bool private = false,
        DateTime? deletedAt,
      }) => db!.updateJournalEntity(
        checkIn(
          id,
          relationshipId: 'rel-a',
          at: at ?? baseTime,
          length: length,
          private: private,
          deletedAt: deletedAt,
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

      test('ranks the lengths this user logs by use, ties shortest first, and '
          'ignores zero-length check-ins', () async {
        await seed('a', length: const Duration(minutes: 30));
        await seed('b', length: const Duration(minutes: 30));
        await seed('c', length: const Duration(minutes: 10));
        await seed('d', length: const Duration(minutes: 45));
        await seed('e', length: Duration.zero);
        await setPrivateFlag(status: true);

        expect(
          await db!.getRankedCheckInDurations(
            since: baseTime.subtract(const Duration(days: 1)),
            limit: 10,
          ),
          const [
            Duration(minutes: 30),
            Duration(minutes: 10),
            Duration(minutes: 45),
          ],
        );
      });

      test(
        'honours the window, the limit, deletion and the private filter',
        () async {
          await seed(
            'old',
            length: const Duration(minutes: 5),
            at: baseTime.subtract(const Duration(days: 100)),
          );
          await seed(
            'gone',
            length: const Duration(minutes: 15),
            deletedAt: baseTime,
          );
          await seed(
            'hidden',
            length: const Duration(minutes: 20),
            private: true,
          );
          await seed('x', length: const Duration(minutes: 30));
          await seed('y', length: const Duration(minutes: 60));
          await setPrivateFlag(status: false);

          expect(
            await db!.getRankedCheckInDurations(
              since: baseTime.subtract(const Duration(days: 90)),
              limit: 1,
            ),
            const [Duration(minutes: 30)],
          );
          expect(
            await db!.getRankedCheckInDurations(
              since: baseTime.subtract(const Duration(days: 90)),
              limit: 10,
            ),
            const [Duration(minutes: 30), Duration(minutes: 60)],
            reason: 'the old, the deleted and the hidden one never rank',
          );
          expect(
            await db!.getRankedCheckInDurations(since: baseTime, limit: 0),
            isEmpty,
          );
        },
      );
    });

    test('getLiveTasksByIds honours the private-entry filter', () async {
      await db!.updateJournalEntity(task('task-open', at: baseTime));
      await db!.updateJournalEntity(
        task('task-private', at: baseTime, private: true),
      );

      Future<void> setPrivateFlag({required bool status}) =>
          db!.upsertConfigFlag(
            ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: status,
            ),
          );

      await setPrivateFlag(status: true);
      expect(
        (await db!.getLiveTasksByIds({
          'task-open',
          'task-private',
        })).map((t) => t.id).toSet(),
        {'task-open', 'task-private'},
      );

      await setPrivateFlag(status: false);
      expect(
        (await db!.getLiveTasksByIds({
          'task-open',
          'task-private',
        })).map((t) => t.id),
        ['task-open'],
      );
    });

    test('getLiveTasksByIds short-circuits on an empty id set', () async {
      expect(await db!.getLiveTasksByIds(const {}), isEmpty);
    });
  });
}
