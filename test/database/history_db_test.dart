// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/history_db.dart';

void main() {
  late HistoryDb db;

  setUp(() {
    db = HistoryDb(inMemoryDatabase: true, background: false);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> append(String entityId, DateTime visitedAt) => db.appendEntry(
    kind: 'task',
    entityId: entityId,
    route: '/tasks/$entityId',
    visitedAt: visitedAt,
  );

  test('appended rows read back newest first with growing ids', () async {
    final first = await append('a', DateTime(2026, 3, 1, 9));
    final second = await append('b', DateTime(2026, 3, 1, 10));

    expect(second, greaterThan(first));
    final rows = await db.entriesPage(limit: 10);
    expect(rows.map((r) => r.entityId), ['b', 'a']);
    expect(rows.first.route, '/tasks/b');
    expect(rows.first.kind, 'task');
    expect(rows.first.visitedAt, DateTime(2026, 3, 1, 10));
  });

  test('latestEntry is the last appended row, null when empty', () async {
    expect(await db.latestEntry(), isNull);
    await append('a', DateTime(2026, 3, 1, 9));
    await append('b', DateTime(2026, 3, 1, 8));
    expect((await db.latestEntry())?.entityId, 'b');
  });

  test('entriesPage pages below a cursor without repeating rows', () async {
    for (var i = 0; i < 5; i++) {
      await append('e$i', DateTime(2026, 3, 1, i));
    }
    final firstPage = await db.entriesPage(limit: 2);
    final secondPage = await db.entriesPage(
      limit: 2,
      beforeId: firstPage.last.id,
    );
    final thirdPage = await db.entriesPage(
      limit: 2,
      beforeId: secondPage.last.id,
    );

    expect(firstPage.map((r) => r.entityId), ['e4', 'e3']);
    expect(secondPage.map((r) => r.entityId), ['e2', 'e1']);
    expect(thirdPage.map((r) => r.entityId), ['e0']);
  });

  test('entriesPage keeps from inclusive and to exclusive', () async {
    await append('before', DateTime(2026, 3, 1, 23, 59));
    await append('start', DateTime(2026, 3, 2));
    await append('inside', DateTime(2026, 3, 2, 12));
    await append('end', DateTime(2026, 3, 3));

    final rows = await db.entriesPage(
      limit: 10,
      from: DateTime(2026, 3, 2),
      to: DateTime(2026, 3, 3),
    );
    expect(rows.map((r) => r.entityId), ['inside', 'start']);
  });

  test('deleteEntry removes only that row, for good', () async {
    final keep = await append('keep', DateTime(2026, 3, 1));
    final drop = await append('drop', DateTime(2026, 3, 2));

    expect(await db.deleteEntry(drop), 1);
    expect(await db.deleteEntry(drop), 0);
    final rows = await db.entriesPage(limit: 10);
    expect(rows.map((r) => r.id), [keep]);
  });
}
