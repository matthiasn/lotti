import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/features/sync/tuning.dart';

/// A generated [BackfillHostStats] scenario. Wrapping the raw counts in a named
/// class (instead of generating [BackfillHostStats] directly) keeps Glados
/// failure output legible — it prints this `toString()` rather than
/// `Instance of 'BackfillHostStats'`.
class _GeneratedHostStats {
  const _GeneratedHostStats({
    required this.received,
    required this.missing,
    required this.requested,
    required this.backfilled,
    required this.deleted,
    required this.unresolvable,
    required this.burned,
  });

  final int received;
  final int missing;
  final int requested;
  final int backfilled;
  final int deleted;
  final int unresolvable;
  final int burned;

  BackfillHostStats toHostStats() => BackfillHostStats(
    receivedCount: received,
    missingCount: missing,
    requestedCount: requested,
    backfilledCount: backfilled,
    deletedCount: deleted,
    unresolvableCount: unresolvable,
    burnedCount: burned,
  );

  @override
  String toString() =>
      '_GeneratedHostStats(received: $received, missing: $missing, '
      'requested: $requested, backfilled: $backfilled, deleted: $deleted, '
      'unresolvable: $unresolvable, burned: $burned)';
}

extension _AnyBackfillHostStats on Any {
  Generator<_GeneratedHostStats> get backfillHostStats => combine7(
    intInRange(0, 1000),
    intInRange(0, 1000),
    intInRange(0, 1000),
    intInRange(0, 1000),
    intInRange(0, 1000),
    intInRange(0, 1000),
    intInRange(0, 1000),
    (
      int received,
      int missing,
      int requested,
      int backfilled,
      int deleted,
      int unresolvable,
      int burned,
    ) => _GeneratedHostStats(
      received: received,
      missing: missing,
      requested: requested,
      backfilled: backfilled,
      deleted: deleted,
      unresolvable: unresolvable,
      burned: burned,
    ),
  );

  Generator<List<_GeneratedHostStats>> get backfillHostStatsList =>
      listWithLengthInRange(0, 8, backfillHostStats);
}

void main() {
  group('BackfillStats.fromHostStats', () {
    Glados(any.backfillHostStatsList, ExploreConfig(numRuns: 150)).test(
      'every total is the per-field fold and totalEntries sums all eight '
      'buckets',
      (generated) {
        final hostStats = [for (final g in generated) g.toHostStats()];
        final stats = BackfillStats.fromHostStats(hostStats);

        int foldOf(int Function(BackfillHostStats) field) =>
            hostStats.fold(0, (sum, h) => sum + field(h));

        expect(stats.totalReceived, foldOf((h) => h.receivedCount));
        expect(stats.totalMissing, foldOf((h) => h.missingCount));
        expect(stats.totalRequested, foldOf((h) => h.requestedCount));
        expect(stats.totalBackfilled, foldOf((h) => h.backfilledCount));
        expect(stats.totalDeleted, foldOf((h) => h.deletedCount));
        expect(stats.totalUnresolvable, foldOf((h) => h.unresolvableCount));
        expect(stats.totalBurned, foldOf((h) => h.burnedCount));
        expect(stats.hostStats, hostStats);

        // totalEntries is exactly the sum of every per-status total, so a
        // burned counter is counted once and never folded into unresolvable.
        expect(
          stats.totalEntries,
          stats.totalReceived +
              stats.totalMissing +
              stats.totalRequested +
              stats.totalBackfilled +
              stats.totalDeleted +
              stats.totalUnresolvable +
              stats.totalBurned,
          reason: '$generated',
        );
      },
      tags: 'glados',
    );

    test('is the additive identity for an empty host list', () {
      final stats = BackfillStats.fromHostStats(const []);

      expect(stats.totalReceived, 0);
      expect(stats.totalMissing, 0);
      expect(stats.totalRequested, 0);
      expect(stats.totalBackfilled, 0);
      expect(stats.totalDeleted, 0);
      expect(stats.totalUnresolvable, 0);
      expect(stats.totalBurned, 0);
      expect(stats.totalEntries, 0);
      expect(stats.hostStats, isEmpty);
    });
  });

  group('SyncTuning', () {
    group('constants', () {
      test('backfill constants have expected values', () {
        expect(
          SyncTuning.backfillRequestInterval,
          const Duration(minutes: 2),
        );
        expect(SyncTuning.backfillMaxRequestCount, 10);
        expect(SyncTuning.backfillProcessingBatchSize, 2000);
      });

      test('default backfill limits have expected values', () {
        expect(
          SyncTuning.defaultBackfillMaxAge,
          const Duration(days: 1),
        );
        expect(SyncTuning.defaultBackfillMaxEntriesPerHost, 250);
      });

      test('outbox constants have expected values', () {
        expect(
          SyncTuning.outboxRetryDelay,
          const Duration(seconds: 5),
        );
        expect(
          SyncTuning.outboxErrorDelay,
          const Duration(seconds: 15),
        );
        expect(SyncTuning.outboxMaxRetriesDiagnostics, 10);
        expect(
          SyncTuning.outboxSendTimeout,
          const Duration(seconds: 20),
        );
        expect(
          SyncTuning.outboxWatchdogInterval,
          const Duration(seconds: 10),
        );
        expect(
          SyncTuning.outboxDbNudgeDebounce,
          const Duration(milliseconds: 50),
        );
        expect(
          SyncTuning.outboxIdleThreshold,
          const Duration(milliseconds: 1200),
        );
      });

      test('historical window constants have expected values', () {
        expect(SyncTuning.catchupMaxLookback, 10000);
      });
    });
  });
}
