import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('columnExistsForTesting returns true/false appropriately', () async {
    // An in-memory DB is created at the current schema, which is exactly what
    // `columnExistsForTesting` inspects — there is no migration scenario here,
    // so no file-based DB (and no path_provider channel mock) is needed.
    final db = JournalDb(inMemoryDatabase: true);
    // journal table is part of schema; id column should exist
    expect(await db.columnExistsForTesting('journal', 'id'), isTrue);
    // Priority columns should also exist in current schema
    expect(await db.columnExistsForTesting('journal', 'task_priority'), isTrue);
    expect(
      await db.columnExistsForTesting('journal', 'task_priority_rank'),
      isTrue,
    );
    expect(await db.columnExistsForTesting('journal', 'nonexistent'), isFalse);
    // Non-existent table should be false
    expect(await db.columnExistsForTesting('fake_table', 'id'), isFalse);
    await db.close();
  });
}
