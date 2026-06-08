// Tests for outbox retention pruning (`lib/database/sync_db_outbox_prune.dart`).
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import 'sync_db_test_utils.dart';

/// Position of a row's `updated_at` relative to the prune cutoff.
/// `pruneSentOutboxItemsChunked` deletes rows where
/// `updated_at < cutoff`, so `atCutoff` rows are intentionally kept —
/// the strict-less-than is the bit the property test exercises.
enum _GeneratedOutboxAge { fresh, atCutoff, old }

class _PruneRowSpec {
  const _PruneRowSpec({
    required this.status,
    required this.age,
  });

  final GeneratedOutboxStatus status;
  final _GeneratedOutboxAge age;

  /// Only `(sent, old)` rows are eligible for pruning. Live state
  /// (pending / sending) is never touched regardless of age, error
  /// rows are forensic and kept forever, fresh/atCutoff sent rows are
  /// inside the retention window.
  bool isPrunable({required Duration retention, required DateTime now}) {
    return status == GeneratedOutboxStatus.sent &&
        age == _GeneratedOutboxAge.old;
  }

  /// `expiredSending` and `activeSending` both map to the
  /// `OutboxStatus.sending` literal in the table — the prune predicate
  /// only inspects `status` and `updated_at`, so this collapse loses no
  /// information.
  OutboxStatus get dbStatus => switch (status) {
    GeneratedOutboxStatus.pending => OutboxStatus.pending,
    GeneratedOutboxStatus.expiredSending => OutboxStatus.sending,
    GeneratedOutboxStatus.activeSending => OutboxStatus.sending,
    GeneratedOutboxStatus.sent => OutboxStatus.sent,
    GeneratedOutboxStatus.error => OutboxStatus.error,
  };

  DateTime updatedAtValue({
    required Duration retention,
    required DateTime now,
  }) {
    final cutoff = now.subtract(retention);
    return switch (age) {
      _GeneratedOutboxAge.fresh => now.subtract(const Duration(hours: 1)),
      _GeneratedOutboxAge.atCutoff => cutoff,
      _GeneratedOutboxAge.old => cutoff.subtract(const Duration(days: 1)),
    };
  }

  @override
  String toString() => '_PruneRowSpec(status: $status, age: $age)';
}

class _PruneScenario {
  const _PruneScenario({
    required this.rows,
    required this.chunkSize,
    required this.retentionDays,
  });

  static final now = DateTime(2026, 5, 9, 12);

  final List<_PruneRowSpec> rows;
  final int chunkSize;
  final int retentionDays;

  Duration get retention => Duration(days: retentionDays);

  int get expectedDeleted => rows
      .where((row) => row.isPrunable(retention: retention, now: now))
      .length;

  /// `pruneSentOutboxItemsChunked` calls `onProgress` exactly once per
  /// loop iteration — including the terminating pass whose chunk
  /// returns `< chunkSize`. So the number of emissions is
  /// `(deleted ~/ chunkSize) + 1`, and emission `i` carries
  /// `min((i + 1) * chunkSize, deleted)` as the running total.
  List<int> get expectedProgress {
    final emissions = (expectedDeleted ~/ chunkSize) + 1;
    return [
      for (var i = 0; i < emissions; i++)
        if ((i + 1) * chunkSize < expectedDeleted)
          (i + 1) * chunkSize
        else
          expectedDeleted,
    ];
  }

  @override
  String toString() =>
      '_PruneScenario('
      'rows: $rows, '
      'chunkSize: $chunkSize, '
      'retentionDays: $retentionDays'
      ')';
}

extension _AnyPruneScenario on Any {
  Generator<_GeneratedOutboxAge> get generatedOutboxAge =>
      choose(_GeneratedOutboxAge.values);

  Generator<_PruneRowSpec> get pruneRowSpec => combine2(
    any.generatedOutboxStatus,
    generatedOutboxAge,
    (GeneratedOutboxStatus status, _GeneratedOutboxAge age) =>
        _PruneRowSpec(status: status, age: age),
  );

  /// Scenario space for `pruneSentOutboxItemsChunked`. `chunkSize`
  /// stays small (1–6) so generated row counts realistically straddle
  /// chunk boundaries — the loop's terminator condition (`n < chunkSize`)
  /// is the bit most likely to harbor an off-by-one. `retentionDays`
  /// covers the realistic configured-retention window from
  /// `SyncTuning.outboxSentRetention` and a few neighbours.
  Generator<_PruneScenario> get pruneScenario => combine3(
    listWithLengthInRange(0, 14, pruneRowSpec),
    intInRange(1, 6),
    intInRange(1, 7),
    (List<_PruneRowSpec> rows, int chunkSize, int retentionDays) =>
        _PruneScenario(
          rows: rows,
          chunkSize: chunkSize,
          retentionDays: retentionDays,
        ),
  );
}

