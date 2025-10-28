import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';

import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty priorities selection returns all tasks (no filtering)', () async {
    final db = JournalDb(inMemoryDatabase: true);
    final base = DateTime(2024, 10, 15, 8);

    JournalEntity build(String id, int hours, TaskPriority p) =>
        JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: base.add(Duration(hours: hours)),
            updatedAt: base.add(Duration(hours: hours)),
            dateFrom: base.add(Duration(hours: hours)),
            dateTo: base.add(Duration(hours: hours)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 'status-$id',
              createdAt: base.add(Duration(hours: hours)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            title: 'Task $id',
            priority: p,
          ),
          entryText: EntryText(plainText: 'Test $id'),
        );

    final entries = [
      build('p0', 0, TaskPriority.p0Urgent),
      build('p1', 1, TaskPriority.p1High),
      build('p2', 2, TaskPriority.p2Medium),
      build('p3', 3, TaskPriority.p3Low),
    ];

    for (final e in entries) {
      await db.upsertJournalDbEntity(toDbEntity(e));
    }

    // Pass an explicit empty priorities list; should not filter out anything
    final results = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN'],
      categoryIds: const [''],
      priorities: const <String>[],
    );

    // Verify all tasks are present and ordered by priority rank then date_from DESC
    expect(results.map((e) => e.meta.id).toList(), ['p0', 'p1', 'p2', 'p3']);

    await db.close();
  });
}
