import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';

import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getTasks ordering handles priorities and date ordering within rank',
      () async {
    final db = JournalDb(inMemoryDatabase: true);
    final base = DateTime(2024, 10, 15);

    JournalEntity buildTask(String id, DateTime date, TaskPriority priority) {
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
          priority: priority,
        ),
        entryText: EntryText(plainText: 'Test $id'),
      );
    }

    final tasks = [
      buildTask('p0-old', base, TaskPriority.p0Urgent),
      buildTask(
          'p0-new', base.add(const Duration(days: 1)), TaskPriority.p0Urgent),
      buildTask(
          'p2-task', base.add(const Duration(days: 2)), TaskPriority.p2Medium),
      buildTask(
          'p3-newest', base.add(const Duration(days: 3)), TaskPriority.p3Low),
    ];

    for (final t in tasks) {
      await db.upsertJournalDbEntity(toDbEntity(t));
    }

    final results = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN'],
      categoryIds: const [''],
    );

    expect(results.map((e) => e.meta.id).toList(), [
      'p0-new',
      'p0-old',
      'p2-task',
      'p3-newest',
    ]);

    await db.close();
  });
}
