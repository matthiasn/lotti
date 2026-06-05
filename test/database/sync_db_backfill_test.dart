// Tests for the backfill sweep queries and statistics
// (`lib/database/sync_db_backfill.dart`).
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';

class _MissingRowSpec {
  const _MissingRowSpec({
    required this.hostIndex,
    required this.status,
    required this.requestCount,
    required this.createdDay,
  });

  final int hostIndex;
  final SyncSequenceStatus status;
  final int requestCount;
  final int createdDay;
}

class _MissingLimitsScenario {
  const _MissingLimitsScenario({
    required this.rows,
    required this.maxPerHost,
    required this.offset,
    required this.limit,
  });

  final List<_MissingRowSpec> rows;
  final int? maxPerHost;
  final int offset;
  final int limit;
}

extension _AnyMissingLimitsScenario on Any {
  Generator<_MissingRowSpec> get missingRowSpec => combine4(
    intInRange(0, 4),
    choose(const [
      SyncSequenceStatus.missing,
      SyncSequenceStatus.requested,
      SyncSequenceStatus.received,
    ]),
    intInRange(0, 13),
    intInRange(1, 10),
    (
      int hostIndex,
      SyncSequenceStatus status,
      int requestCount,
      int createdDay,
    ) => _MissingRowSpec(
      hostIndex: hostIndex,
      status: status,
      requestCount: requestCount,
      createdDay: createdDay,
    ),
  );

  Generator<_MissingLimitsScenario> get missingLimitsScenario => combine4(
    listWithLengthInRange(0, 14, missingRowSpec),
    intInRange(0, 4).map((v) => v == 0 ? null : v),
    intInRange(0, 4),
    intInRange(1, 9),
    (List<_MissingRowSpec> rows, int? maxPerHost, int offset, int limit) =>
        _MissingLimitsScenario(
          rows: rows,
          maxPerHost: maxPerHost,
          offset: offset,
          limit: limit,
        ),
  );
}

Future<void> _insertSequenceRow(
  SyncDatabase database, {
  required String hostId,
  required int counter,
  required SyncSequenceStatus status,
  required DateTime createdAt,
}) {
  return database.recordSequenceEntry(
    SyncSequenceLogCompanion(
      hostId: Value(hostId),
      counter: Value(counter),
      status: Value(status.index),
      createdAt: Value(createdAt),
      updatedAt: Value(createdAt),
    ),
  );
}

