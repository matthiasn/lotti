// Tests for the outbox queue engine (`lib/database/sync_db_outbox.dart`).
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:glados/glados.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import 'sync_db_test_utils.dart';

class _OutboxClaimRowSpec {
  const _OutboxClaimRowSpec({
    required this.createdMinute,
    required this.hasMedia,
    required this.status,
  });

  final int createdMinute;
  final bool hasMedia;
  final GeneratedOutboxStatus status;

  DateTime createdAt(DateTime base) =>
      base.add(Duration(minutes: createdMinute));

  OutboxStatus get dbStatus => switch (status) {
    GeneratedOutboxStatus.pending => OutboxStatus.pending,
    GeneratedOutboxStatus.expiredSending => OutboxStatus.sending,
    GeneratedOutboxStatus.activeSending => OutboxStatus.sending,
    GeneratedOutboxStatus.sent => OutboxStatus.sent,
    GeneratedOutboxStatus.error => OutboxStatus.error,
  };

  DateTime updatedAt(DateTime base, DateTime now) => switch (status) {
    GeneratedOutboxStatus.expiredSending => now.subtract(
      const Duration(minutes: 10),
    ),
    GeneratedOutboxStatus.activeSending => now,
    _ => createdAt(base),
  };
}

class _OutboxClaimScenario {
  const _OutboxClaimScenario({
    required this.maxSize,
    required this.rows,
  });

  final int maxSize;
  final List<_OutboxClaimRowSpec> rows;
}

class _OutboxClaimModelRow {
  const _OutboxClaimModelRow({
    required this.id,
    required this.spec,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final _OutboxClaimRowSpec spec;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => spec.status == GeneratedOutboxStatus.pending;

  bool get isExpiredSending =>
      spec.status == GeneratedOutboxStatus.expiredSending;

  bool get hasMedia => spec.hasMedia;
}

extension _AnyOutboxClaimScenario on Any {
  Generator<_OutboxClaimRowSpec> get outboxClaimRowSpec => combine3(
    intInRange(0, 6),
    any.bool,
    any.generatedOutboxStatus,
    (int createdMinute, bool hasMedia, GeneratedOutboxStatus status) =>
        _OutboxClaimRowSpec(
          createdMinute: createdMinute,
          hasMedia: hasMedia,
          status: status,
        ),
  );

  Generator<_OutboxClaimScenario> get outboxClaimScenario => combine2(
    intInRange(0, 8),
    listWithLengthInRange(0, 12, outboxClaimRowSpec),
    (int maxSize, List<_OutboxClaimRowSpec> rows) => _OutboxClaimScenario(
      maxSize: maxSize,
      rows: rows,
    ),
  );
}

List<_OutboxClaimModelRow> _expectedClaimedRows({
  required List<_OutboxClaimModelRow> rows,
  required int maxSize,
}) {
  if (maxSize <= 0) return const [];

  int compareByCreatedAtThenId(
    _OutboxClaimModelRow a,
    _OutboxClaimModelRow b,
  ) {
    final created = a.createdAt.compareTo(b.createdAt);
    if (created != 0) return created;
    return a.id.compareTo(b.id);
  }

  final pendingRows = rows.where((row) => row.isPending).toList()
    ..sort(compareByCreatedAtThenId);
  final expiredSendingRows = rows.where((row) => row.isExpiredSending).toList()
    ..sort(compareByCreatedAtThenId);

  final candidates = <_OutboxClaimModelRow>[
    ...pendingRows.take(maxSize),
    ...expiredSendingRows.take(maxSize),
  ]..sort(compareByCreatedAtThenId);
  if (candidates.length > maxSize) {
    candidates.removeRange(maxSize, candidates.length);
  }
  if (candidates.isEmpty) return const [];

  if (candidates.first.hasMedia) return [candidates.first];

  final stopAt = candidates.indexWhere((row) => row.hasMedia);
  return stopAt == -1 ? candidates : candidates.sublist(0, stopAt);
}

void main() {
  SyncDatabase? db;

  group('Outbox queue - ', () {
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
              priority: OutboxPriority.low.index,
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
              priority: OutboxPriority.low.index,
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
              priority: OutboxPriority.low.index,
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
              priority: OutboxPriority.low.index,
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
              priority: OutboxPriority.low.index,
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
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: 'pending',
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 2),
          subject: 'error',
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 3),
          subject: 'sent',
        ),
      );

