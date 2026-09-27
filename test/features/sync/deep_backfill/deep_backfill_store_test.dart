import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  late JournalDb db;
  late DeepBackfillTableQueries queries;

  /// Inserts a link row whose serialized JSON carries [clockJson] verbatim
  /// (null leaves the clock out).
  Future<void> insertLink(String id, {String? clockJson}) =>
      db.customStatement(
        'INSERT INTO linked_entries (id, from_id, to_id, type, serialized) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          id,
          'from-$id',
          'to-$id',
          'BasicLink',
          if (clockJson == null) '{"id":"$id"}' else '{"id":"$id","vectorClock":$clockJson}',
        ],
      );

  setUp(() async {
    db = JournalDb(inMemoryDatabase: true);
    queries = DeepBackfillTableQueries(
      db: db,
      table: 'linked_entries',
      clockSql: r"json_extract(serialized, '$.vectorClock')",
    );
    for (final id in ['b', 'd', 'a', 'c']) {
      await insertLink(id, clockJson: '{"host":${id.codeUnitAt(0) - 96}}');
    }
    await insertLink('e');
  });

  tearDown(() => db.close());

  test('count counts every row', () async {
    expect(await queries.count(), 5);
  });

  test('page returns rows in id order after the cursor, up to the limit', () async {
    final first = await queries.page(after: null, limit: 2);
    final next = await queries.page(after: first.last.id, limit: 2);
    final last = await queries.page(after: next.last.id, limit: 2);

    expect(first.map((r) => r.id), ['a', 'b']);
    expect(first.first.clock, const VectorClock({'host': 1}));
    expect(next.map((r) => r.id), ['c', 'd']);
    expect(last.map((r) => r.id), ['e']);
    expect(last.single.clock, isNull, reason: 'a row without a clock');
  });

  test('range honours each bound and treats null as unbounded', () async {
    expect(
      (await queries.range(start: 'b', end: 'd')).keys,
      unorderedEquals(['b', 'c']),
      reason: 'start inclusive, end exclusive',
    );
    expect(
      (await queries.range(start: null, end: 'b')).keys,
      ['a'],
    );
    expect(
      (await queries.range(start: 'd', end: null)).keys,
      unorderedEquals(['d', 'e']),
    );
    final all = await queries.range(start: null, end: null);
    expect(all.length, 5);
    expect(all['c'], const VectorClock({'host': 3}));
    expect(all['e'], isNull);
  });

  test('serializedByIds loads the rows that exist, across chunks', () async {
    final ids = {
      'a',
      'c',
      'missing',
      for (var i = 0; i < DeepBackfillTableQueries.inListChunk + 5; i++)
        'absent-$i',
    };
    final rows = await queries.serializedByIds(ids);

    expect(rows.keys, unorderedEquals(['a', 'c']));
    expect(rows['a'], contains('"vectorClock":{"host":1}'));
  });

  group('rangeClause', () {
    test('names only the bounds that are set', () {
      final (both, bothVars) = DeepBackfillTableQueries.rangeClause(
        start: 'a',
        end: 'z',
      );
      final (none, noneVars) = DeepBackfillTableQueries.rangeClause(
        start: null,
        end: null,
      );
      final (onlyEnd, endVars) = DeepBackfillTableQueries.rangeClause(
        start: null,
        end: 'z',
      );

      expect(both, 'WHERE id >= ? AND id < ?');
      expect(bothVars.map((v) => v.value), ['a', 'z']);
      expect(none, isEmpty);
      expect(noneVars, isEmpty);
      expect(onlyEnd, 'WHERE id < ?');
      expect(endVars.map((v) => (v as Variable<String>).value), ['z']);
    });
  });

  group('parseClock', () {
    test('reads a JSON object of host to counter', () {
      expect(
        DeepBackfillTableQueries.parseClock('{"a":2,"b":1}'),
        const VectorClock({'a': 2, 'b': 1}),
      );
    });

    test('reads null, empty, non-object and malformed JSON as no clock', () {
      for (final json in [null, '', '[1]', '{not json', '{"a":"x"}']) {
        expect(
          DeepBackfillTableQueries.parseClock(json),
          isNull,
          reason: json,
        );
      }
    });
  });
}
