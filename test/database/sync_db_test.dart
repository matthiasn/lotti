// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

OutboxCompanion _buildOutbox({
  required OutboxStatus status,
  required DateTime createdAt,
  int retries = 0,
  String subject = 'subject',
  String message = '{}',
  String? filePath,
}) {
  return OutboxCompanion(
    status: Value(status.index),
    subject: Value(subject),
    message: Value(message),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
    retries: Value(retries),
    filePath:
        filePath == null ? const Value.absent() : Value<String?>(filePath),
  );
}

void main() {
  SyncDatabase? db;

  group('Sync Database Tests - ', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'empty database',
      () async {
        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.watchOutboxItems().first,
          <OutboxItem>[],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );

    test(
      'add items to database',
      () async {
        final outboxItem1 = OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 13)),
          updatedAt: Value(DateTime(2022, 7, 7, 13)),
          retries: const Value(2),
        );

        final outboxItem2 = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem1);
        await db?.addOutboxItem(outboxItem2);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );
      },
    );

    test(
      'update item in database',
      () async {
        final outboxItem = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        await db?.updateOutboxItem(
          const OutboxCompanion(
            id: Value(1),
            retries: Value(1),
          ),
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 1,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        await db?.updateOutboxItem(
          OutboxCompanion(
            id: const Value(1),
            status: Value(OutboxStatus.sent.index),
          ),
        );

        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );

    test('watchOutboxItems filters by provided statuses', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: 'pending',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 2),
          subject: 'error',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 3),
          subject: 'sent',
        ),
      );

      final results = await database.watchOutboxItems(
        statuses: [
          OutboxStatus.pending,
          OutboxStatus.error,
        ],
      ).first;

      expect(results, hasLength(2));
      expect(
        results.map((item) => item.status).toSet(),
        {OutboxStatus.pending.index, OutboxStatus.error.index},
      );
    });

    test('oldestOutboxItems returns pending items in ascending order',
        () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 3, 10),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 3, 8),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 3, 9),
        ),
      );

      final results = await database.oldestOutboxItems(3);
      expect(
        results.map((item) => item.createdAt),
        [
          DateTime(2024, 3, 8),
          DateTime(2024, 3, 9),
          DateTime(2024, 3, 10),
        ],
      );
    });

    test('oldestOutboxItems respects requested limit', () async {
      final database = db!;
      for (var i = 0; i < 5; i++) {
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 4, 1 + i),
          ),
        );
      }

      final results = await database.oldestOutboxItems(2);
      expect(results, hasLength(2));
      expect(results.first.createdAt, DateTime(2024, 4, 1));
      expect(results.last.createdAt, DateTime(2024, 4, 2));
    });

    test('updateOutboxItem can set status to error', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 1),
        ),
      );

      await database.updateOutboxItem(
        OutboxCompanion(
          id: const Value(1),
          status: Value(OutboxStatus.error.index),
        ),
      );

      final errorItems =
          await database.watchOutboxItems(statuses: [OutboxStatus.error]).first;
      expect(errorItems.single.status, OutboxStatus.error.index);
      expect(await database.watchOutboxCount().first, 0);
    });

    test('watchOutboxCount counts only pending items', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 5, 2),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 5, 3),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 4),
        ),
      );

      expect(await database.watchOutboxCount().first, 1);
    });

    test('updateOutboxItem increments retry count', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 6, 1),
          retries: 0,
        ),
      );

      await database.updateOutboxItem(
        const OutboxCompanion(
          id: Value(1),
          retries: Value(3),
        ),
      );

      final items = await database.oldestOutboxItems(1);
      expect(items.single.retries, 3);
    });

    test('updateOutboxItem updates multiple fields atomically', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 7, 1),
        ),
      );

      final updatedAt = DateTime(2024, 7, 2);
      await database.updateOutboxItem(
        OutboxCompanion(
          id: const Value(1),
          status: Value(OutboxStatus.sent.index),
          retries: const Value(5),
          updatedAt: Value(updatedAt),
        ),
      );

      final rows = await database.allOutboxItems;
      expect(rows.single.status, OutboxStatus.sent.index);
      expect(rows.single.retries, 5);
      expect(rows.single.updatedAt, updatedAt);
    });

    test('updateOutboxItem returns 0 for unknown id', () async {
      final database = db!;
      final result = await database.updateOutboxItem(
        const OutboxCompanion(
          id: Value(99),
          retries: Value(1),
        ),
      );
      expect(result, 0);
    });

    test('watchOutboxItems emits when new item is added', () async {
      final database = db!;
      final updates =
          database.watchOutboxItems(statuses: [OutboxStatus.pending]);
      final expectation = expectLater(
        updates,
        emitsThrough(
          isA<List<OutboxItem>>()
              .having((items) => items.length, 'length', 1)
              .having((items) => items.single.subject, 'subject', 'new-item'),
        ),
      );

      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 8, 10),
          subject: 'new-item',
        ),
      );

      await expectation;
    });

    test('addOutboxItem persists optional fields', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 8, 1),
          retries: 2,
          subject: 'with-file',
          message: '{"payload":true}',
          filePath: '/tmp/outbox.json',
        ),
      );

      final stored = await database.allOutboxItems;
      final item = stored.single;
      expect(item.retries, 2);
      expect(item.filePath, '/tmp/outbox.json');
      expect(item.message, '{"payload":true}');
      expect(item.subject, 'with-file');
    });

    test('deleteOutboxItems removes all items', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 9, 1),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 9, 2),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 9, 3),
        ),
      );

      expect(await database.allOutboxItems, hasLength(3));

      final deletedCount = await database.deleteOutboxItems();
      expect(deletedCount, 3);

      expect(await database.allOutboxItems, isEmpty);
    });
  });

  group('SyncSequenceLog Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('recordSequenceEntry inserts new entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 5;
      final now = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          entryId: const Value('entry-1'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry, isNotNull);
      expect(entry!.hostId, hostId);
      expect(entry.counter, counter);
      expect(entry.entryId, 'entry-1');
      expect(entry.status, SyncSequenceStatus.received.index);
    });

    test('recordSequenceEntry updates existing entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 5;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          entryId: const Value('entry-1'),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.status, SyncSequenceStatus.backfilled.index);
      expect(entry.entryId, 'entry-1');
    });

    test('getLastCounterForHost returns highest counter', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final lastCounter = await database.getLastCounterForHost(hostId);
      expect(lastCounter, 5);
    });

    test('getLastCounterForHost returns null for unknown host', () async {
      final database = db!;
      final lastCounter = await database.getLastCounterForHost('unknown');
      expect(lastCounter, isNull);
    });

    test('getMissingEntries returns only missing/requested entries', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );

      final missing = await database.getMissingEntries();
      expect(missing, hasLength(2));
      expect(missing.map((e) => e.counter).toSet(), {2, 3});
    });

    test('getMissingEntries respects maxRequestCount', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(15),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final missing = await database.getMissingEntries(maxRequestCount: 10);
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test('incrementRequestCount atomically increments', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(0),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.incrementRequestCount(hostId, counter);
      await database.incrementRequestCount(hostId, counter);
      await database.incrementRequestCount(hostId, counter);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.requestCount, 3);
      expect(entry.status, SyncSequenceStatus.requested.index);
      expect(entry.lastRequestedAt, isNotNull);
    });

    test('updateSequenceStatus updates status', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.deleted,
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.status, SyncSequenceStatus.deleted.index);
    });

    test('watchMissingCount emits count of missing entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Initial count should be 0
      expect(await database.watchMissingCount().first, 0);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // After adding one missing entry
      expect(await database.watchMissingCount().first, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      // After adding one requested entry (both missing and requested count)
      expect(await database.watchMissingCount().first, 2);
    });
  });

  group('HostActivity Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('updateHostActivity inserts new host', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime(2024, 1, 1);

      await database.updateHostActivity(hostId, now);

      final lastSeen = await database.getHostLastSeen(hostId);
      expect(lastSeen, now);
    });

    test('updateHostActivity updates existing host', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.updateHostActivity(hostId, DateTime(2024, 1, 1));
      await database.updateHostActivity(hostId, DateTime(2024, 2, 1));

      final lastSeen = await database.getHostLastSeen(hostId);
      expect(lastSeen, DateTime(2024, 2, 1));
    });

    test('getHostLastSeen returns null for unknown host', () async {
      final database = db!;
      final lastSeen = await database.getHostLastSeen('unknown');
      expect(lastSeen, isNull);
    });

    test('getAllHostActivity returns all hosts', () async {
      final database = db!;

      await database.updateHostActivity('host-1', DateTime(2024, 1, 1));
      await database.updateHostActivity('host-2', DateTime(2024, 2, 1));
      await database.updateHostActivity('host-3', DateTime(2024, 3, 1));

      final all = await database.getAllHostActivity();
      expect(all, hasLength(3));
      expect(all.map((h) => h.hostId).toSet(), {'host-1', 'host-2', 'host-3'});
    });

    test('getMissingEntriesForActiveHosts filters by host activity', () async {
      final database = db!;
      const activeHost = 'active-host';
      const inactiveHost = 'inactive-host';

      // Set up host activity
      await database.updateHostActivity(activeHost, DateTime(2024, 1, 10));

      // Add missing entry for active host (never requested)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(activeHost),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Add missing entry for inactive host (no activity record)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(inactiveHost),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final missing = await database.getMissingEntriesForActiveHosts();
      expect(missing, hasLength(1));
      expect(missing.first.hostId, activeHost);
    });

    test(
        'getMissingEntriesForActiveHosts returns empty when no missing entries',
        () async {
      final database = db!;

      // No entries at all
      final missing = await database.getMissingEntriesForActiveHosts();
      expect(missing, isEmpty);
    });

    test('getMissingEntriesForActiveHosts respects exponential backoff',
        () async {
      final database = db!;
      const hostId = 'test-host';

      // Set up host activity (very recent)
      await database.updateHostActivity(hostId, DateTime.now());

      // Add missing entry that was recently requested (should be filtered out)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(1),
          lastRequestedAt: Value(DateTime.now()), // Just requested
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Should be filtered out due to backoff
      final missing = await database.getMissingEntriesForActiveHosts();
      expect(missing, isEmpty);
    });

    test(
        'getMissingEntriesForActiveHosts excludes entries when host not active since last request',
        () async {
      final database = db!;
      const hostId = 'test-host';

      // Host was last seen BEFORE the entry was requested
      await database.updateHostActivity(hostId, DateTime(2024, 1, 1));

      // Entry was requested AFTER host was last seen
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(1),
          lastRequestedAt: Value(DateTime(2024, 1, 5)), // After host last seen
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Should be filtered out because host hasn't been active since request
      final missing = await database.getMissingEntriesForActiveHosts();
      expect(missing, isEmpty);
    });

    test('getMissingEntriesForActiveHosts respects limit', () async {
      final database = db!;
      const hostId = 'test-host';

      // Set up host activity
      await database.updateHostActivity(hostId, DateTime.now());

      // Add multiple missing entries
      for (var i = 1; i <= 10; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesForActiveHosts(limit: 3);
      expect(missing, hasLength(3));
    });
  });

  group('getBackfillStats Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns empty stats when no entries', () async {
      final database = db!;
      final stats = await database.getBackfillStats();

      expect(stats.hostStats, isEmpty);
      expect(stats.totalReceived, 0);
      expect(stats.totalMissing, 0);
      expect(stats.totalRequested, 0);
      expect(stats.totalBackfilled, 0);
      expect(stats.totalDeleted, 0);
    });

    test('counts entries by status for single host', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(1));
      expect(stats.hostStats.first.hostId, hostId);
      expect(stats.hostStats.first.receivedCount, 2);
      expect(stats.hostStats.first.missingCount, 1);
      expect(stats.hostStats.first.backfilledCount, 1);
      expect(stats.hostStats.first.latestCounter, 4);

      expect(stats.totalReceived, 2);
      expect(stats.totalMissing, 1);
      expect(stats.totalBackfilled, 1);
    });

    test('counts entries across multiple hosts', () async {
      final database = db!;

      // Host 1: 2 received
      for (var i = 1; i <= 2; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      // Host 2: 3 missing
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 2, i)),
            updatedAt: Value(DateTime(2024, 2, i)),
          ),
        );
      }

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(2));
      expect(stats.totalReceived, 2);
      expect(stats.totalMissing, 3);
      expect(stats.totalEntries, 5);
    });

    test('includes host activity lastSeenAt', () async {
      final database = db!;
      const hostId = 'host-1';
      final lastSeen = DateTime(2024, 5, 15);

      await database.updateHostActivity(hostId, lastSeen);
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats.first.lastSeenAt, lastSeen);
    });
  });

  group('getMissingEntriesWithLimits Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns missing entries without limits', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits();
      expect(missing, hasLength(5));
    });

    test('respects maxAge limit', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime.now();

      // Entry from 2 hours ago (should be included with 1 day limit)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now.subtract(const Duration(hours: 2))),
          updatedAt: Value(now.subtract(const Duration(hours: 2))),
        ),
      );

      // Entry from 2 days ago (should be excluded with 1 day limit)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now.subtract(const Duration(days: 2))),
          updatedAt: Value(now.subtract(const Duration(days: 2))),
        ),
      );

      final missing = await database.getMissingEntriesWithLimits(
        maxAge: const Duration(days: 1),
      );
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test('respects maxPerHost limit', () async {
      final database = db!;

      // Add 5 entries for host-1
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      // Add 5 entries for host-2
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 2, i)),
            updatedAt: Value(DateTime(2024, 2, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(
        maxPerHost: 2,
      );
      // 2 from host-1 + 2 from host-2 = 4
      expect(missing, hasLength(4));

      // Check we got 2 from each host
      final host1Entries = missing.where((e) => e.hostId == 'host-1').toList();
      final host2Entries = missing.where((e) => e.hostId == 'host-2').toList();
      expect(host1Entries, hasLength(2));
      expect(host2Entries, hasLength(2));
    });

    test('respects overall limit', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 10; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(limit: 3);
      expect(missing, hasLength(3));
    });

    test('respects maxRequestCount', () async {
      final database = db!;
      const hostId = 'host-1';

      // Entry with low request count (should be included)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(2),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Entry with high request count (should be excluded)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(15),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final missing = await database.getMissingEntriesWithLimits(
        maxRequestCount: 10,
      );
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test('combines all limits correctly', () async {
      final database = db!;
      final now = DateTime.now();

      // Recent entries for host-1 (10 entries)
      for (var i = 1; i <= 10; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(Duration(hours: i))),
            updatedAt: Value(now.subtract(Duration(hours: i))),
          ),
        );
      }

      // Old entries for host-2 (should be filtered by maxAge)
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(days: 5))),
            updatedAt: Value(now.subtract(const Duration(days: 5))),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(
        limit: 5,
        maxAge: const Duration(days: 1),
        maxPerHost: 3,
      );

      // Only host-1 entries (maxAge filters host-2)
      // maxPerHost limits to 3
      // overall limit is 5 but maxPerHost restricts to 3
      expect(missing, hasLength(3));
      expect(missing.every((e) => e.hostId == 'host-1'), isTrue);
    });
  });

  group('Batch Operations Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('batchInsertSequenceEntries inserts multiple entries', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      final entries = [
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ];

      await database.batchInsertSequenceEntries(entries);

      final host1Entry1 = await database.getEntryByHostAndCounter('host-1', 1);
      final host1Entry2 = await database.getEntryByHostAndCounter('host-1', 2);
      final host2Entry1 = await database.getEntryByHostAndCounter('host-2', 1);

      expect(host1Entry1, isNotNull);
      expect(host1Entry2, isNotNull);
      expect(host2Entry1, isNotNull);
    });

    test('batchInsertSequenceEntries ignores duplicates', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Insert initial entry
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value('original-entry'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Batch insert with duplicate
      final entries = [
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value('duplicate-entry'),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ];

      await database.batchInsertSequenceEntries(entries);

      // Original entry should be unchanged
      final entry = await database.getEntryByHostAndCounter('host-1', 1);
      expect(entry!.entryId, 'original-entry');
      expect(entry.status, SyncSequenceStatus.received.index);
    });

    test('getCountersForHost returns all counters', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime(2024, 1, 1);

      for (final i in [1, 3, 5, 7]) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final counters = await database.getCountersForHost(hostId);
      expect(counters, {1, 3, 5, 7});
    });

    test('getCountersForHost returns empty set for unknown host', () async {
      final database = db!;
      final counters = await database.getCountersForHost('unknown');
      expect(counters, isEmpty);
    });
  });

  group('getPendingBackfillEntries Tests', () {
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          message: '{"runtimeType":"journalEntity","id":"test-1"}',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('extracts entries from pending backfill request messages', () async {
      final database = db!;

      // Add a backfill request message with entries
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 1),
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

    test('ignores error backfill request messages', () async {
      final database = db!;

      // Add an error (not pending) backfill request message
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 1),
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

      // Add a malformed message
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 2),
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
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
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
  });

  group('getRequestedEntries Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns only entries with requested status', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(2));
      expect(requested.map((e) => e.counter).toSet(), {2, 4});
    });

    test('respects limit parameter', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add 5 requested entries
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final requested = await database.getRequestedEntries(limit: 2);
      expect(requested, hasLength(2));
    });

    test('returns empty list when no requested entries', () async {
      final database = db!;

      // Only add received entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, isEmpty);
    });

    test('orders by createdAt ascending', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries in reverse order
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 30)),
          updatedAt: Value(DateTime(2024, 1, 30)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 10)),
          updatedAt: Value(DateTime(2024, 1, 10)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 20)),
          updatedAt: Value(DateTime(2024, 1, 20)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(3));
      expect(requested[0].counter, 1); // Oldest first
      expect(requested[1].counter, 2);
      expect(requested[2].counter, 3); // Newest last
    });

    test('ignores maxRequestCount - returns all requested entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entry with high request count
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(100), // Very high count
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Should still return the entry regardless of request count
      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(1));
      expect(requested.first.requestCount, 100);
    });
  });

  group('resetRequestCounts Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('resets request count to zero', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      // Add entry with high request count
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(10),
          lastRequestedAt: Value(DateTime(2024, 1, 1)),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.resetRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.requestCount, 0);
      expect(entry.lastRequestedAt, isNull);
    });

    test('resets multiple entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add multiple entries with request counts
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.requested.index),
            requestCount: Value(i * 5), // Different counts
            lastRequestedAt: Value(DateTime(2024, 1, i)),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      await database.resetRequestCounts([
        (hostId: hostId, counter: 1),
        (hostId: hostId, counter: 2),
        (hostId: hostId, counter: 3),
      ]);

      for (var i = 1; i <= 3; i++) {
        final entry = await database.getEntryByHostAndCounter(hostId, i);
        expect(entry!.requestCount, 0);
        expect(entry.lastRequestedAt, isNull);
      }
    });

    test('handles empty list gracefully', () async {
      final database = db!;

      // Should not throw
      await database.resetRequestCounts([]);
    });

    test('updates updatedAt timestamp', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;
      final originalDate = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(5),
          createdAt: Value(originalDate),
          updatedAt: Value(originalDate),
        ),
      );

      await database.resetRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.updatedAt.isAfter(originalDate), isTrue);
    });

    test('does not affect other entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add two entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(10),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(20),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      // Only reset counter 1
      await database.resetRequestCounts([
        (hostId: hostId, counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter(hostId, 1);
      final entry2 = await database.getEntryByHostAndCounter(hostId, 2);

      expect(entry1!.requestCount, 0);
      expect(entry2!.requestCount, 20); // Unchanged
    });
  });

  group('batchIncrementRequestCounts Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('increments request count for single entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(0),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.requestCount, 1);
      expect(entry.status, SyncSequenceStatus.requested.index);
      expect(entry.lastRequestedAt, isNotNull);
    });

    test('increments multiple entries in single batch', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add multiple entries
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            requestCount: const Value(0),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: 1),
        (hostId: hostId, counter: 2),
        (hostId: hostId, counter: 3),
      ]);

      for (var i = 1; i <= 3; i++) {
        final entry = await database.getEntryByHostAndCounter(hostId, i);
        expect(entry!.requestCount, 1);
        expect(entry.status, SyncSequenceStatus.requested.index);
        expect(entry.lastRequestedAt, isNotNull);
      }
    });

    test('increments different hosts in single batch', () async {
      final database = db!;

      // Add entries for different hosts
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(3),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: 'host-1', counter: 1),
        (hostId: 'host-2', counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter('host-1', 1);
      final entry2 = await database.getEntryByHostAndCounter('host-2', 1);
      expect(entry1!.requestCount, 6); // 5 + 1
      expect(entry2!.requestCount, 4); // 3 + 1
    });

    test('handles empty list gracefully', () async {
      final database = db!;

      // Should not throw
      await database.batchIncrementRequestCounts([]);
    });

    test('does not affect other entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add two entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(10),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      // Only increment counter 1
      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter(hostId, 1);
      final entry2 = await database.getEntryByHostAndCounter(hostId, 2);

      expect(entry1!.requestCount, 6); // 5 + 1
      expect(entry2!.requestCount, 10); // Unchanged
      expect(entry2.status, SyncSequenceStatus.missing.index); // Unchanged
    });

    test('updates updatedAt and lastRequestedAt timestamps', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;
      final originalDate = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(0),
          createdAt: Value(originalDate),
          updatedAt: Value(originalDate),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.updatedAt.isAfter(originalDate), isTrue);
      expect(entry.lastRequestedAt, isNotNull);
      expect(entry.lastRequestedAt!.isAfter(originalDate), isTrue);
    });
  });

  group('getPendingEntriesByPayloadId Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns empty list when no entries exist', () async {
      final database = db!;
      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: 'non-existent',
      );
      expect(entries, isEmpty);
    });

    test('returns pending entries matching payloadType and payloadId',
        () async {
      final database = db!;
      const entryId = 'test-entry';
      final now = DateTime(2024, 1, 1);

      // Add pending entry with matching payload
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value(entryId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: entryId,
      );
      expect(entries, hasLength(1));
      expect(entries.first.entryId, entryId);
    });

    test('filters by payloadType - journalEntity vs entryLink', () async {
      final database = db!;
      const payloadId = 'shared-id';
      final now = DateTime(2024, 1, 1);

      // Add journalEntity entry
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add entryLink entry with same payloadId
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.entryLink.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Query for journalEntity
      final journalEntries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: payloadId,
      );
      expect(journalEntries, hasLength(1));
      expect(journalEntries.first.hostId, 'host-1');

      // Query for entryLink
      final linkEntries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: payloadId,
      );
      expect(linkEntries, hasLength(1));
      expect(linkEntries.first.hostId, 'host-2');
    });

    test('returns only missing or requested status entries', () async {
      final database = db!;
      const payloadId = 'test-entry';
      final now = DateTime(2024, 1, 1);

      // Add received entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add missing entry (should be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add requested entry (should be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-3'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add backfilled entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-4'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add deleted entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-5'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.deleted.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: payloadId,
      );
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.hostId).toSet(),
        {'host-2', 'host-3'},
      );
    });

    test('getPendingEntriesByEntryId delegates to getPendingEntriesByPayloadId',
        () async {
      final database = db!;
      const entryId = 'journal-entry-1';
      final now = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(5),
          entryId: const Value(entryId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // getPendingEntriesByEntryId should find the entry
      final entries = await database.getPendingEntriesByEntryId(entryId);
      expect(entries, hasLength(1));
      expect(entries.first.entryId, entryId);
      expect(
        entries.first.payloadType,
        SyncSequencePayloadType.journalEntity.index,
      );
    });

    test('returns multiple entries across different hosts', () async {
      final database = db!;
      const payloadId = 'link-id';
      final now = DateTime(2024, 1, 1);

      // Add entries from multiple hosts for the same payload
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value('host-$i'),
            counter: Value(i * 10),
            entryId: const Value(payloadId),
            payloadType: Value(SyncSequencePayloadType.entryLink.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: payloadId,
      );
      expect(entries, hasLength(3));
      expect(
        entries.map((e) => e.hostId).toSet(),
        {'host-1', 'host-2', 'host-3'},
      );
    });
  });
}
