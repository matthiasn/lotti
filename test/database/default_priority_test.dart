import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';

import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;

  setUp(() {
    // `updateJournalEntity` persists the entity JSON next to the (in-memory)
    // DB write; injecting the directory directly avoids any GetIt or
    // path_provider scaffolding.
    testDirectory = Directory.systemTemp.createTempSync('lotti_default_prio_');
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  test('Legacy tasks default to P2 priority when not set', () async {
    final db = JournalDb(
      inMemoryDatabase: true,
      documentsDirectory: testDirectory,
    );
    final base = DateTime(2024, 10);

    const id = 'legacy-task';
    final task = JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: base,
        updatedAt: base,
        dateFrom: base,
        dateTo: base,
      ),
      data: testTask.data.copyWith(
        title: 'Legacy Task',
        // do not set priority explicitly, rely on default
      ),
      entryText: const EntryText(plainText: 'test'),
    );

    await db.updateJournalEntity(task);

    final result = await db.journalEntityById(id);
    expect(result, isNotNull);
    final savedTask = result! as Task;
    expect(savedTask.data.priority, TaskPriority.p2Medium);

    await db.close();
  });
}
