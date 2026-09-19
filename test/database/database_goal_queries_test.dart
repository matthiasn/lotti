import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
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

  const criteria = GoalCriterion.habit(
    criterionId: 'waddle-daily',
    habitId: 'habit-waddle',
    targetCount: 5,
    window: GoalWindow.rollingDays(count: 7),
  );

  JournalEntity goal(
    String id, {
    required DateTime at,
    String? snapshotOf,
    int specVersion = 1,
    bool private = false,
    DateTime? deletedAt,
  }) => JournalEntity.goal(
    meta: Metadata(
      id: id,
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
      private: private,
      deletedAt: deletedAt,
    ),
    data: GoalData(
      title: 'Waddle $id',
      statement: 'Waddle to the ice shelf five days a week.',
      criteria: criteria,
      specVersion: specVersion,
      specVersionId: '$id:spec-v$specVersion',
      snapshotOf: snapshotOf,
    ),
  );

  Future<void> setPrivateFlag({required bool status}) => db!.upsertConfigFlag(
    ConfigFlag(
      name: privateFlag,
      description: 'Show private entries?',
      status: status,
    ),
  );

  group('JournalDb goal queries -', () {
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
      'getGoals returns live goals newest first and excludes spec snapshots '
      'and deleted goals',
      () async {
        await db!.updateJournalEntity(goal('goal-older', at: baseTime));
        await db!.updateJournalEntity(
          goal('goal-newer', at: baseTime.add(const Duration(days: 2))),
        );
        await db!.updateJournalEntity(
          goal(
            'goal-deleted',
            at: baseTime.add(const Duration(days: 3)),
            deletedAt: baseTime.add(const Duration(days: 4)),
          ),
        );
        // A snapshot shares the Goal row type but carries its goal's id as
        // the subtype, so it must never be listed as a goal of its own.
        await db!.updateJournalEntity(
          goal(
            'snapshot-1',
            at: baseTime.add(const Duration(days: 5)),
            snapshotOf: 'goal-older',
          ),
        );

        final goals = await db!.getGoals();

        expect(goals.map((g) => g.meta.id).toList(), [
          'goal-newer',
          'goal-older',
        ]);
        expect(goals.every((g) => g.data.snapshotOf == null), isTrue);
      },
    );

    test(
      "getSpecSnapshotsForGoal returns only that goal's live snapshots, "
      'newest first',
      () async {
        await db!.updateJournalEntity(goal('goal-a', at: baseTime));
        await db!.updateJournalEntity(
          goal('snap-a-v1', at: baseTime, snapshotOf: 'goal-a'),
        );
        await db!.updateJournalEntity(
          goal(
            'snap-a-v2',
            at: baseTime.add(const Duration(days: 1)),
            snapshotOf: 'goal-a',
            specVersion: 2,
          ),
        );
        await db!.updateJournalEntity(
          goal(
            'snap-a-deleted',
            at: baseTime.add(const Duration(days: 2)),
            snapshotOf: 'goal-a',
            deletedAt: baseTime.add(const Duration(days: 3)),
          ),
        );
        await db!.updateJournalEntity(
          goal('snap-b-v1', at: baseTime, snapshotOf: 'goal-b'),
        );

        final snapshots = await db!.getSpecSnapshotsForGoal('goal-a');

        expect(snapshots.map((s) => s.meta.id).toList(), [
          'snap-a-v2',
          'snap-a-v1',
        ]);
        expect(snapshots.map((s) => s.data.specVersion).toList(), [2, 1]);
        expect(await db!.getSpecSnapshotsForGoal('goal-unknown'), isEmpty);
      },
    );

    test(
      'private goals and snapshots are hidden when the private flag is off '
      'and visible when it is on',
      () async {
        await db!.updateJournalEntity(goal('goal-public', at: baseTime));
        await db!.updateJournalEntity(
          goal(
            'goal-private',
            at: baseTime.add(const Duration(days: 1)),
            private: true,
          ),
        );
        await db!.updateJournalEntity(
          goal(
            'snap-private',
            at: baseTime,
            snapshotOf: 'goal-public',
            private: true,
          ),
        );

        await setPrivateFlag(status: false);
        expect((await db!.getGoals()).map((g) => g.meta.id), ['goal-public']);
        expect(await db!.getSpecSnapshotsForGoal('goal-public'), isEmpty);

        await setPrivateFlag(status: true);
        expect((await db!.getGoals()).map((g) => g.meta.id), [
          'goal-private',
          'goal-public',
        ]);
        expect(
          (await db!.getSpecSnapshotsForGoal(
            'goal-public',
          )).map((s) => s.meta.id),
          ['snap-private'],
        );
      },
    );
  });
}
