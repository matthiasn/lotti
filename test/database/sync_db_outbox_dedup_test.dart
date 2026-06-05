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
    // every backfill outbox row. `getPendingBackfillEntries` filters on
    // `subject LIKE 'backfillRequest:%'` at the SQL level so it can skip
    // JSON-decoding unrelated pending rows on a million-row outbox.
    const backfillSubject = 'backfillRequest:batch:1';

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
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

    test(
      'plan uses an outbox status index (full or partial) rather than '
      'SCANning the table — load-bearing for the 2-minute backfill tick '
      'which was the top offender in the 2026-05-12 desktop slow-query '
      'log when `t.status.isIn([pending, sending])` bound the values '
      'as parameters and the planner fell back to SCAN outbox',
      () async {
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

        final rows = await database
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM outbox WHERE status IN (0, 3) '
              "AND subject LIKE 'backfillRequest:%'",
            )
            .get();
        final plan = rows.map((r) => r.data.toString()).join('\n');

        // With status values inlined as literals the planner has a real
        // status filter at plan time and picks either the partial
        // `idx_outbox_actionable_priority_created_at` (WHERE status IN
        // (0, 3)) or the full `idx_outbox_status_priority_created_at` for
        // a two-key seek. Both are correct outcomes; the regression we
        // are guarding against is the planner falling back to SCAN
        // outbox, which is what happened with parameterised statuses.
        expect(
          plan,
          anyOf(
            contains('idx_outbox_actionable_priority_created_at'),
            contains('idx_outbox_status_priority_created_at'),
          ),
          reason:
              'literal `IN (0, 3)` must let the planner pick a status '
              'index seek instead of falling back to SCAN outbox',
        );
        expect(
          plan,
          isNot(matches(RegExp('SCAN outbox(?! USING)'))),
          reason:
              'no base-table scan once the planner can see the status set '
              '(an indexed `SCAN outbox USING INDEX <name>` plan is fine — '
              'only bare `SCAN outbox` is a regression)',
        );

        final entries = await database.getPendingBackfillEntries();
        expect(entries, hasLength(1));
      },
    );

    test(
      'status literals (0, 3) baked into the partial-index match stay '
      'in sync with OutboxStatus.pending.index and the sending status '
      'used by the outbox state machine — without this guard a future '
      'enum reorder would silently index the wrong rows',
      () {
        expect(OutboxStatus.pending.index, 0);
        // `_outboxSendingStatus` mirrors OutboxStatus.sending.index (3);
        // the sync_db.dart guard test asserts the partial-index DDL uses
        // the same two literals via `idx_outbox_actionable_priority_created_at`.
        expect(OutboxStatus.sending.index, 3);
      },
    );
  });

  group('Outbox Deduplication Methods', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('findPendingByEntryId returns pending item for entry', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add a pending item with entryId
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"test": true}'),
          subject: const Value('test-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-123'),
        ),
      );

      final result = await database.findPendingByEntryId('entry-123');
      expect(result, isNotNull);
      expect(result!.outboxEntryId, 'entry-123');
      expect(result.message, '{"test": true}');
    });

    test('findPendingByEntryId returns null when no matching entry', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add a pending item with different entryId
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"test": true}'),
          subject: const Value('test-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-456'),
        ),
      );

      final result = await database.findPendingByEntryId('entry-123');
      expect(result, isNull);
    });

    test(
      'findPendingByEntryId returns null when entry is not pending',
      () async {
        final database = db!;
        final now = DateTime(2024, 1, 1);

        // Add a sent (non-pending) item with entryId
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            message: const Value('{"test": true}'),
            subject: const Value('test-subject'),
            createdAt: Value(now),
            updatedAt: Value(now),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        final result = await database.findPendingByEntryId('entry-123');
        expect(result, isNull);
      },
    );

    test(
      'findPendingByEntryId returns most recent when multiple exist',
      () async {
        final database = db!;

        // Add older item
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            message: const Value('{"version": 1}'),
            subject: const Value('test-subject-old'),
            createdAt: Value(DateTime(2024, 1, 1)),
            updatedAt: Value(DateTime(2024, 1, 1)),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        // Add newer item
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            message: const Value('{"version": 2}'),
            subject: const Value('test-subject-new'),
            createdAt: Value(DateTime(2024, 1, 2)),
            updatedAt: Value(DateTime(2024, 1, 2)),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        final result = await database.findPendingByEntryId('entry-123');
        expect(result, isNotNull);
        expect(result!.message, '{"version": 2}');
        expect(result.subject, 'test-subject-new');
      },
    );

    test(
      'findPendingByEntryId uses the pending entry-id partial index',
      () async {
        final database = db!;

        for (var i = 0; i < 50; i++) {
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.sent.index),
              message: Value('{"i":$i}'),
              subject: Value('sent-$i'),
              createdAt: Value(DateTime(2024, 1, 1).add(Duration(minutes: i))),
              updatedAt: Value(DateTime(2024, 1, 1).add(Duration(minutes: i))),
              outboxEntryId: Value('entry-$i'),
            ),
          );
        }
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            message: const Value('{"version": 1}'),
            subject: const Value('test-subject'),
            createdAt: Value(DateTime(2024, 1, 2)),
            updatedAt: Value(DateTime(2024, 1, 2)),
            outboxEntryId: const Value('entry-123'),
          ),
        );
        await database.customStatement('ANALYZE');

        final rows = await database
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM outbox '
              'WHERE status = 0 AND outbox_entry_id = ?1 '
              'ORDER BY created_at DESC LIMIT 1',
              variables: [const Variable<String>('entry-123')],
            )
            .get();
        final plan = rows.map((row) => row.data.toString()).join('\n');

        expect(
          plan,
          contains('idx_outbox_pending_entry_id_created_at'),
          reason:
              'literal status = 0 must let SQLite use the pending entry-id '
              'partial index instead of scanning all pending rows',
        );
        expect(
          plan,
          isNot(matches(RegExp('SCAN outbox(?! USING)'))),
        );
      },
    );

    test('updateOutboxMessage updates message and subject', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add an item
      final id = await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"original": true}'),
          subject: const Value('original-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-123'),
        ),
      );

      // Update the item
      final rowsAffected = await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"updated": true}',
        newSubject: 'updated-subject',
      );

      expect(rowsAffected, 1);

      // Verify the update
      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.message, '{"updated": true}');
      expect(items.first.subject, 'updated-subject');
      // updatedAt should be changed
      expect(items.first.updatedAt.isAfter(now), isTrue);
    });

    test('updateOutboxMessage returns 0 when item not found', () async {
      final database = db!;

      final rowsAffected = await database.updateOutboxMessage(
        itemId: 999,
        newMessage: '{"new": true}',
        newSubject: 'new-subject',
      );

      expect(rowsAffected, 0);
    });

    test('updateOutboxMessage updates payloadSize when provided', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: now,
          message: '{"data": "test"}',
        ),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));

      await database.updateOutboxMessage(
        itemId: items.first.id,
        newMessage: '{"data": "updated"}',
        newSubject: 'updated',
        payloadSize: 12345,
      );

      final updatedItems = await database.allOutboxItems;
      expect(updatedItems.first.payloadSize, 12345);
    });
  });

  group('Payload size tracking -', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
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

    test('getDailyOutboxVolume returns empty for no sent items', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, isEmpty);
    });

    test('getDailyOutboxVolume aggregates sent items by day', () async {
      final database = db!;
      final day1 = DateTime.utc(2025, 3, 14, 10);
      final day2 = DateTime.utc(2025, 3, 15, 8);
      final day2b = DateTime.utc(2025, 3, 15, 14);
      final now = DateTime.utc(2025, 3, 16);

      // Day 1: one item, 1000 bytes
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day1),
          updatedAt: Value(day1),
          payloadSize: const Value(1000),
        ),
      );

      // Day 2: two items, 2000 + 3000 bytes
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s2'),
          message: const Value('m2'),
          createdAt: Value(day2),
          updatedAt: Value(day2),
          payloadSize: const Value(2000),
        ),
      );
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s3'),
          message: const Value('m3'),
          createdAt: Value(day2b),
          updatedAt: Value(day2b),
          payloadSize: const Value(3000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(2));

      // Day 1: 1 item, 1000 bytes
      expect(volumes[0].itemCount, 1);
      expect(volumes[0].totalBytes, 1000);

      // Day 2: 2 items, 5000 bytes
      expect(volumes[1].itemCount, 2);
      expect(volumes[1].totalBytes, 5000);
    });

    test('getDailyOutboxVolume excludes non-sent items', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      // Pending item - should not be included
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(1000),
        ),
      );

      // Sent item - should be included
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s2'),
          message: const Value('m2'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(2000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 2000);
      expect(volumes.first.itemCount, 1);
    });

    test('getDailyOutboxVolume respects days parameter', () async {
      final database = db!;
      final now = DateTime.utc(2025, 3, 20);
      final recent = DateTime.utc(2025, 3, 19, 10);
      final old = DateTime.utc(2025, 3, 10, 10);

      // Old item - outside 7-day window
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('old'),
          message: const Value('m'),
          createdAt: Value(old),
          updatedAt: Value(old),
          payloadSize: const Value(1000),
        ),
      );

      // Recent item - within 7-day window
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('recent'),
          message: const Value('m'),
          createdAt: Value(recent),
          updatedAt: Value(recent),
          payloadSize: const Value(2000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 2000);

      // With larger window, both should appear
      final allVolumes = await database.getDailyOutboxVolume(
        days: 30,
        now: now,
      );
      expect(allVolumes, hasLength(2));
    });

    test('getDailyOutboxVolume treats null payloadSize as zero', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          // No payloadSize - should be treated as 0
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 0);
      expect(volumes.first.itemCount, 1);
    });

    test('OutboxDailyVolume totalMegabytes computes correctly', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(1048576), // exactly 1 MB
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes.first.totalMegabytes, closeTo(1.0, 0.001));
    });
  });

  group('Payload size column behavior -', () {
    late SyncDatabase db;

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
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

    test('updateOutboxMessage writes payloadSize to existing row', () async {
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
      await db.updateOutboxMessage(
        itemId: items.first.id,
        newMessage: '{"updated": true}',
        newSubject: 'updated-subject',
        payloadSize: 9999,
      );

      final updated = await db.allOutboxItems;
      expect(updated.first.payloadSize, 9999);
    });

    test('schema version is 24', () {
      expect(db.schemaVersion, 24);
    });

    test(
      'OutboxStatus indices used by the partial-index annotation '
      'on the Outbox table stay aligned with the enum — `@TableIndex.sql` '
      'is a const-string annotation that cannot reference the enum at '
      'compile time, so the literals (0, 3) used in '
      '`idx_outbox_actionable_priority_created_at` would silently '
      'index the wrong rows if `OutboxStatus` were ever reordered. '
      'This guard fails loudly instead.',
      () {
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
      },
    );
  });

  group('updateOutboxMessage - priority parameter -', () {
    // Exercises line 2253: the `priority != null ? Value(priority) : Value.absent()`
    // branch inside `updateOutboxMessage`.
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await database.close();
    });

    test('updates priority when non-null priority is supplied', () async {
      final now = DateTime(2024, 3, 15, 10);
      final id = await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{}'),
          createdAt: Value(now),
          updatedAt: Value(now),
          priority: Value(OutboxPriority.low.index),
        ),
      );

      final rowsAffected = await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"v":2}',
        newSubject: 'updated',
        priority: OutboxPriority.high.index,
      );

      expect(rowsAffected, 1);
      final item = await database.getOutboxItemById(id);
      expect(item, isNotNull);
      expect(item!.message, '{"v":2}');
      expect(item.priority, OutboxPriority.high.index);
    });

    test('leaves priority unchanged when null priority is supplied', () async {
      final now = DateTime(2024, 3, 15, 10);
      final id = await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{}'),
          createdAt: Value(now),
          updatedAt: Value(now),
          priority: Value(OutboxPriority.normal.index),
        ),
      );

      await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"v":2}',
        newSubject: 'updated',
        // priority intentionally null
      );

      final item = await database.getOutboxItemById(id);
      expect(item, isNotNull);
      // Priority must remain normal since we passed null.
      expect(item!.priority, OutboxPriority.normal.index);
    });
  });

  group('getDailyOutboxVolume -', () {
    late SyncDatabase database;

    setUp(() {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertSent({
      required DateTime sentAt,
      required int payloadSize,
    }) async {
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('subject'),
          message: const Value('{}'),
          createdAt: Value(sentAt.subtract(const Duration(hours: 1))),
          updatedAt: Value(sentAt),
          payloadSize: Value(payloadSize),
        ),
      );
    }

    test(
      'groups sent items by send day with summed bytes and counts, '
      'skipping empty days and items outside the window',
      () async {
        final now = DateTime.utc(2024, 3, 15, 12);

        await insertSent(
          sentAt: DateTime.utc(2024, 3, 15, 8),
          payloadSize: 100,
        );
        await insertSent(
          sentAt: DateTime.utc(2024, 3, 15, 9),
          payloadSize: 250,
        );
        await insertSent(sentAt: DateTime.utc(2024, 3, 13, 9), payloadSize: 40);
        // Outside the 7-day window — must be excluded.
        await insertSent(sentAt: DateTime.utc(2024, 3, 1, 9), payloadSize: 999);
        // Pending row — only `sent` rows count toward volume.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('subject'),
            message: const Value('{}'),
            createdAt: Value(DateTime.utc(2024, 3, 15, 8)),
            updatedAt: Value(DateTime.utc(2024, 3, 15, 8)),
            payloadSize: const Value(500),
          ),
        );

        final volume = await database.getDailyOutboxVolume(now: now);

        expect(volume, hasLength(2));
        expect(volume[0].date, DateTime.utc(2024, 3, 13));
        expect(volume[0].totalBytes, 40);
        expect(volume[0].itemCount, 1);
        expect(volume[1].date, DateTime.utc(2024, 3, 15));
        expect(volume[1].totalBytes, 350);
        expect(volume[1].itemCount, 2);
      },
    );

    test('treats NULL payload sizes as zero bytes', () async {
      final now = DateTime.utc(2024, 3, 15, 12);
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('subject'),
          message: const Value('{}'),
          createdAt: Value(DateTime.utc(2024, 3, 15, 8)),
          updatedAt: Value(DateTime.utc(2024, 3, 15, 8)),
        ),
      );

      final volume = await database.getDailyOutboxVolume(now: now);
      expect(volume, hasLength(1));
      expect(volume.single.totalBytes, 0);
      expect(volume.single.itemCount, 1);
    });

    test('returns empty list for non-positive day windows', () async {
      expect(await database.getDailyOutboxVolume(days: 0), isEmpty);
      expect(await database.getDailyOutboxVolume(days: -3), isEmpty);
    });
  });
}