void main() {
  SyncDatabase? db;

  group('pruneSentOutboxItems - ', () {
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
      'pruneSentOutboxItems deletes only `sent` rows older than retention, '
      'keeps `error` forever (regardless of age), and leaves pending/sending '
      'untouched',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22, 12);
        final old = now.subtract(const Duration(days: 10));
        final fresh = now.subtract(const Duration(days: 2));

        // Old sent — must be pruned.
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: old,
            subject: 'old-sent',
          ),
        );
        // Fresh sent — within retention, must stay.
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: fresh,
            subject: 'fresh-sent',
          ),
        );
        // Old error — kept forever for forensic inspection.
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.error,
            createdAt: old,
            subject: 'old-error',
          ),
        );
        // Old pending — never pruned (live state).
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: old,
            subject: 'old-pending',
          ),
        );
        // Old sending — never pruned (live state).
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sending,
            createdAt: old,
            subject: 'old-sending',
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 1);

        final remaining = await database.allOutboxItems;
        expect(
          remaining.map((e) => e.subject).toSet(),
          {'fresh-sent', 'old-error', 'old-pending', 'old-sending'},
        );
      },
    );

    test(
      'pruneSentOutboxItems uses updated_at (send time), not created_at '
      '(enqueue time) — a row enqueued 10 days ago but sent today must not '
      'be pruned',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22, 12);
        final oldCreated = now.subtract(const Duration(days: 10));
        final recentlySent = now.subtract(const Duration(hours: 6));

        // Enqueued 10 days ago, sent 6 hours ago. Pruning by created_at
        // would delete this row; pruning by updated_at (the send time
        // stamped by markSent) keeps it.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            subject: const Value('stuck-then-recently-sent'),
            message: const Value('{}'),
            createdAt: Value(oldCreated),
            updatedAt: Value(recentlySent),
            retries: const Value(0),
          ),
        );

        // An actually-old sent row (control): enqueued AND sent 10 days
        // ago — this one should be deleted.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            subject: const Value('actually-old'),
            message: const Value('{}'),
            createdAt: Value(oldCreated),
            updatedAt: Value(oldCreated),
            retries: const Value(0),
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 1);

        final remaining = await database.allOutboxItems;
        expect(remaining.map((e) => e.subject).toSet(), {
          'stuck-then-recently-sent',
        });
      },
    );

    test(
      'pruneSentOutboxItems returns 0 when there is nothing to prune',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22);
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: now.subtract(const Duration(days: 2)),
            subject: 'recent-sent',
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 0);
        expect(await database.allOutboxItems, hasLength(1));
      },
    );

    test(
      'pruneSentOutboxItemsChunked deletes the same rows as the unbounded '
      'variant but in bounded passes — onProgress reports the running total '
      'after each chunk and the loop terminates when a pass deletes fewer '
      'rows than chunkSize',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9, 12);
        // 12 stale `sent` rows + 1 fresh `sent` + 1 `pending` + 1 `error`.
        // With chunkSize = 5 the chunked loop must run 3 passes
        // (5 + 5 + 2); the third pass is the natural terminator (n <
        // chunkSize), so progress should be [5, 10, 12].
        for (var i = 0; i < 12; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.sent,
              createdAt: now.subtract(const Duration(days: 30)),
              subject: 'stale-sent-$i',
            ),
          );
        }
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: now,
            subject: 'fresh-sent',
          ),
        );
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: now.subtract(const Duration(days: 30)),
            subject: 'old-pending',
          ),
        );
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.error,
            createdAt: now.subtract(const Duration(days: 30)),
            subject: 'old-error',
          ),
        );

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 5,
          now: now,
          onProgress: progress.add,
        );

        expect(deleted, 12);
        expect(progress, [5, 10, 12]);
        final remaining = await database.allOutboxItems;
        expect(
          remaining.map((e) => e.subject).toSet(),
          {'fresh-sent', 'old-pending', 'old-error'},
        );
      },
    );

    test(
      'pruneSentOutboxItemsChunked stops on the first pass when the eligible '
      'set fits in one chunk',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9);
        for (var i = 0; i < 3; i++) {
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: OutboxStatus.sent,
              createdAt: now.subtract(const Duration(days: 30)),
              subject: 'stale-$i',
            ),
          );
        }

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 100,
          now: now,
          onProgress: progress.add,
        );

        expect(deleted, 3);
        expect(progress, [3]);
        expect(await database.allOutboxItems, isEmpty);
      },
    );

    Glados(any.pruneScenario, ExploreConfig(numRuns: 80)).test(
      'pruneSentOutboxItemsChunked invariants — for any (rows, chunkSize, '
      'retention): only (sent, old) rows are deleted; live state and forensic '
      'rows survive; progress is monotonic non-decreasing, ends at the return '
      'value, and the emission count obeys (deleted ~/ chunkSize) + 1',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        try {
          // Seed in scenario order so the auto-increment id's encode the
          // generator's row index — makes failing-shrink scenarios easier
          // to reason about by row.
          for (final row in scenario.rows) {
            await database.addOutboxItem(
              OutboxCompanion(
                status: Value(row.dbStatus.index),
                subject: const Value('s'),
                message: const Value('{}'),
                createdAt: Value(
                  row.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                ),
                updatedAt: Value(
                  row.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                ),
                retries: const Value(0),
              ),
            );
          }

          final progress = <int>[];
          final deleted = await database.pruneSentOutboxItemsChunked(
            retention: scenario.retention,
            chunkSize: scenario.chunkSize,
            now: _PruneScenario.now,
            onProgress: progress.add,
          );

          // Return value matches the model.
          expect(deleted, scenario.expectedDeleted);

          // Surviving rows are exactly the non-prunable subset, in any
          // order. Compare a sorted (status, updatedAt) projection so
          // the assertion is independent of insertion order.
          final remaining = await database.allOutboxItems;
          List<(int, int)> projection(Iterable<OutboxItem> items) =>
              [
                for (final item in items)
                  (item.status, item.updatedAt.microsecondsSinceEpoch),
              ]..sort((a, b) {
                final s = a.$1.compareTo(b.$1);
                return s != 0 ? s : a.$2.compareTo(b.$2);
              });
          final expectedSurvivors = scenario.rows.where(
            (r) => !r.isPrunable(
              retention: scenario.retention,
              now: _PruneScenario.now,
            ),
          );
          expect(
            projection(remaining),
            projection([
              for (final r in expectedSurvivors)
                OutboxItem(
                  id: 0,
                  status: r.dbStatus.index,
                  subject: 's',
                  message: '{}',
                  createdAt: r.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                  updatedAt: r.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                  retries: 0,
                  priority: OutboxPriority.low.index,
                ),
            ]),
          );

          // Progress sequence matches the model: monotonic non-decreasing,
          // terminates at `deleted`, with `(deleted ~/ chunkSize) + 1`
          // emissions including the terminator pass.
          expect(progress, scenario.expectedProgress);
          expect(progress.last, deleted);
          for (var i = 1; i < progress.length; i++) {
            expect(
              progress[i] >= progress[i - 1],
              isTrue,
              reason: 'progress must be monotonic non-decreasing',
            );
          }
        } finally {
          await database.close();
        }
      },
      tags: 'glados',
    );

    test(
      'pruneSentOutboxItemsChunked returns 0 and invokes onProgress once '
      'with 0 when there is nothing to prune — the terminator pass still '
      'reports its (zero) running total so callers can rely on the final '
      'progress value matching the return value',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9);
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: now.subtract(const Duration(days: 1)),
            subject: 'recent-sent',
          ),
        );

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 10,
          now: now,
          onProgress: progress.add,
        );

        // The first pass deletes 0 rows (nothing eligible) and that is
        // already < chunkSize, so the loop exits after one iteration.
        // The progress callback fires exactly once with the running
        // total of zero — callers can rely on the final progress value
        // matching the return value.
        expect(deleted, 0);
        expect(progress, [0]);
        expect(await database.allOutboxItems, hasLength(1));
      },
    );

    test(
      'pruneSentOutboxItemsChunked short-circuits with 0 when chunkSize is '
      'non-positive — guards the writer against a misconfigured caller that '
      'would otherwise wedge the loop on LIMIT 0 / negative LIMIT semantics',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9);
        // Seed an eligible row so the assertion proves the early
        // short-circuit fired BEFORE the DELETE; if the guard regressed,
        // the row would be deleted instead.
        await database.addOutboxItem(
          buildOutboxCompanion(
            status: OutboxStatus.sent,
            createdAt: now.subtract(const Duration(days: 30)),
            subject: 'stale-sent',
          ),
        );

        final progress = <int>[];
        final zeroDeleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 0,
          now: now,
          onProgress: progress.add,
        );
        final negDeleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: -1,
          now: now,
          onProgress: progress.add,
        );

        expect(zeroDeleted, 0);
        expect(negDeleted, 0);
        // onProgress is never invoked when the guard fires — the loop
        // body (and therefore the progress emit) is skipped entirely.
        expect(progress, isEmpty);
        expect(await database.allOutboxItems, hasLength(1));
      },
    );
  });

  group('pruneSentOutboxItems - default now -', () {
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

    // Exercises the `now ?? DateTime.now()` branch at line 918 by omitting
    // the `now` parameter. We cannot assert the exact cutoff, but we can
    // verify the method runs and returns 0 when there is nothing to prune.
    test(
      'returns 0 when called without explicit now and outbox is empty',
      () async {
        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
        );
        expect(deleted, 0);
      },
    );

    test(
      'prunes sent rows older than retention when now is omitted',
      () async {
        // Insert a sent row with a very old updatedAt so it is guaranteed to
        // be older than any reasonable wall-clock retention.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            subject: const Value('old-sent'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2000, 1, 1)),
            updatedAt: Value(DateTime(2000, 1, 1)),
          ),
        );

        // Insert a pending row that must not be pruned.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('pending'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2000, 1, 1)),
            updatedAt: Value(DateTime(2000, 1, 1)),
          ),
        );

        // Calling without `now` should use DateTime.now() internally and
        // prune the ancient sent row.
        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 1),
        );
        expect(deleted, 1);

        final remaining = await database.allOutboxItems;
        expect(remaining, hasLength(1));
        expect(remaining.first.status, OutboxStatus.pending.index);
      },
    );
  });
}
