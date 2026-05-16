import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/tuning.dart';

void main() {
  group('BackfillStats', () {
    test('fromHostStats creates stats from list', () {
      const hostStats = [
        BackfillHostStats(
          receivedCount: 10,
          missingCount: 2,
          requestedCount: 1,
          backfilledCount: 3,
          deletedCount: 0,
          unresolvableCount: 1,
        ),
        BackfillHostStats(
          receivedCount: 5,
          missingCount: 1,
          requestedCount: 0,
          backfilledCount: 2,
          deletedCount: 1,
          unresolvableCount: 0,
        ),
      ];

      final stats = BackfillStats.fromHostStats(hostStats);

      expect(stats.totalReceived, 15);
      expect(stats.totalMissing, 3);
      expect(stats.totalRequested, 1);
      expect(stats.totalBackfilled, 5);
      expect(stats.totalDeleted, 1);
      expect(stats.totalUnresolvable, 1);
      expect(stats.hostStats, hostStats);
    });

    test('totalEntries returns sum of all counts', () {
      final stats = BackfillStats.fromHostStats(const [
        BackfillHostStats(
          receivedCount: 10,
          missingCount: 5,
          requestedCount: 3,
          backfilledCount: 7,
          deletedCount: 2,
          unresolvableCount: 1,
        ),
      ]);

      expect(stats.totalEntries, 28);
    });

    test('fromHostStats works with empty list', () {
      final stats = BackfillStats.fromHostStats(const []);

      expect(stats.totalReceived, 0);
      expect(stats.totalMissing, 0);
      expect(stats.totalRequested, 0);
      expect(stats.totalBackfilled, 0);
      expect(stats.totalDeleted, 0);
      expect(stats.totalUnresolvable, 0);
      expect(stats.hostStats, isEmpty);
      expect(stats.totalEntries, 0);
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
