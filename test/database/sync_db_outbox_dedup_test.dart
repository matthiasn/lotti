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

  group('Outbox Deduplication Methods', () {
    setUpAll(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(db!);
    });
    tearDownAll(() async {
      await db?.close();
    });

    test(
      'findPendingByEntryId breaks same-second createdAt ties by newest id',
      () async {
        final sameInstant = DateTime(2024, 3, 15, 10);
        // created_at is stored at second granularity, so two rapid edits
        // collide on the timestamp; the higher (newer) id must win.
        await db!.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('older-edit'),
            message: const Value('{"v": 1}'),
            createdAt: Value(sameInstant),
            updatedAt: Value(sameInstant),
            outboxEntryId: const Value('tie-entry'),
          ),
        );
        await db!.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('newer-edit'),
            message: const Value('{"v": 2}'),
            createdAt: Value(sameInstant),
            updatedAt: Value(sameInstant),
            outboxEntryId: const Value('tie-entry'),
          ),
        );

        final pending = await db!.findPendingByEntryId('tie-entry');
        expect(pending, isNotNull);
        expect(pending!.subject, 'newer-edit');
      },
    );

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

        final capture = _SelectPlanCapture();
        final result = await database.runWithInterceptor(
          () => database.findPendingByEntryId('entry-123'),
          interceptor: capture,
        );
        final plan = capture.formattedPlan;

        expect(result, isNotNull);
        expect(
          plan,
          contains('idx_outbox_pending_entry_id_created_at'),
          reason:
              'literal status = 0 must let SQLite use the pending entry-id '
              'partial index instead of scanning all pending rows',
        );
        expect(plan, isNot(matches(RegExp('SCAN outbox(?! USING)'))));
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

    test('updateOutboxMessage promotes a text row to media-bearing', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      final id = await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"original": true}'),
          subject: const Value('original-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-media'),
        ),
      );

      // A re-sync merging onto a pending edit must carry the blob. The row's
      // filePath is also what keeps it out of the dequeue-time bundler, which
      // ships JSON manifests only.
      final rowsAffected = await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"updated": true}',
        newSubject: 'updated-subject',
        filePath: '/images/photo.jpg',
      );
      expect(rowsAffected, 1);
      expect(
        (await database.allOutboxItems).single.filePath,
        '/images/photo.jpg',
      );

      // A later merge that passes no path leaves the attachment in place
      // rather than silently clearing it.
      await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"updated": 2}',
        newSubject: 'updated-subject-2',
      );
      expect(
        (await database.allOutboxItems).single.filePath,
        '/images/photo.jpg',
      );
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

    test('schema version is 29', () {
      expect(db.schemaVersion, 29);
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
    });
  });

  group('updateOutboxMessage - priority parameter -', () {
    // Exercises line 2253: the `priority != null ? Value(priority) : Value.absent()`
    // branch inside `updateOutboxMessage`.
    late SyncDatabase database;

    setUpAll(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(database);
    });
    tearDownAll(() async {
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