      final results = await database
          .watchOutboxItems(
            statuses: [
              OutboxStatus.pending,
              OutboxStatus.error,
            ],
          )
          .first;

      expect(results, hasLength(2));
      expect(
        results.map((item) => item.status).toSet(),
        {OutboxStatus.pending.index, OutboxStatus.error.index},
      );
    });

    test(
      'oldestOutboxItems returns pending items in ascending order',
      () async {
        final database = db!;
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 3, 10),
          ),
        );
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 3, 8),
          ),
        );
        await database.addOutboxItem(
          buildOutboxCompanion(
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
      },
    );

    test('oldestOutboxItems respects requested limit', () async {
      final database = db!;
      for (var i = 0; i < 5; i++) {
        await database.addOutboxItem(
          buildOutboxCompanion(
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

    test('oldestOutboxItems avoids a full table scan', () async {
      final plan = await db!
          .customSelect(
            '''
        EXPLAIN QUERY PLAN
        SELECT * FROM outbox
        WHERE status = ?1
        ORDER BY created_at ASC
        LIMIT 1
        ''',
            variables: [Variable<int>(OutboxStatus.pending.index)],
          )
          .get();

      final details = plan.map((row) => row.read<String>('detail')).join(' ');
      // `SCAN outbox USING INDEX <name>` (e.g. the partial pending
      // index) is a legitimate plan — only a bare base-table scan
      // counts as a regression.
      expect(details, isNot(matches(RegExp('SCAN outbox(?! USING)'))));
    });

    test(
      'pending-claim plan uses a priority-leading index and skips the '
      'temp B-tree — the '
      '2026-05-12 desktop super-slow log captured oldestOutboxItems / '
      'claimNextOutboxBatch as `SEARCH outbox USING INDEX '
      'idx_outbox_status_priority_created_at (status=?)` + `USE TEMP '
      'B-TREE FOR ORDER BY` at tails up to 6.0 s before dequeue order '
      'was aligned with outbox priority',
      () async {
        final database = db!;

        // Seed enough sent tombstones that the partial index is
        // clearly the cheaper plan — and run ANALYZE so the planner
        // has stats to choose with. The migration runs ANALYZE on
        // upgrade; for in-memory fresh-create test DBs we run it
        // here explicitly.
        for (var i = 0; i < 200; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.sent,
              subject: 'tombstone-$i',
              message: '{"i":$i}',
              createdAt: DateTime(2024, 1, 1).add(Duration(seconds: i)),
            ),
          );
        }
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            subject: 'live',
            message: '{}',
            createdAt: DateTime(2024, 2, 1),
          ),
        );
        await database.customStatement('ANALYZE');

        final plan = await database
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM outbox WHERE status = 0 '
              'ORDER BY priority ASC, created_at ASC, id ASC LIMIT 1',
            )
            .get();
        final details = plan.map((r) => r.data.toString()).join('\n');

        expect(
          details,
          anyOf(
            contains('idx_outbox_status_priority_created_at'),
            contains('idx_outbox_actionable_priority_created_at'),
          ),
          reason:
              'status = 0 + priority/created_at ordering must match an '
              'outbox priority index after ANALYZE; otherwise the planner '
              'pays a temp B-tree sort in the dequeue hot path',
        );
        expect(
          details,
          isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
          reason:
              'priority index sort key already matches the query — no '
              'temp B-tree should appear in the plan',
        );
        // SQLite reports a partial-index walk as `SCAN <table> USING
        // INDEX <name>` — that is the correct outcome here because the
        // partial only contains the actionable pending rows and the
        // index order already matches the ORDER BY. What we are
        // guarding against is a *base-table* scan; assert by index
        // name instead of the SCAN keyword.
        expect(details, isNot(contains('SCAN outbox USING INDEX sqlite_')));
        expect(
          details,
          isNot(matches(RegExp('SCAN outbox(?! USING)'))),
        );
      },
    );

    test(
      'sending-expiry plan uses the priority-leading status index and '
      'skips the temp B-tree — the same temp-B-tree regression hit '
      "claimNextOutboxBatch's expired-sending branch "
      '(`WHERE status = 3 AND updated_at < cutoff ORDER BY priority, '
      'created_at, id LIMIT 50`)',
      () async {
        final database = db!;

        for (var i = 0; i < 100; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.sent,
              subject: 'sent-$i',
              message: '{"i":$i}',
              createdAt: DateTime(2024, 1, 1).add(Duration(seconds: i)),
            ),
          );
        }
        // Plant a real expired-sending row, then ANALYZE so the planner
        // sees the current v23 index set after the legacy expiry index
        // has been dropped during database creation.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sending.index),
            subject: const Value('stale-lease'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1)),
            updatedAt: Value(DateTime(2024, 1, 1)),
          ),
        );
        await database.customStatement('ANALYZE');

        final plan = await database
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM outbox '
              'WHERE status = 3 AND updated_at < ?1 '
              'ORDER BY priority ASC, created_at ASC, id ASC LIMIT 50',
              variables: [Variable<DateTime>(DateTime(2024, 1, 2))],
            )
            .get();
        final details = plan.map((r) => r.data.toString()).join('\n');

        expect(
          details,
          anyOf(
            contains('idx_outbox_status_priority_created_at'),
            contains('idx_outbox_actionable_priority_created_at'),
          ),
          reason:
              'literal status = 3 + priority/created_at/id ordering must '
              'match a priority-leading outbox index after ANALYZE',
        );
        expect(
          details,
          isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
          reason:
              'the status/priority index is ordered by priority/created_at '
              'inside status=3, so the expired-lease reclaim path should '
              'not sort externally',
        );
        // See sibling test — `SCAN outbox USING INDEX <partial>` is
        // legitimate; only a base-table scan (`SCAN outbox` without
        // an index) is a regression.
        expect(
          details,
          isNot(matches(RegExp('SCAN outbox(?! USING)'))),
        );
      },
    );

    test(
      'production outbox claim reads emit literal status SQL so SQLite '
      'can match the partial-index WHERE clauses',
      () async {
        final loggedEntries = <SlowQueryLogEntry>[];
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(SlowQueryLoggingGate.resetForTest);

        final loggedDb = SyncDatabase.connect(
          DatabaseConnection(
            NativeDatabase.memory().interceptWith(
              SlowQueryInterceptor(
                databaseName: syncDbFileName,
                threshold: Duration.zero,
                superSlowThreshold: const Duration(days: 1),
                reporter: loggedEntries.add,
              ),
            ),
          ),
        );
        addTearDown(loggedDb.close);

        await loggedDb.oldestOutboxItems(1);
        await loggedDb.claimNextOutboxItem(now: DateTime(2024, 1, 1, 12));
        await loggedDb.claimNextOutboxBatch(
          maxSize: 50,
          now: DateTime(2024, 1, 1, 12),
        );

        final outboxSelects = loggedEntries
            .map((entry) => entry.formattedStatement)
            .map((statement) => statement.replaceAll('"', ''))
            .where((statement) => statement.startsWith('SELECT * FROM outbox'))
            .toList();

        expect(
          outboxSelects,
          anyElement(
            allOf(
              contains('WHERE status = 0'),
              contains('ORDER BY priority ASC, created_at ASC, id ASC'),
              contains('LIMIT'),
            ),
          ),
        );
        expect(
          outboxSelects,
          anyElement(
            allOf(
              contains('status = 3'),
              contains('updated_at < ?'),
              contains('ORDER BY priority ASC, created_at ASC, id ASC'),
              contains('LIMIT'),
            ),
          ),
        );
        expect(
          outboxSelects.any((statement) => statement.contains('status = ?')),
          isFalse,
          reason:
              'a bound status value would no longer imply the literal '
              'partial-index predicate',
        );
      },
    );

    test('claimNextOutboxItem claims oldest eligible item', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          subject: 'newest',
          message: '{"id":"newest"}',
          createdAt: DateTime(2024, 1, 3),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          subject: 'oldest',
          message: '{"id":"oldest"}',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sent,
          subject: 'ignored',
          message: '{"id":"ignored"}',
          createdAt: DateTime(2024, 1, 2),
        ),
      );

      final claimed = await database.claimNextOutboxItem();

      expect(claimed, isNotNull);
      expect(claimed?.id, 2);
      final refreshed = await database.getOutboxItemById(2);
      expect(refreshed?.status, OutboxStatus.sending.index);
      expect(refreshed?.updatedAt.isAfter(DateTime(2024, 1, 1)), isTrue);
    });

    test(
      'claimNextOutboxItem skips in-flight rows with active leases',
      () async {
        final now = DateTime(2024, 1, 2, 12);
        final database = db!;
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sending.index),
            subject: const Value('inFlight'),
            message: const Value('{"id":"inFlight"}'),
            createdAt: Value(now),
            updatedAt: Value(now),
            retries: const Value(0),
          ),
        );
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            subject: 'pending',
            message: '{"id":"pending"}',
            createdAt: DateTime(2024, 1, 2),
          ),
        );

        final claimed = await database.claimNextOutboxItem(
          leaseDuration: const Duration(minutes: 5),
          now: now,
        );

        expect(claimed, isNotNull);
        expect(claimed?.id, 2);
        expect(claimed?.status, OutboxStatus.sending.index);
        final first = await database.getOutboxItemById(1);
        expect(first?.status, OutboxStatus.sending.index);
      },
    );

    test('claimNextOutboxItem reclaims stale in-flight rows', () async {
      final now = DateTime(2024, 1, 1, 12);
      final stale = now.subtract(const Duration(minutes: 10));
      final database = db!;
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sending.index),
          subject: const Value('stale'),
          message: const Value('{"id":"stale"}'),
          createdAt: Value(stale),
          updatedAt: Value(stale),
          retries: const Value(0),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          subject: 'newer',
          message: '{"id":"newer"}',
          createdAt: DateTime(2024, 1, 2),
        ),
      );

      final claimed = await database.claimNextOutboxItem(
        leaseDuration: const Duration(minutes: 5),
        now: now,
      );

      expect(claimed, isNotNull);
      expect(claimed?.id, 1);
      expect(claimed?.status, OutboxStatus.sending.index);
    });

    group('claimNextOutboxBatch', () {
      test('returns [] for an empty queue', () async {
        final database = db!;
        final batch = await database.claimNextOutboxBatch(maxSize: 50);
        expect(batch, isEmpty);
      });

      test('returns [] when maxSize is zero', () async {
        final database = db!;
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024),
          ),
        );
        final batch = await database.claimNextOutboxBatch(maxSize: 0);
        expect(batch, isEmpty);
        // The row is untouched.
        final refreshed = await database.getOutboxItemById(1);
        expect(refreshed?.status, OutboxStatus.pending.index);
      });

      test(
        'claims up to maxSize consecutive same-priority text rows in '
        'createdAt order and transitions each to sending',
        () async {
          final database = db!;
          for (var i = 0; i < 5; i++) {
            await database.addOutboxItem(
              buildOutboxCompanion(
                status: OutboxStatus.pending,
                createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
                subject: 'row-$i',
                message: '{"i":$i}',
              ),
            );
          }

          final batch = await database.claimNextOutboxBatch(maxSize: 3);

          expect(batch, hasLength(3));
          expect(batch.map((r) => r.id).toList(), [1, 2, 3]);
          for (final row in batch) {
            expect(row.status, OutboxStatus.sending.index);
          }
          // Untouched leftovers stay pending.
          for (final id in [4, 5]) {
            final refreshed = await database.getOutboxItemById(id);
            expect(refreshed?.status, OutboxStatus.pending.index);
          }
        },
      );

      test(
        'returns the head row alone when it is a media attachment, even when '
        'maxSize would allow more',
        () async {
          final database = db!;
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 0),
              filePath: 'audio/1.aac',
              subject: 'attachment-head',
            ),
          );
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 1),
              subject: 'text-1',
            ),
          );
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 2),
              subject: 'text-2',
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch, hasLength(1));
          expect(batch.single.id, 1);
          expect(batch.single.filePath, 'audio/1.aac');
          // The text rows after the attachment remain pending — the next
          // drain pass will batch them.
          for (final id in [2, 3]) {
            final refreshed = await database.getOutboxItemById(id);
            expect(refreshed?.status, OutboxStatus.pending.index);
          }
        },
      );

      test(
        'stops the bundle one row before the first media attachment',
        () async {
          final database = db!;
          for (var i = 0; i < 3; i++) {
            await database.addOutboxItem(
              buildOutboxCompanion(
                status: OutboxStatus.pending,
                createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
                subject: 'text-$i',
              ),
            );
          }
          // Position 4 carries a media attachment.
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 3),
              filePath: 'images/1.jpg',
              subject: 'media',
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch.map((r) => r.id).toList(), [1, 2, 3]);
          // The media row is left pending so the next pass sends it alone.
          final media = await database.getOutboxItemById(4);
          expect(media?.status, OutboxStatus.pending.index);
          expect(media?.filePath, 'images/1.jpg');
        },
      );

      test(
        'bundles in priority order before createdAt order',
        () async {
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.pending.index),
              subject: const Value('normal-old'),
              message: const Value('{}'),
              createdAt: Value(DateTime(2024, 1, 1, 0, 0)),
              updatedAt: Value(DateTime(2024, 1, 1, 0, 0)),
              retries: const Value(0),
              priority: Value(OutboxPriority.normal.index),
            ),
          );
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.pending.index),
              subject: const Value('high-new'),
              message: const Value('{}'),
              createdAt: Value(DateTime(2024, 1, 1, 0, 1)),
              updatedAt: Value(DateTime(2024, 1, 1, 0, 1)),
              retries: const Value(0),
              priority: Value(OutboxPriority.high.index),
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch.map((r) => r.subject).toList(), [
            'high-new',
            'normal-old',
          ]);
          expect(batch.first.priority, OutboxPriority.high.index);
          expect(batch.last.priority, OutboxPriority.normal.index);
        },
      );

      test(
        'reclaims expired sending rows just like the single-claim path',
        () async {
          final now = DateTime(2024, 1, 1, 12);
          final stale = now.subtract(const Duration(minutes: 10));
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.sending.index),
              subject: const Value('stale'),
              message: const Value('{}'),
              createdAt: Value(stale),
              updatedAt: Value(stale),
              retries: const Value(0),
            ),
          );
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: now,
              subject: 'fresh',
            ),
          );

          final batch = await database.claimNextOutboxBatch(
            maxSize: 50,
            leaseDuration: const Duration(minutes: 5),
            now: now,
          );

          expect(batch.map((r) => r.id).toList(), [1, 2]);
          for (final row in batch) {
            expect(row.status, OutboxStatus.sending.index);
            expect(row.updatedAt, now);
          }
        },
      );

      test(
        'leaves rows whose lease is still active untouched',
        () async {
          final now = DateTime(2024, 1, 2, 12);
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.sending.index),
              subject: const Value('active'),
              message: const Value('{}'),
              createdAt: Value(now),
              updatedAt: Value(now),
              retries: const Value(0),
            ),
          );
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 2),
              subject: 'pending',
            ),
          );

          final batch = await database.claimNextOutboxBatch(
            maxSize: 50,
            leaseDuration: const Duration(minutes: 5),
            now: now,
          );

          // Only the pending row, since the in-flight lease is still valid.
          expect(batch.map((r) => r.id).toList(), [2]);
        },
      );

      test('caps the result at maxSize even for an all-text queue', () async {
        final database = db!;
        for (var i = 0; i < 7; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
              subject: 'row-$i',
            ),
          );
        }

        final batch = await database.claimNextOutboxBatch(maxSize: 5);

        expect(batch, hasLength(5));
        expect(batch.map((r) => r.id).toList(), [1, 2, 3, 4, 5]);
        // The remaining 2 rows still claimable on the next call.
        final next = await database.claimNextOutboxBatch(maxSize: 5);
        expect(next.map((r) => r.id).toList(), [6, 7]);
      });

      Glados(any.outboxClaimScenario, ExploreConfig(numRuns: 40)).test(
        'claims the modelled eligible media-bounded prefix',
        (scenario) async {
          final database = SyncDatabase(inMemoryDatabase: true);
          final base = DateTime(2024, 1);
          final now = DateTime(2024, 1, 1, 12);
          const leaseDuration = Duration(minutes: 5);
          final modelRows = <_OutboxClaimModelRow>[];

          try {
            for (var i = 0; i < scenario.rows.length; i++) {
              final spec = scenario.rows[i];
              final createdAt = spec.createdAt(base);
              final updatedAt = spec.updatedAt(base, now);
              final id = await database.addOutboxItem(
                OutboxCompanion(
                  status: Value(spec.dbStatus.index),
                  subject: Value('row-$i'),
                  message: Value('{"row":$i}'),
                  createdAt: Value(createdAt),
                  updatedAt: Value(updatedAt),
                  retries: const Value(0),
                  filePath: spec.hasMedia
                      ? Value<String?>('media-$i.bin')
                      : const Value.absent(),
                ),
              );
              modelRows.add(
                _OutboxClaimModelRow(
                  id: id,
                  spec: spec,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );
            }

            final expected = _expectedClaimedRows(
              rows: modelRows,
              maxSize: scenario.maxSize,
            );

            final claimed = await database.claimNextOutboxBatch(
              maxSize: scenario.maxSize,
              leaseDuration: leaseDuration,
              now: now,
            );

            expect(
              claimed.map((row) => row.id).toList(),
              expected.map((row) => row.id).toList(),
            );

            final selectedIds = expected.map((row) => row.id).toSet();
            final storedRows = {
              for (final row in await database.allOutboxItems) row.id: row,
            };

            for (final row in modelRows) {
              final stored = storedRows[row.id]!;
              if (selectedIds.contains(row.id)) {
                expect(stored.status, OutboxStatus.sending.index);
                expect(stored.updatedAt, now);
              } else {
                expect(stored.status, row.spec.dbStatus.index);
                expect(stored.updatedAt, row.updatedAt);
              }
            }
          } finally {
            await database.close();
          }
        },
        tags: 'glados',
      );
    });

    test('updateOutboxItem can set status to error', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
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

      final errorItems = await database
          .watchOutboxItems(statuses: [OutboxStatus.error])
          .first;
      expect(errorItems.single.status, OutboxStatus.error.index);
      expect(await database.watchOutboxCount().first, 0);
    });

    test('watchOutboxCount counts only pending items', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 5, 2),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 5, 3),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 4),
        ),
      );

      expect(await database.watchOutboxCount().first, 1);
    });

    test('getPendingOutboxCount returns count of pending items', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 5, 2),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 3),
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 4),
        ),
      );

      expect(await database.getPendingOutboxCount(), 2);
    });

    test('updateOutboxItem increments retry count', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
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
        buildOutboxCompanion(
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
      final updates = database.watchOutboxItems(
        statuses: [OutboxStatus.pending],
      );
      final expectation = expectLater(
        updates,
        emitsThrough(
          isA<List<OutboxItem>>()
              .having((items) => items.length, 'length', 1)
              .having((items) => items.single.subject, 'subject', 'new-item'),
        ),
      );

      await database.addOutboxItem(
        buildOutboxCompanion(
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
        buildOutboxCompanion(
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

    test('deleteOutboxItemById removes specific item', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 9, 1),
          subject: 'item-1',
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 9, 2),
          subject: 'item-2',
        ),
      );
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 9, 3),
          subject: 'item-3',
        ),
      );

      expect(await database.allOutboxItems, hasLength(3));

      // Delete item with id 2
      final deletedCount = await database.deleteOutboxItemById(2);
      expect(deletedCount, 1);

      final remaining = await database.allOutboxItems;
      expect(remaining, hasLength(2));
      expect(remaining.map((e) => e.subject).toSet(), {'item-1', 'item-3'});
    });

    test('deleteOutboxItemById returns 0 for non-existent id', () async {
      final database = db!;
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 9, 1),
        ),
      );

      final deletedCount = await database.deleteOutboxItemById(999);
      expect(deletedCount, 0);

      expect(await database.allOutboxItems, hasLength(1));
    });
  });

  group('markOutboxItemsSent edge cases - ', () {
    late SyncDatabase database;

    setUp(() {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test('empty id list is an explicit no-op', () async {
      await database.addOutboxItem(
        buildOutboxCompanion(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 3, 15),
        ),
      );

      await database.markOutboxItemsSent(ids: []);

      final items = await database.allOutboxItems;
      expect(items.single.status, OutboxStatus.pending.index);
    });

    test(
      'within one priority, ties break by createdAt then id ascending',
      () async {
        final sameInstant = DateTime(2024, 3, 15, 10);
        // Same priority + createdAt for all three; insertion order defines
        // ascending ids, so the claim/list order must follow ids.
        for (var i = 0; i < 3; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: sameInstant,
              subject: 'tie-$i',
            ),
          );
        }
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: sameInstant.subtract(const Duration(minutes: 1)),
            subject: 'earlier',
          ),
        );

        final ordered = await database.oldestOutboxItems(10);
        expect(
          ordered.map((item) => item.subject).toList(),
          ['earlier', 'tie-0', 'tie-1', 'tie-2'],
        );
      },
    );
  });

  group('Outbox Polling Ordering - ', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'oldestOutboxItems returns items in priority order before createdAt',
      () async {
        // Insert low-priority item first (older)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-old'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );

        // Insert high-priority item second (newer)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-new'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        // Insert normal-priority item (middle time)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('normal-mid'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 11)),
            updatedAt: Value(DateTime(2024, 1, 1, 11)),
            priority: Value(OutboxPriority.normal.index),
          ),
        );

        final items = await database.oldestOutboxItems(10);
        expect(items, hasLength(3));
        expect(items[0].subject, 'high-new');
        expect(items[1].subject, 'normal-mid');
        expect(items[2].subject, 'low-old');
      },
    );

    test(
      'claimNextOutboxItem claims high-priority work before older low-priority work',
      () async {
        // Insert low-priority item first (older)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-old'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );

        // Insert high-priority item second (newer)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-new'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        final claimed = await database.claimNextOutboxItem(
          now: DateTime(2024, 1, 1, 13),
        );

        expect(claimed, isNotNull);
        expect(claimed!.subject, 'high-new');
      },
    );

    test('within same priority, oldest item is processed first', () async {
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('normal-newer'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 12)),
          updatedAt: Value(DateTime(2024, 1, 1, 12)),
          priority: Value(OutboxPriority.normal.index),
        ),
      );

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('normal-older'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 10)),
          updatedAt: Value(DateTime(2024, 1, 1, 10)),
          priority: Value(OutboxPriority.normal.index),
        ),
      );

      final items = await database.oldestOutboxItems(10);
      expect(items, hasLength(2));
      expect(items[0].subject, 'normal-older');
      expect(items[1].subject, 'normal-newer');
    });

    test('default priority is low when not specified', () async {
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('default-priority'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final items = await database.oldestOutboxItems(10);
      expect(items, hasLength(1));
      expect(items.first.priority, OutboxPriority.low.index);
    });

    test(
      'watchOutboxItems sorts by priority then newest within priority',
      () async {
        // Add items in mixed order
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-1'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-1'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 11)),
            updatedAt: Value(DateTime(2024, 1, 1, 11)),
            priority: Value(OutboxPriority.high.index),
          ),
        );
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-2'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        final items = await database.watchOutboxItems().first;
        expect(items, hasLength(3));
        // High priority first, newest within priority (DESC)
        expect(items[0].subject, 'high-2');
        expect(items[1].subject, 'high-1');
        expect(items[2].subject, 'low-1');
      },
    );

    test('health query helpers return correct counts', () async {
      // Add sequence log entries with various statuses
      final now = DateTime(2024, 1, 1, 12);
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      expect(await database.getMissingSequenceCount(), 2);
      expect(await database.getRequestedSequenceCount(), 1);

      // Add sent outbox item
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('sent-item'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 11)),
          updatedAt: Value(DateTime(2024, 1, 1, 11, 30)),
        ),
      );

      final sentCount = await database.getSentCountSince(
        DateTime(2024, 1, 1, 11),
      );
      expect(sentCount, 1);

      final sentCountNone = await database.getSentCountSince(
        DateTime(2024, 1, 1, 12),
      );
      expect(sentCountNone, 0);
    });
  });

  group('getOutboxItems -', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await database.close();
    });

    test('returns empty list when outbox is empty', () async {
      final items = await database.getOutboxItems();
      expect(items, isEmpty);
    });

    test('returns all statuses by default', () async {
      final base = DateTime(2024, 3, 15, 10);
      for (final status in [
        OutboxStatus.pending,
        OutboxStatus.error,
        OutboxStatus.sent,
      ]) {
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(status.index),
            subject: Value('subj-${status.name}'),
            message: const Value('{}'),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
        );
      }

      final items = await database.getOutboxItems();
      expect(items, hasLength(3));
      final statuses = items.map((i) => i.status).toSet();
      expect(
        statuses,
        containsAll([
          OutboxStatus.pending.index,
          OutboxStatus.error.index,
          OutboxStatus.sent.index,
        ]),
      );
    });

    test('filters by requested statuses', () async {
      final base = DateTime(2024, 3, 15, 10);
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('pending'),
          message: const Value('{}'),
          createdAt: Value(base),
          updatedAt: Value(base),
        ),
      );
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('sent'),
          message: const Value('{}'),
          createdAt: Value(base),
          updatedAt: Value(base),
        ),
      );

      final pendingOnly = await database.getOutboxItems(
        statuses: [OutboxStatus.pending],
      );
      expect(pendingOnly, hasLength(1));
      expect(pendingOnly.first.subject, 'pending');

      final sentOnly = await database.getOutboxItems(
        statuses: [OutboxStatus.sent],
      );
      expect(sentOnly, hasLength(1));
      expect(sentOnly.first.subject, 'sent');
    });

    test('respects limit parameter', () async {
      final base = DateTime(2024, 3, 15, 10);
      for (var i = 0; i < 5; i++) {
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: Value('item-$i'),
            message: const Value('{}'),
            createdAt: Value(base.add(Duration(minutes: i))),
            updatedAt: Value(base.add(Duration(minutes: i))),
          ),
        );
      }

      final limited = await database.getOutboxItems(limit: 3);
      expect(limited, hasLength(3));
    });

    test(
      'returns same rows as watchOutboxItems for the same statuses',
      () async {
        final base = DateTime(2024, 3, 15, 10);
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('p'),
            message: const Value('{}'),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
        );
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.error.index),
            subject: const Value('e'),
            message: const Value('{}'),
            createdAt: Value(base.add(const Duration(hours: 1))),
            updatedAt: Value(base.add(const Duration(hours: 1))),
          ),
        );

        final fromGet = await database.getOutboxItems();
        final fromWatch = await database.watchOutboxItems().first;

        expect(fromGet.map((i) => i.id), equals(fromWatch.map((i) => i.id)));
      },
    );
  });
}
