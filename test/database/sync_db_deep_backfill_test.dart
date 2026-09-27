import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

const _journal = SyncSequencePayloadType.journalEntity;
const _links = SyncSequencePayloadType.entryLink;
final _at = DateTime(2024, 3, 15, 12);

void main() {
  late SyncDatabase db;

  DeepBackfillRequestsCompanion request(
    String entryId, {
    String target = 'peer',
    SyncSequencePayloadType type = _journal,
    String clocks = '[{"a":1}]',
    DateTime? at,
  }) => DeepBackfillRequestsCompanion.insert(
    targetHostId: target,
    payloadType: type.index,
    entryId: entryId,
    vectorClocks: clocks,
    requestedAt: at ?? _at,
  );

  Future<List<String>> idsIn({
    String target = 'peer',
    SyncSequencePayloadType type = _journal,
    String? start,
    String? end,
  }) async => [
    for (final row in await db.deepBackfillRequestsInRange(
      targetHostId: target,
      payloadType: type,
      start: start,
      end: end,
    ))
      row.entryId,
  ]..sort();

  setUp(() async {
    db = SyncDatabase(inMemoryDatabase: true);
    await db.recordDeepBackfillRequests([
      request('a'),
      request('c'),
      request('e'),
      request('c', target: 'other'),
      request('c', type: _links),
    ]);
  });

  tearDown(() => db.close());

  test('reads one advertiser and payload type, within the range', () async {
    expect(await idsIn(), ['a', 'c', 'e']);
    expect(await idsIn(start: 'b', end: 'e'), ['c']);
    expect(await idsIn(start: 'c'), ['c', 'e']);
    expect(await idsIn(end: 'c'), ['a']);
    expect(await idsIn(target: 'other'), ['c']);
    expect(await idsIn(type: _links), ['c']);
  });

  test('recording a request again replaces the earlier row', () async {
    final later = _at.add(const Duration(hours: 1));
    await db.recordDeepBackfillRequests([
      request('a', clocks: '[{"a":2}]', at: later),
    ]);

    final rows = await db.deepBackfillRequestsInRange(
      targetHostId: 'peer',
      payloadType: _journal,
      start: 'a',
      end: 'b',
    );
    expect(rows.single.vectorClocks, '[{"a":2}]');
    expect(rows.single.requestedAt, later);
  });

  test('recording nothing is a no-op', () async {
    await db.recordDeepBackfillRequests(const []);
    expect(await idsIn(), ['a', 'c', 'e']);
  });

  test('removes only the named rows of that advertiser and type, across '
      'chunks', () async {
    await db.removeDeepBackfillRequests(
      targetHostId: 'peer',
      payloadType: _journal,
      entryIds: {'a', 'c', for (var i = 0; i < 600; i++) 'absent-$i'},
    );

    expect(await idsIn(), ['e']);
    expect(await idsIn(target: 'other'), ['c']);
    expect(await idsIn(type: _links), ['c']);
  });

  test('removing nothing is a no-op', () async {
    await db.removeDeepBackfillRequests(
      targetHostId: 'peer',
      payloadType: _journal,
      entryIds: const {},
    );
    expect(await idsIn(), ['a', 'c', 'e']);
  });
}
