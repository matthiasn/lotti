// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';

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
}