void main() {
  SyncDatabase? db;

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
      expect(stats.hostStats.first.receivedCount, 2);
      expect(stats.hostStats.first.missingCount, 1);
      expect(stats.hostStats.first.backfilledCount, 1);

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

    test('counts unresolvable entries correctly', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses including unresolvable
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
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.deleted.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(1));
      expect(stats.hostStats.first.receivedCount, 1);
      expect(stats.hostStats.first.unresolvableCount, 2);
      expect(stats.hostStats.first.deletedCount, 1);
      expect(stats.totalUnresolvable, 2);
      expect(stats.totalDeleted, 1);
    });

    test('counts burned entries separately from unresolvable', () async {
      final database = db!;
      const hostId = 'host-1';

      Future<void> add(int counter, SyncSequenceStatus status) {
        return database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(counter),
            status: Value(status.index),
            createdAt: Value(DateTime(2024, 3, counter)),
            updatedAt: Value(DateTime(2024, 3, counter)),
          ),
        );
      }

      await add(1, SyncSequenceStatus.unresolvable);
      await add(2, SyncSequenceStatus.burned);
      await add(3, SyncSequenceStatus.burned);
      await add(4, SyncSequenceStatus.burned);

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(1));
      expect(stats.hostStats.first.unresolvableCount, 1);
      expect(stats.hostStats.first.burnedCount, 3);
      // Burned is its own bucket — it must NOT inflate unresolvable.
      expect(stats.totalUnresolvable, 1);
      expect(stats.totalBurned, 3);
      expect(stats.totalEntries, 4);
    });
  });

  group('hasActionableEntries Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'returns false when sync_sequence_log is empty, so the periodic '
      'backfill timer can skip the retire + load body when nothing is '
      'missing (see BackfillRequestService._processBackfillRequests)',
      () async {
        final database = db!;

        expect(await database.hasActionableEntries(), isFalse);
      },
    );

    test(
      'returns false when only terminal-status rows exist (received / '
      'backfilled / deleted / unresolvable), since none of those need a '
      'backfill request',
      () async {
        final database = db!;
        const hostId = 'host-1';

        for (final status in <SyncSequenceStatus>[
          SyncSequenceStatus.received,
          SyncSequenceStatus.backfilled,
          SyncSequenceStatus.deleted,
          SyncSequenceStatus.unresolvable,
        ]) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(status.index),
              status: Value(status.index),
              createdAt: Value(DateTime(2024, status.index + 1)),
              updatedAt: Value(DateTime(2024, status.index + 1)),
            ),
          );
        }

        expect(await database.hasActionableEntries(), isFalse);
      },
    );

    test('returns true when any row is in `missing` status', () async {
      final database = db!;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 3, 1)),
          updatedAt: Value(DateTime(2024, 3, 1)),
        ),
      );

      expect(await database.hasActionableEntries(), isTrue);
    });

    test('returns true when any row is in `requested` status', () async {
      final database = db!;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 3, 1)),
          updatedAt: Value(DateTime(2024, 3, 1)),
        ),
      );

      expect(await database.hasActionableEntries(), isTrue);
    });

    test(
      'plan uses the actionable partial index '
      '(idx_sync_sequence_log_actionable_status_created_at) so the probe '
      'stays O(log n) on the index regardless of how many terminal rows '
      'have accumulated — this is the load-bearing assumption of the '
      'early-exit gate in BackfillRequestService',
      () async {
        final database = db!;

        // Seed enough rows that the planner could be tempted to scan the
        // base table; the partial index must still win.
        for (var i = 0; i < 200; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('host-bulk'),
              counter: Value(i),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(DateTime(2024, 1, 1).add(Duration(minutes: i))),
              updatedAt: Value(DateTime(2024, 1, 1).add(Duration(minutes: i))),
            ),
          );
        }
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-bulk'),
            counter: const Value(9999),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 2, 1)),
            updatedAt: Value(DateTime(2024, 2, 1)),
          ),
        );

        final rows = await database
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT 1 FROM sync_sequence_log '
              'WHERE status IN (1, 2) LIMIT 1',
            )
            .get();
        final plan = rows.map((r) => r.data.toString()).join('\n');

        // Either of the two actionable partial indices is acceptable —
        // both are declared `WHERE status IN (1, 2)` (see
        // `idx_sync_sequence_log_actionable_status_created_at` and
        // `idx_sync_sequence_log_actionable_status_updated_at` in
        // `lib/database/sync_db.dart`). What we care about is that the
        // planner does NOT fall back to a full base-table scan.
        expect(
          plan,
          matches(
            RegExp(
              'idx_sync_sequence_log_actionable_status_'
              '(created_at|updated_at)',
            ),
          ),
          reason:
              'probe must match an actionable partial index, not SCAN sync_sequence_log',
        );
        expect(
          plan,
          isNot(matches(RegExp('SCAN sync_sequence_log(?! USING)'))),
          reason: 'probe must never fall back to a base-table scan',
        );
        expect(
          await database.hasActionableEntries(),
          isTrue,
          reason: 'one missing row among 200 terminals must still register',
        );
      },
    );

    test(
      'status literals (1, 2) baked into the partial-index match used '
      'by hasActionableEntries stay in sync with '
      'SyncSequenceStatus.missing.index and .requested.index — '
      '`customSelect` cannot reference the enum at compile time, so a '
      'future enum reorder would silently probe the wrong rows. This '
      'guard fails loudly instead (mirrors the OutboxStatus guard at '
      'the end of this group).',
      () {
        expect(
          SyncSequenceStatus.missing.index,
          1,
          reason:
              'missing must be index 1 — used as a literal in the '
              'hasActionableEntries / partial-index WHERE clauses.',
        );
        expect(
          SyncSequenceStatus.requested.index,
          2,
          reason:
              'requested must be index 2 — used as a literal in the '
              'hasActionableEntries / partial-index WHERE clauses.',
        );
      },
    );
  });

  group('getMissingEntriesWithLimits Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    Glados(any.missingLimitsScenario, ExploreConfig(numRuns: 40)).test(
      'per-host cap, offset, limit, and actionability invariants hold for '
      'arbitrary row sets',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        try {
          const maxRequestCount = 10;
          await database.batchInsertSequenceEntries([
            for (var i = 0; i < scenario.rows.length; i++)
              SyncSequenceLogCompanion(
                hostId: Value('host-${scenario.rows[i].hostIndex}'),
                counter: Value(i + 1),
                status: Value(scenario.rows[i].status.index),
                requestCount: Value(scenario.rows[i].requestCount),
                createdAt: Value(
                  DateTime(2024, 1, scenario.rows[i].createdDay, i),
                ),
                updatedAt: Value(
                  DateTime(2024, 1, scenario.rows[i].createdDay, i),
                ),
              ),
          ]);

          final result = await database.getMissingEntriesWithLimits(
            limit: scenario.limit,
            offset: scenario.offset,
            maxPerHost: scenario.maxPerHost,
          );

          // (a) Total result is bounded by limit.
          expect(result.length, lessThanOrEqualTo(scenario.limit));

          // (b) Only actionable rows under the request-count cap come back.
          for (final row in result) {
            expect(
              row.status,
              anyOf(
                SyncSequenceStatus.missing.index,
                SyncSequenceStatus.requested.index,
              ),
            );
            expect(row.requestCount, lessThan(maxRequestCount));
          }

          // (c) No host exceeds maxPerHost.
          final cap = scenario.maxPerHost;
          if (cap != null) {
            final perHost = <String, int>{};
            for (final row in result) {
              perHost.update(row.hostId, (v) => v + 1, ifAbsent: () => 1);
            }
            for (final count in perHost.values) {
              expect(count, lessThanOrEqualTo(cap));
            }
          }

          // (d) Rows are ordered by creation time.
          for (var i = 1; i < result.length; i++) {
            expect(
              result[i].createdAt.isBefore(result[i - 1].createdAt),
              isFalse,
            );
          }

          // (e) Offset slices the same underlying ordering: fetching with
          // offset k equals fetching from 0 and dropping the first k rows.
          final unsliced = await database.getMissingEntriesWithLimits(
            limit: scenario.offset + scenario.limit,
            maxPerHost: scenario.maxPerHost,
          );
          expect(
            result.map((row) => (row.hostId, row.counter)).toList(),
            unsliced
                .skip(scenario.offset)
                .map((row) => (row.hostId, row.counter))
                .toList(),
          );
        } finally {
          await database.close();
        }
      },
      tags: 'glados',
    );

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
      final now = DateTime(2024, 1, 3, 12);

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
        now: now,
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

    test('supports offset after filtering', () async {
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

      final missing = await database.getMissingEntriesWithLimits(
        limit: 2,
        offset: 2,
      );
      expect(missing.map((e) => e.counter).toList(), [3, 4]);
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
      final now = DateTime(2024, 1, 3, 12);

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
        now: now,
      );

      // Only host-1 entries (maxAge filters host-2)
      // maxPerHost limits to 3
      // overall limit is 5 but maxPerHost restricts to 3
      expect(missing, hasLength(3));
      expect(missing.every((e) => e.hostId == 'host-1'), isTrue);
    });

    test('breaks created_at ties by (host_id, counter), including the '
        'in-memory maxPerHost merge', () async {
      final database = db!;
      final sameSecond = DateTime(2024, 1, 15, 12);
      final shuffled = [
        (hostId: 'host-b', counter: 5),
        (hostId: 'host-a', counter: 8),
        (hostId: 'host-b', counter: 2),
        (hostId: 'host-a', counter: 4),
      ];
      for (final row in shuffled) {
        await _insertSequenceRow(
          database,
          hostId: row.hostId,
          counter: row.counter,
          status: SyncSequenceStatus.missing,
          createdAt: sameSecond,
        );
      }

      // SQL path (no per-host cap).
      final unlimited = await database.getMissingEntriesWithLimits();
      expect(
        unlimited.map((e) => (e.hostId, e.counter)).toList(),
        [('host-a', 4), ('host-a', 8), ('host-b', 2), ('host-b', 5)],
      );

      // In-memory merge path: maxPerHost keeps the first row per host and
      // the merged result stays tuple-ordered.
      final capped = await database.getMissingEntriesWithLimits(
        maxPerHost: 1,
      );
      expect(
        capped.map((e) => (e.hostId, e.counter)).toList(),
        [('host-a', 4), ('host-b', 2)],
      );

      // With both same-second rows of a host surviving the cap, the merge
      // sort has to fall through to the counter tie-breaker.
      final cappedTwo = await database.getMissingEntriesWithLimits(
        maxPerHost: 2,
      );
      expect(
        cappedTwo.map((e) => (e.hostId, e.counter)).toList(),
        [('host-a', 4), ('host-a', 8), ('host-b', 2), ('host-b', 5)],
      );
    });
  });

  group('getMissingEntries ordering Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('breaks created_at ties by (host_id, counter) so LIMIT/OFFSET '
        'sweeps stay stable', () async {
      final database = db!;
      final sameSecond = DateTime(2024, 1, 15, 12);
      final shuffled = [
        (hostId: 'host-b', counter: 7),
        (hostId: 'host-a', counter: 6),
        (hostId: 'host-b', counter: 3),
        (hostId: 'host-a', counter: 1),
      ];
      for (final row in shuffled) {
        await _insertSequenceRow(
          database,
          hostId: row.hostId,
          counter: row.counter,
          status: SyncSequenceStatus.missing,
          createdAt: sameSecond,
        );
      }

      final all = await database.getMissingEntries();
      expect(
        all.map((e) => (e.hostId, e.counter)).toList(),
        [('host-a', 1), ('host-a', 6), ('host-b', 3), ('host-b', 7)],
      );

      final page1 = await database.getMissingEntries(limit: 2);
      final page2 = await database.getMissingEntries(limit: 2, offset: 2);
      expect(
        [...page1, ...page2].map((e) => (e.hostId, e.counter)).toList(),
        all.map((e) => (e.hostId, e.counter)).toList(),
      );
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

    test('supports offset parameter', () async {
      final database = db!;
      const hostId = 'host-1';

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

      final requested = await database.getRequestedEntries(limit: 2, offset: 2);
      expect(requested.map((e) => e.counter).toList(), [3, 4]);
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

    test('breaks created_at ties by (host_id, counter) so LIMIT/OFFSET '
        'pages neither skip nor duplicate rows', () async {
      final database = db!;
      // created_at is stored as Unix seconds, so same-second rows are
      // common in production. Insert in shuffled order to prove the
      // ordering comes from the query, not insertion order.
      final sameSecond = DateTime(2024, 1, 15, 12);
      final shuffled = [
        (hostId: 'host-b', counter: 2),
        (hostId: 'host-a', counter: 9),
        (hostId: 'host-b', counter: 1),
        (hostId: 'host-a', counter: 3),
      ];
      for (final row in shuffled) {
        await _insertSequenceRow(
          database,
          hostId: row.hostId,
          counter: row.counter,
          status: SyncSequenceStatus.requested,
          createdAt: sameSecond,
        );
      }

      final all = await database.getRequestedEntries();
      expect(
        all.map((e) => (e.hostId, e.counter)).toList(),
        [('host-a', 3), ('host-a', 9), ('host-b', 1), ('host-b', 2)],
      );

      // Paging through the same data reassembles the full sequence.
      final page1 = await database.getRequestedEntries(limit: 2);
      final page2 = await database.getRequestedEntries(limit: 2, offset: 2);
      expect(
        [...page1, ...page2].map((e) => (e.hostId, e.counter)).toList(),
        all.map((e) => (e.hostId, e.counter)).toList(),
      );
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

    test('invalidates sync_sequence_log stream queries (raw SQL declares '
        'its table update explicitly)', () async {
      final database = db!;
      await _insertSequenceRow(
        database,
        hostId: 'host-1',
        counter: 1,
        status: SyncSequenceStatus.missing,
        createdAt: DateTime(2024, 1, 15),
      );

      // Subscribe before the write; resolves only if drift re-runs the
      // watch query after the batch (raw customStatement updates are not
      // inferred automatically, so this hangs without the explicit
      // TableUpdate declaration).
      final updated = database
          .select(database.syncSequenceLog)
          .watch()
          .firstWhere(
            (rows) => rows.any(
              (row) =>
                  row.requestCount == 1 &&
                  row.status == SyncSequenceStatus.requested.index,
            ),
          );

      await database.batchIncrementRequestCounts([
        (hostId: 'host-1', counter: 1),
      ]);

      final rows = await updated;
      expect(rows.single.requestCount, 1);
      expect(rows.single.status, SyncSequenceStatus.requested.index);
    });

    test(
      'does not revert rows that resolved between selection and the batch '
      'write',
      () async {
        final database = db!;
        final base = DateTime(2024, 3, 15, 10);
        await database.batchInsertSequenceEntries([
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
          // Resolved while the backfill sweep was preparing its batch.
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: const Value(2),
            entryId: const Value('entry-2'),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
        ]);

        await database.batchIncrementRequestCounts([
          (hostId: 'host-1', counter: 1),
          (hostId: 'host-1', counter: 2),
        ]);

        final actionable = await database.getEntryByHostAndCounter(
          'host-1',
          1,
        );
        expect(actionable!.status, SyncSequenceStatus.requested.index);
        expect(actionable.requestCount, 1);

        final resolved = await database.getEntryByHostAndCounter(
          'host-1',
          2,
        );
        // The guard must leave the resolved row untouched.
        expect(resolved!.status, SyncSequenceStatus.received.index);
        expect(resolved.requestCount, 0);
        expect(resolved.lastRequestedAt, isNull);
      },
    );

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
}
