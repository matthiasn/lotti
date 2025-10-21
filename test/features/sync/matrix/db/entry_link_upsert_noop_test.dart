import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';

void main() {
  test('upsertEntryLink returns 0 on identical serialized payload', () async {
    final db =
        JournalDb(inMemoryDatabase: true, overriddenFilename: 'mem.sqlite');
    addTearDown(() async => db.close());

    final link = EntryLink.basic(
      id: 'L1',
      fromId: 'A',
      toId: 'B',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    );

    final first = await db.upsertEntryLink(link);
    expect(first, isNonZero);
    final second = await db.upsertEntryLink(link);
    expect(second, 0);
  });
}
