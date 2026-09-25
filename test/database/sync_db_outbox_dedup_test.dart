// Tests for outbox dedup lookups, payload-size tracking, and volume/
// health stats (`lib/database/sync_db_outbox_dedup.dart`).
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import 'sync_db_test_utils.dart';

void main() {
  SyncDatabase? db;

  group('getPendingBackfillEntries Tests', () {
    // Subject prefix that production `_enqueueBackfillRequest` stamps on
    // every backfill outbox row. `getPendingBackfillEntries` filters with a
    // bounded `backfillRequest:` subject-prefix range at the SQL level so it
    // can skip JSON-decoding unrelated pending rows on a million-row outbox.
    const backfillSubject = 'backfillRequest:batch:1';

    setUpAll(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(db!);
    });
    tearDownAll(() async {
      await db?.close();
    });

    test('returns empty set when no outbox items', () async {
      final database = db!;
      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('returns empty set when no backfill request messages', () async {
      final database = db!;

      // Add a regular message (not backfill request)
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: 'journalEntity',
          message: '{"runtimeType":"journalEntity","id":"test-1"}',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test(
      'excludes pending rows whose subject does not match the backfill prefix',
      () async {
        final database = db!;

        // Backfill-shaped JSON but a non-backfill subject — the SQL
        // prefilter must drop this row before it ever reaches JSON
        // decode. Production has no path that produces this combination
        // (`_enqueueBackfillRequest` is the only writer of this JSON
        // shape and it always stamps the matching subject), but the
        // filter is what makes the rewritten query cheap on huge
        // outboxes, so verify it is doing real work.
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 1, 1),
            subject: 'something-else',
            message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "req-1"
}
''',
          ),
        );

        final entries = await database.getPendingBackfillEntries();
        expect(entries, isEmpty);
      },
    );

    test('extracts entries from pending backfill request messages', () async {
      final database = db!;

      // Add a backfill request message with entries
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1", "counter": 5},
    {"hostId": "host-1", "counter": 6},
    {"hostId": "host-2", "counter": 10}
  ],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      expect(entries, hasLength(3));
      expect(
        entries,
        containsAll([
          (hostId: 'host-1', counter: 5),
          (hostId: 'host-1', counter: 6),
          (hostId: 'host-2', counter: 10),
        ]),
      );
    });

    test('ignores sent backfill request messages', () async {
      final database = db!;

      // Add a sent (not pending) backfill request message
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('includes sending backfill request messages', () async {
      final database = db!;

      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, {(hostId: 'host-1', counter: 5)});
    });

    test('ignores error backfill request messages', () async {
      final database = db!;

      // Add an error (not pending) backfill request message
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles malformed JSON gracefully', () async {
      final database = db!;

      // Add a malformed message — but with the backfill subject so the
      // SQL prefilter does not exclude it. The Dart-side try/catch is
      // what guards against a bad message body slipping past.
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: 'not valid json',
        ),
      );

      // Should not throw, just return empty
      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles missing entries array gracefully', () async {
      final database = db!;

      // Add a backfill request without entries array
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '{"runtimeType": "backfillRequest", "requesterId": "req-1"}',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles invalid entry format gracefully', () async {
      final database = db!;

      // Add a backfill request with invalid entry format
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1"},
    {"counter": 5},
    "invalid",
    null,
    {"hostId": "host-2", "counter": 10}
  ],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      // Only the valid entry should be extracted
      expect(entries, hasLength(1));
      expect(entries.first, (hostId: 'host-2', counter: 10));
    });

    test('combines entries from multiple pending backfill requests', () async {
      final database = db!;

      // Add first backfill request
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 1}],
  "requesterId": "req-1"
}
''',
        ),
      );

      // Add second backfill request
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 2),
          subject: 'backfillRequest:batch:2',
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-2", "counter": 2}],
  "requesterId": "req-2"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      expect(entries, hasLength(2));
      expect(
        entries,
        containsAll([
          (hostId: 'host-1', counter: 1),
          (hostId: 'host-2', counter: 2),
        ]),
      );
    });

    test('deduplicates identical entries', () async {
      final database = db!;

      // Add backfill request with duplicate entries
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1", "counter": 5},
    {"hostId": "host-1", "counter": 5}
  ],
  "requesterId": "req-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      // Set automatically deduplicates
      expect(entries, hasLength(1));
      expect(entries.first, (hostId: 'host-1', counter: 5));
    });

    test('plan uses the actionable subject index rather than scanning every '
        'pending/sending outbox row — load-bearing for the 2-minute backfill '
        'tick that used to filter the backfillRequest subject after scanning '
        'the actionable queue', () async {
      final database = db!;

      for (var i = 0; i < 50; i++) {
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: DateTime(2024, 1, 1).add(Duration(seconds: i)),
            subject: 'irrelevant:$i',
            message: '{"runtimeType": "noise"}',
          ),
        );
      }
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 2, 1),
          subject: backfillSubject,
          message:
              '{"runtimeType": "backfillRequest", '
              '"entries": [{"hostId": "h1", "counter": 1}], '
              '"requesterId": "req-1"}',
        ),
      );

      final capture = _SelectPlanCapture();
      final entries = await database.runWithInterceptor(
        database.getPendingBackfillEntries,
        interceptor: capture,
      );
      final plan = capture.formattedPlan;

      expect(
        plan,
        contains('idx_outbox_actionable_subject'),
        reason:
            'the backfill-request probe must range-scan the subject '
            'prefix index instead of walking every actionable row',
      );
      expect(
        plan,
        isNot(matches(RegExp('SCAN outbox(?! USING)'))),
        reason:
            'no base-table scan once the planner can see the subject '
            'prefix range and actionable status set',
      );
      expect(entries, hasLength(1));
    });

    test('status literals (0, 3) baked into the partial-index match stay '
        'in sync with OutboxStatus.pending.index and the sending status '
        'used by the outbox state machine — without this guard a future '
        'enum reorder would silently index the wrong rows', () {
      expect(OutboxStatus.pending.index, 0);
      // `_outboxSendingStatus` mirrors OutboxStatus.sending.index (3);
      // the sync_db.dart guard test asserts the partial-index DDL uses
      // the same two literals via `idx_outbox_actionable_priority_created_at`.
      expect(OutboxStatus.sending.index, 3);
    });
  });

  group('Dequeue-time collapse lookups (ADR 0086)', () {
    setUpAll(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(db!);
    });
    tearDownAll(() async {
      await db?.close();
    });

    Future<int> row(OutboxStatus status, String? entryId) => db!.addOutboxItem(
      OutboxCompanion(
        status: Value(status.index),
        subject: Value('${status.name}:$entryId'),
        message: const Value('{}'),
        createdAt: Value(DateTime(2024, 3, 15)),
        updatedAt: Value(DateTime(2024, 3, 15)),
        outboxEntryId: Value(entryId),
      ),
    );

    test('collapsibleOutboxRows returns the pending and failed rows of the '
        'entity in enqueue order, and nothing else', () async {
      final failed = await row(OutboxStatus.error, 'e');
      final first = await row(OutboxStatus.pending, 'e');
      await row(OutboxStatus.sending, 'e');
      await row(OutboxStatus.sent, 'e');
      await row(OutboxStatus.pending, 'other');
      await row(OutboxStatus.pending, null);
      final second = await row(OutboxStatus.pending, 'e');

      final rows = await db!.collapsibleOutboxRows('e');
      expect(rows.map((r) => r.id), [failed, first, second]);

      final withoutFirst = await db!.collapsibleOutboxRows(
        'e',
        excludeIds: {first},
      );
      expect(withoutFirst.map((r) => r.id), [failed, second]);
    });

    test('claimOutboxRows claims only rows whose status is unchanged since '
        'they were read', () async {
      final pending = await row(OutboxStatus.pending, 'e');
      final failed = await row(OutboxStatus.error, 'e');
      final read = await db!.collapsibleOutboxRows('e');
      // The monitor retries the failed row in between.
      await db!.updateOutboxItem(
        OutboxCompanion(
          id: Value(failed),
          status: Value(OutboxStatus.pending.index),
        ),
      );

      final now = DateTime(2024, 3, 15, 12);
      final claimed = await db!.claimOutboxRows(read, now: now);

      expect(claimed.map((r) => r.id), [pending]);
      expect(claimed.single.status, OutboxStatus.sending.index);
      final statuses = {
        for (final item in await db!.allOutboxItems) item.id: item.status,
      };
      expect(statuses, {
        pending: OutboxStatus.sending.index,
        failed: OutboxStatus.pending.index,
      });
    });
  });

  group('Payload size tracking -', () {
    setUpAll(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(db!);
    });
    tearDownAll(() async {
      await db?.close();
    });

    test('stores and retrieves payloadSize on outbox items', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{"test": true}'),
          createdAt: Value(now),
          updatedAt: Value(now),
          payloadSize: const Value(4096),
        ),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, 4096);
    });

    test('payloadSize defaults to null when not provided', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        buildOutboxCompanion(status: OutboxStatus.pending, createdAt: now),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, isNull);
    });
  });

  group('Payload size column behavior -', () {
    late SyncDatabase db;

    setUpAll(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(db);
    });
    tearDownAll(() async {
      await db.close();
    });

    test('payloadSize defaults to null when omitted', () async {
      final now = DateTime(2025, 3, 15, 10);
      await db.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{"old": true}'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await db.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, isNull);
    });

    test('schema version is 29', () {
      expect(db.schemaVersion, 30);
    });

    test('OutboxStatus indices used by the partial-index annotation '
        'on the Outbox table stay aligned with the enum — `@TableIndex.sql` '
        'is a const-string annotation that cannot reference the enum at '
        'compile time, so the literals (0, 3) used in '
        '`idx_outbox_actionable_priority_created_at` would silently '
        'index the wrong rows if `OutboxStatus` were ever reordered. '
        'This guard fails loudly instead.', () {
      expect(
        OutboxStatus.pending.index,
        0,
        reason:
            'pending must be index 0 — used as a literal in the '
            'partial-index WHERE clause.',
      );
      expect(
        OutboxStatus.sending.index,
        3,
        reason:
            'sending must be index 3 — used as a literal in the '
            'partial-index WHERE clause and as `_outboxSendingStatus` '
            'in sync_db.dart.',
      );
      expect(
        OutboxStatus.sent.index,
        1,
        reason:
            'sent must be index 1 — used as a literal in the '
            'sent-ledger updated_at partial-index WHERE clause.',
      );
      expect(
        OutboxStatus.error.index,
        2,
        reason:
            'error must be index 2 — used as a literal in '
            '`collapsibleOutboxRows`.',
      );
    });
  });
}

class _SelectPlanCapture extends QueryInterceptor {
  List<Map<String, Object?>> _plan = const [];

  String get formattedPlan => _plan.map((row) => row.toString()).join('\n');

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    _plan = await executor.runSelect('EXPLAIN QUERY PLAN $statement', args);
    return executor.runSelect(statement, args);
  }
}
