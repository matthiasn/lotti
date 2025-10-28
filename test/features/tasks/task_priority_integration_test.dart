import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';

import '../../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Priority Integration -', () {
    late JournalDb db;

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    tearDown(() async {
      await db.close();
    });

    test('create → filter → sort → update priority reorders list', () async {
      final base = DateTime(2024, 10, 20, 9);

      JournalEntity buildTask(String id, DateTime date, TaskPriority p) {
        return JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: date,
            updatedAt: date,
            dateFrom: date,
            dateTo: date,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 'status-$id',
              createdAt: date,
              utcOffset: date.timeZoneOffset.inMinutes,
            ),
            title: 'Task $id',
            priority: p,
          ),
          entryText: EntryText(plainText: 'Test $id'),
        );
      }

      final tasks = <JournalEntity>[
        buildTask('urgent-task', base, TaskPriority.p0Urgent),
        buildTask('high-task', base.add(const Duration(hours: 1)),
            TaskPriority.p1High),
        buildTask('medium-task', base.add(const Duration(hours: 2)),
            TaskPriority.p2Medium),
        buildTask(
            'low-task', base.add(const Duration(hours: 3)), TaskPriority.p3Low),
      ];

      // Insert tasks directly via upsert to avoid filesystem interactions
      for (final t in tasks) {
        await db.upsertJournalDbEntity(toDbEntity(t));
      }

      // Verify all tasks are present ordered by priority rank then date_from DESC
      final all = await db.getTasks(
        starredStatuses: const [true, false],
        taskStatuses: const ['OPEN'],
        categoryIds: const [''],
      );
      expect(all.map((e) => e.meta.id).toList(), [
        'urgent-task',
        'high-task',
        'medium-task',
        'low-task',
      ]);

      // Filter by P0 and P1 only
      final urgentHigh = await db.getTasks(
        starredStatuses: const [true, false],
        taskStatuses: const ['OPEN'],
        categoryIds: const [''],
        priorities: const ['P0', 'P1'],
      );
      expect(urgentHigh.map((e) => e.meta.id).toList(), [
        'urgent-task',
        'high-task',
      ]);

      // Update medium-task to P0 and re-upsert; it should move to the top within P0
      final medium = tasks[2] as Task;
      final updatedMedium = medium.copyWith(
        data: medium.data.copyWith(priority: TaskPriority.p0Urgent),
      );
      await db.upsertJournalDbEntity(toDbEntity(updatedMedium));

      final reordered = await db.getTasks(
        starredStatuses: const [true, false],
        taskStatuses: const ['OPEN'],
        categoryIds: const [''],
      );

      // Two P0s now; newer date_from should appear first (medium-task)
      expect(reordered.map((e) => e.meta.id).toList(), [
        'medium-task',
        'urgent-task',
        'high-task',
        'low-task',
      ]);
    });
  });
}
