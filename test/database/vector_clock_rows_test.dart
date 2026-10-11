import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/vector_clock_rows.dart';

void main() {
  late NotificationsDb db;

  setUp(() {
    db = NotificationsDb(inMemoryDatabase: true, background: false);
  });

  tearDown(() async {
    await db.close();
  });

  /// A raw row whose clock column holds exactly [clock], parseable or not.
  Future<void> insertRow(String id, String clock) => db.customStatement(
    'INSERT INTO notifications (id, created_at, updated_at, scheduled_for, '
    'type, vector_clock, originating_host_id, serialized) '
    "VALUES (?, 0, 0, 0, 'taskSuggestion', ?, 'host-a', '{}')",
    [id, clock],
  );

  /// Records with a map field compare by identity; lists compare deeply.
  List<List<Object?>> flat(Iterable<VectorClockRecord> records) => [
    for (final record in records) [record.id, record.vectorClock],
  ];

  test('pages through every row in id order, each page at most the batch '
      'size', () async {
    await insertRow('c', '{"host-a": 3}');
    await insertRow('a', '{"host-a": 1, "host-b": 2}');
    await insertRow('b', '{"host-b": 5}');

    final pages = await streamTableVectorClocks(
      db,
      table: 'notifications',
      clockSql: 'vector_clock',
      batchSize: 2,
    ).toList();

    expect(pages.map(flat).toList(), [
      [
        [
          'a',
          {'host-a': 1, 'host-b': 2},
        ],
        [
          'b',
          {'host-b': 5},
        ],
      ],
      [
        [
          'c',
          {'host-a': 3},
        ],
      ],
    ]);
    expect(await countTableRows(db, 'notifications'), 3);
  });

  test(
    'a clock that is missing or not a JSON object comes back null',
    () async {
      await insertRow('broken', 'not json');
      await insertRow('list', '[1, 2]');
      await insertRow('null', 'null');

      final records = (await streamTableVectorClocks(
        db,
        table: 'notifications',
        clockSql: 'vector_clock',
      ).toList()).expand((page) => page);

      expect(flat(records), [
        ['broken', null],
        ['list', null],
        ['null', null],
      ]);
    },
  );

  test('an empty table yields no page', () async {
    expect(
      await streamTableVectorClocks(
        db,
        table: 'notifications',
        clockSql: 'vector_clock',
      ).toList(),
      isEmpty,
    );
    expect(await countTableRows(db, 'notifications'), 0);
  });

  test('reads the clock from a JSON path when the expression asks', () async {
    await insertRow('n', '{}');
    await db.customStatement(
      'UPDATE notifications SET serialized = ? WHERE id = ?',
      [
        '{"vectorClock": {"host-c": 7}}',
        'n',
      ],
    );

    final records = await streamTableVectorClocks(
      db,
      table: 'notifications',
      clockSql: r"json_extract(serialized, '$.vectorClock')",
    ).first;

    expect(flat(records), [
      [
        'n',
        {'host-c': 7},
      ],
    ]);
  });
}
