// Tests for sequence-log recording, lookups, and host activity
// (`lib/database/sync_db_sequence.dart`), including the persisted
// contiguous-prefix watermark behavior backed by
// `lib/database/sync_db_watermarks.dart`.
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

void main() {
  SyncDatabase? db;

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

    test(
      'getLastCounterForHost returns highest contiguous resolved counter',
      () async {
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
      },
    );

    test(
      'getLastCounterForHost reads the persisted host watermark',
      () async {
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
        await database.customStatement('ANALYZE');

        final watermarkRows = await database
            .customSelect(
              'SELECT last_counter FROM sync_sequence_watermarks '
              'WHERE host_id = ?',
              variables: [Variable.withString(hostId)],
            )
            .get();
        expect(watermarkRows, hasLength(1));
        expect(watermarkRows.first.read<int>('last_counter'), 5);
        expect(await database.getLastCounterForHost(hostId), 5);

        final plan = await database
            .customSelect(
              '''
              EXPLAIN QUERY PLAN
              SELECT last_counter
              FROM sync_sequence_watermarks
              WHERE host_id = ?
              ''',
              variables: [
                Variable.withString(hostId),
              ],
            )
            .get();
        final details = plan.map((row) => row.data.toString()).join('\n');

        expect(
          details,
          contains('sqlite_autoindex_sync_sequence_watermarks_1'),
          reason:
              'the hot watermark path should be a primary-key lookup against '
              'the persisted watermark table, not a ROW_NUMBER scan over the '
              'host sequence log',
        );
      },
    );

    test(
      'getLastCounterForHost lazily warms the persisted watermark for '
      'pre-v23 rows',
      () async {
        final database = db!;
        const hostId = 'legacy-host';

        for (final counter in [1, 2, 3]) {
          await database.customUpdate(
            'INSERT INTO sync_sequence_log '
            '(host_id, counter, status, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(hostId),
              Variable.withInt(counter),
              Variable.withInt(SyncSequenceStatus.received.index),
              Variable.withDateTime(DateTime(2024, 1, counter)),
              Variable.withDateTime(DateTime(2024, 1, counter)),
            ],
            updates: {database.syncSequenceLog},
          );
        }

        expect(
          await database
              .customSelect(
                'SELECT * FROM sync_sequence_watermarks WHERE host_id = ?',
                variables: [Variable.withString(hostId)],
              )
              .get(),
          isEmpty,
        );

        expect(await database.getLastCounterForHost(hostId), 3);

        final watermark = await database
            .customSelect(
              'SELECT last_counter FROM sync_sequence_watermarks '
              'WHERE host_id = ?',
              variables: [Variable.withString(hostId)],
            )
            .getSingle();
        expect(watermark.read<int>('last_counter'), 3);
      },
    );

    test('getLastCounterForHost stops at first unresolved gap', () async {
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
          status: Value(SyncSequenceStatus.backfilled.index),
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
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final lastCounter = await database.getLastCounterForHost(hostId);
      expect(lastCounter, 2);
    });

    test(
      'getLastCounterForHost lowers the persisted watermark when a '
      'previously resolved row is reopened',
      () async {
        final database = db!;
        const hostId = 'host-reopened';

        for (var counter = 1; counter <= 4; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(DateTime(2024, 1, counter)),
              updatedAt: Value(DateTime(2024, 1, counter)),
            ),
          );
        }
        expect(await database.getLastCounterForHost(hostId), 4);

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(2),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(DateTime(2024, 1, 2)),
            updatedAt: Value(DateTime(2024, 1, 5)),
          ),
        );

        expect(await database.getLastCounterForHost(hostId), 1);
        final watermark = await database
            .customSelect(
              'SELECT last_counter FROM sync_sequence_watermarks '
              'WHERE host_id = ?',
              variables: [Variable.withString(hostId)],
            )
            .getSingle();
        expect(watermark.read<int>('last_counter'), 1);
      },
    );

    test('getLastCounterForHost returns null for unknown host', () async {
      final database = db!;
      final lastCounter = await database.getLastCounterForHost('unknown');
      expect(lastCounter, isNull);
    });

    test(
      'getLastCounterForHost returns 0 when host rows start above counter 1',
      () async {
        final database = db!;
        const hostId = 'host-1';

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(5),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, 5)),
            updatedAt: Value(DateTime(2024, 1, 5)),
          ),
        );

        final lastCounter = await database.getLastCounterForHost(hostId);
        expect(lastCounter, 0);
      },
    );

    test(
      'getLastCounterForHost plan uses the resolved-host partial index '
      'without sorting through missing/requested rows',
      () async {
        final database = db!;
        const hostId = 'host-plan';

        for (var counter = 1; counter <= 50; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              status: Value(
                counter.isEven
                    ? SyncSequenceStatus.received.index
                    : SyncSequenceStatus.missing.index,
              ),
              createdAt: Value(DateTime(2024, 1, 1)),
              updatedAt: Value(DateTime(2024, 1, 1)),
            ),
          );
        }
        await database.customStatement('ANALYZE');

        final plan = await database
            .customSelect(
              '''
              EXPLAIN QUERY PLAN
              WITH resolved_prefix AS (
                SELECT
                  counter,
                  ROW_NUMBER() OVER (ORDER BY counter) AS rn
                FROM sync_sequence_log
                WHERE host_id = ?
                  AND status IN (0, 3, 4, 5, 8)
              )
              SELECT CASE
                WHEN NOT EXISTS (
                  SELECT 1 FROM sync_sequence_log WHERE host_id = ? LIMIT 1
                ) THEN NULL
                ELSE COALESCE(
                  (
                    SELECT MAX(counter)
                    FROM resolved_prefix
                    WHERE counter = rn
                  ),
                  0
                )
              END AS last_counter
              ''',
              variables: [
                Variable.withString(hostId),
                Variable.withString(hostId),
              ],
            )
            .get();
        final details = plan.map((r) => r.data.toString()).join('\n');

        expect(
          details,
          contains('idx_sync_sequence_log_resolved_host_counter'),
          reason:
              'the resolved-prefix scan must use the literal-status partial '
              'index rather than reading every row for the host',
        );
        expect(
          details,
          isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
          reason:
              'the partial index is already ordered by host_id/counter, so '
              'the window should not need an external sort',
        );
      },
    );

    test(
      'reserved counters do not advance the contiguous resolved watermark',
      () async {
        final database = db!;
        const hostId = 'host-reserved';

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2026, 5, 24, 11)),
            updatedAt: Value(DateTime(2026, 5, 24, 11)),
          ),
        );
        await database.recordReservedSequenceCounter(
          hostId: hostId,
          counter: 2,
          now: DateTime(2026, 5, 24, 11, 1),
        );
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(3),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2026, 5, 24, 11, 2)),
            updatedAt: Value(DateTime(2026, 5, 24, 11, 2)),
          ),
        );

        expect(await database.getLastCounterForHost(hostId), 1);
        expect(await database.reservedSequenceCountersForHost(hostId: hostId), [
          2,
        ]);

        await database.updateSequenceStatus(
          hostId,
          2,
          SyncSequenceStatus.unresolvable,
        );

        expect(await database.getLastCounterForHost(hostId), 3);
      },
    );

    test(
      'resolved status literals used by getLastCounterForHost stay aligned '
      'with SyncSequenceStatus enum indices',
      () {
        expect(SyncSequenceStatus.received.index, 0);
        expect(SyncSequenceStatus.backfilled.index, 3);
        expect(SyncSequenceStatus.deleted.index, 4);
        expect(SyncSequenceStatus.unresolvable.index, 5);
        expect(SyncSequenceStatus.reserved.index, 6);
        expect(SyncSequenceStatus.burnPending.index, 7);
      },
    );

    test(
      'getCountersForHostInRange returns only counters inside range',
      () async {
        final database = db!;
        const hostId = 'host-1';

        for (final counter in [1, 3, 5]) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(DateTime(2024, 1, counter)),
              updatedAt: Value(DateTime(2024, 1, counter)),
            ),
          );
        }

        final counters = await database.getCountersForHostInRange(hostId, 2, 4);
        expect(counters, {3});
      },
    );

    test(
      'getCountersForHostInRange returns empty set for invalid range',
      () async {
        final database = db!;

        final counters = await database.getCountersForHostInRange(
          'host-1',
          5,
          4,
        );
        expect(counters, isEmpty);
      },
    );

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

    test(
      'getMissingEntries honors minAge — rows created more recently '
      'than now-minAge are held back so a short-lived gap caused by '
      'out-of-order priority messages can resolve via standard sync '
      'before backfill fires',
      () async {
        final database = db!;
        const hostId = 'host-1';
        final now = DateTime(2024, 1, 2, 12);

        // Fresh: 1 minute old — within the 10-minute debounce window.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 1))),
            updatedAt: Value(now.subtract(const Duration(minutes: 1))),
          ),
        );
        // Ripe: 15 minutes old — past the window.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(2),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 15))),
            updatedAt: Value(now.subtract(const Duration(minutes: 15))),
          ),
        );

        final ripe = await database.getMissingEntries(
          minAge: const Duration(minutes: 10),
          now: now,
        );
        expect(ripe, hasLength(1));
        expect(ripe.single.counter, 2);

        // Without debounce, both rows are eligible. Ordering is by
        // created_at ASC, so the older row (counter 2) comes first.
        final all = await database.getMissingEntries(now: now);
        expect(all.map((e) => e.counter), [2, 1]);
      },
    );

    test(
      'getMissingEntriesWithLimits honors minAge alongside the maxAge / '
      'maxPerHost gates',
      () async {
        final database = db!;
        const hostId = 'host-1';
        final now = DateTime(2024, 1, 2, 12);

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 1))),
            updatedAt: Value(now.subtract(const Duration(minutes: 1))),
          ),
        );
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(2),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 15))),
            updatedAt: Value(now.subtract(const Duration(minutes: 15))),
          ),
        );

        final ripe = await database.getMissingEntriesWithLimits(
          minAge: const Duration(minutes: 10),
          now: now,
        );
        expect(ripe, hasLength(1));
        expect(ripe.single.counter, 2);
      },
    );

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

    test('getSequenceLogCount returns total count of entries', () async {
      final database = db!;

      // Initial count should be 0
      expect(await database.getSequenceLogCount(), 0);

      // Add entries with various statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      expect(await database.getSequenceLogCount(), 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      expect(await database.getSequenceLogCount(), 2);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      expect(await database.getSequenceLogCount(), 3);
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

  group('getNearestCoveringEntry Tests', () {
    late SyncDatabase database;

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
      database = db!;
    });

    tearDown(() async {
      await db?.close();
    });

    test('returns null when no entries exist', () async {
      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test(
      'returns entry with counter >= requested and received status',
      () async {
        await database.batchInsertSequenceEntries([
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: const Value(7),
            status: Value(SyncSequenceStatus.received.index),
            entryId: const Value('entry-7'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            createdAt: Value(DateTime(2024, 3, 15)),
            updatedAt: Value(DateTime(2024, 3, 15)),
          ),
        ]);

        final result = await database.getNearestCoveringEntry('host-1', 5);
        expect(result, isNotNull);
        expect(result!.counter, 7);
        expect(result.entryId, 'entry-7');
      },
    );

    test('returns entry with backfilled status', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.backfilled.index),
          entryId: const Value('entry-10'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 10);
      expect(result.entryId, 'entry-10');
    });

    test('skips hint-only requested rows', () async {
      // A requested row with entryId is a hint — payload may not exist locally
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.requested.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips missing rows with entryId', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.missing.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips rows without entryId', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('returns nearest (lowest counter) covering entry', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-10'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-7'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 7);
      expect(result.entryId, 'entry-7');
    });

    test('does not return entry for different host', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-7'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('does not return entry with counter below requested', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-3'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips lower requested row and returns higher received row', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.requested.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('real-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 10);
      expect(result.entryId, 'real-entry');
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

    test(
      'returns pending entries matching payloadType and payloadId',
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
      },
    );

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

  group('getLastSentCounterForEntry', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'returns null when no entries exist for the host/entry pair',
      () async {
        final database = db!;
        final result = await database.getLastSentCounterForEntry(
          'host-1',
          'entry-1',
        );
        expect(result, isNull);
      },
    );

    test('returns the highest counter for a received entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      // Insert two received entries for the same entryId at different counters
      for (final counter in [10, 15, 20]) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(counter),
            entryId: const Value(entryId),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, counter)),
            updatedAt: Value(DateTime(2024, 1, counter)),
          ),
        );
      }

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 20);
    });

    test('includes backfilled entries in the result', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(25),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 25);
    });

    test('excludes missing and requested entries', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      // Higher counter but missing — should not be returned
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(30),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      // Higher counter but requested — should not be returned
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(40),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 10);
    });

    test('does not cross entry boundaries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Entry A at counter 10
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value('entry-a'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      // Entry B at counter 50
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(50),
          entryId: const Value('entry-b'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final resultA = await database.getLastSentCounterForEntry(
        hostId,
        'entry-a',
      );
      expect(resultA, 10);

      final resultB = await database.getLastSentCounterForEntry(
        hostId,
        'entry-b',
      );
      expect(resultB, 50);
    });

    test(
      'returns the highest counter even when intervening rows are not '
      'ordered by insertion, exercising the ORDER BY DESC LIMIT 1 path',
      () async {
        final database = db!;
        const hostId = 'host-shuffle';
        const entryId = 'entry-shuffle';

        // Insert out-of-order counters for the same (host, entry) with mixed
        // statuses. The rewritten query must still return the max received
        // counter (33), not the max overall (77 is missing and must not win).
        final rows = <({int counter, SyncSequenceStatus status})>[
          (counter: 12, status: SyncSequenceStatus.received),
          (counter: 33, status: SyncSequenceStatus.backfilled),
          (counter: 5, status: SyncSequenceStatus.received),
          (counter: 77, status: SyncSequenceStatus.missing),
          (counter: 21, status: SyncSequenceStatus.received),
          (counter: 100, status: SyncSequenceStatus.requested),
        ];
        for (final row in rows) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(row.counter),
              entryId: const Value(entryId),
              status: Value(row.status.index),
              createdAt: Value(DateTime(2024, 6, 1)),
              updatedAt: Value(DateTime(2024, 6, 1)),
            ),
          );
        }

        expect(
          await database.getLastSentCounterForEntry(hostId, entryId),
          33,
        );
      },
    );
  });

  group('recordOwnUnresolvableSequenceCounter - default now -', () {
    // Exercises the `now ?? DateTime.now()` branch at line 1096.
    test('records burned row when called without explicit now', () async {
      final database = SyncDatabase(inMemoryDatabase: true);
      try {
        const hostId = 'burn-default-now-host';
        const counter = 1;

        final recorded = await database.recordOwnUnresolvableSequenceCounter(
          hostId: hostId,
          counter: counter,
          // Deliberately omit `now:` to exercise the default branch.
        );

        expect(recorded, isTrue);
        final row = await database.getEntryByHostAndCounter(hostId, counter);
        expect(row, isNotNull);
        expect(row!.status, SyncSequenceStatus.burned.index);
        expect(row.entryId, isNull);
      } finally {
        await database.close();
      }
    });
  });

  group('recordSequenceEntry - status fallback in watermark refresh -', () {
    // Exercises line 1399: the `else` branch of
    // `entry.status.present ? ... : SyncSequenceStatus.received.index`
    // inside `_refreshSequenceWatermarkAfterMutation`. When a companion
    // is inserted without an explicit `status`, the helper must treat it
    // as `received` for watermark purposes.
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await database.close();
    });

    test(
      'entry without explicit status defaults to received for watermark',
      () async {
        const hostId = 'status-fallback-host';
        final now = DateTime(2024, 3, 15, 12);

        // Insert a companion where `status` is absent — relies on the DB
        // default (received = 0) for the actual row and on the fallback
        // branch for the watermark refresh.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            entryId: const Value('entry-fallback'),
            createdAt: Value(now),
            updatedAt: Value(now),
            // status intentionally omitted
          ),
        );

        final row = await database.getEntryByHostAndCounter(hostId, 1);
        expect(row, isNotNull);
        // The DB default maps to received (index 0).
        expect(row!.status, SyncSequenceStatus.received.index);

        // Watermark must advance to 1 because counter 1 was received.
        expect(await database.getLastCounterForHost(hostId), 1);
      },
    );
  });

  group('getCountersForHostInRange', () {
    late SyncDatabase database;

    setUp(() {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    SyncSequenceLogCompanion entry(String hostId, int counter) =>
        SyncSequenceLogCompanion.insert(
          hostId: hostId,
          counter: counter,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
        );

    test('returns the intersection of stored counters and the range', () async {
      await database.batchInsertSequenceEntries([
        entry('host-a', 1),
        entry('host-a', 2),
        entry('host-a', 5),
        entry('host-a', 9),
        // Different host inside the range must not leak in.
        entry('host-b', 3),
      ]);

      final counters = await database.getCountersForHostInRange(
        'host-a',
        2,
        6,
      );

      expect(counters, {2, 5});
    });

    test('range bounds are inclusive on both ends', () async {
      await database.batchInsertSequenceEntries([
        entry('host-a', 4),
        entry('host-a', 7),
      ]);

      expect(
        await database.getCountersForHostInRange('host-a', 4, 7),
        {4, 7},
      );
    });

    test('returns empty set when endCounter < startCounter', () async {
      await database.batchInsertSequenceEntries([entry('host-a', 4)]);
      expect(
        await database.getCountersForHostInRange('host-a', 5, 4),
        isEmpty,
      );
    });
  });
}
