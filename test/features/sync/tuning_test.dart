import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/tuning.dart';

void main() {
  group('BackfillHostStats', () {
    test('totalCount returns sum of all counts', () {
      const stats = BackfillHostStats(
        hostId: 'host-1',
        receivedCount: 10,
        missingCount: 5,
        requestedCount: 3,
        backfilledCount: 7,
        deletedCount: 2,
        unresolvableCount: 1,
        latestCounter: 28,
      );

      expect(stats.totalCount, 28);
    });

    test('pendingCount returns sum of missing and requested', () {
      const stats = BackfillHostStats(
        hostId: 'host-1',
        receivedCount: 10,
        missingCount: 5,
        requestedCount: 3,
        backfilledCount: 7,
        deletedCount: 2,
        unresolvableCount: 0,
        latestCounter: 27,
      );

      expect(stats.pendingCount, 8);
    });

    test('lastSeenAt can be null', () {
      const stats = BackfillHostStats(
        hostId: 'host-1',
        receivedCount: 1,
        missingCount: 0,
        requestedCount: 0,
        backfilledCount: 0,
        deletedCount: 0,
        unresolvableCount: 0,
        latestCounter: 1,
      );

      expect(stats.lastSeenAt, isNull);
    });

    test('lastSeenAt can be set', () {
      final lastSeen = DateTime(2024, 1, 15);
      final stats = BackfillHostStats(
        hostId: 'host-1',
        receivedCount: 1,
        missingCount: 0,
        requestedCount: 0,
        backfilledCount: 0,
        deletedCount: 0,
        unresolvableCount: 0,
        latestCounter: 1,
        lastSeenAt: lastSeen,
      );

      expect(stats.lastSeenAt, lastSeen);
    });
  });

  group('BackfillStats', () {
    test('fromHostStats creates stats from list', () {
      const hostStats = [
        BackfillHostStats(
          hostId: 'host-1',
          receivedCount: 10,
          missingCount: 2,
          requestedCount: 1,
          backfilledCount: 3,
          deletedCount: 0,
          unresolvableCount: 1,
          latestCounter: 17,
        ),
        BackfillHostStats(
          hostId: 'host-2',
          receivedCount: 5,
          missingCount: 1,
          requestedCount: 0,
          backfilledCount: 2,
          deletedCount: 1,
          unresolvableCount: 0,
          latestCounter: 9,
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

    test('totalPending returns sum of missing and requested', () {
      final stats = BackfillStats.fromHostStats(const [
        BackfillHostStats(
          hostId: 'host-1',
          receivedCount: 10,
          missingCount: 5,
          requestedCount: 3,
          backfilledCount: 0,
          deletedCount: 0,
          unresolvableCount: 0,
          latestCounter: 18,
        ),
      ]);

      expect(stats.totalPending, 8);
    });

    test('totalEntries returns sum of all counts', () {
      final stats = BackfillStats.fromHostStats(const [
        BackfillHostStats(
          hostId: 'host-1',
          receivedCount: 10,
          missingCount: 5,
          requestedCount: 3,
          backfilledCount: 7,
          deletedCount: 2,
          unresolvableCount: 1,
          latestCounter: 28,
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
      expect(stats.totalPending, 0);
      expect(stats.totalEntries, 0);
    });
  });

  group('SyncTuning', () {
    group('calculateBackoff', () {
      test('returns zero for requestCount <= 0 (first request is immediate)',
          () {
        expect(SyncTuning.calculateBackoff(0), Duration.zero);
        expect(SyncTuning.calculateBackoff(-1), Duration.zero);
        expect(SyncTuning.calculateBackoff(-100), Duration.zero);
      });

      test('uses exponential backoff for retries', () {
        // attempt 1: 5 minutes * 2^0 = 5 minutes
        expect(
          SyncTuning.calculateBackoff(1),
          const Duration(minutes: 5),
        );
        // attempt 2: 5 minutes * 2^1 = 10 minutes
        expect(
          SyncTuning.calculateBackoff(2),
          const Duration(minutes: 10),
        );
        // attempt 3: 5 minutes * 2^2 = 20 minutes
        expect(
          SyncTuning.calculateBackoff(3),
          const Duration(minutes: 20),
        );
        // attempt 4: 5 minutes * 2^3 = 40 minutes
        expect(
          SyncTuning.calculateBackoff(4),
          const Duration(minutes: 40),
        );
        // attempt 5: 5 minutes * 2^4 = 80 minutes
        expect(
          SyncTuning.calculateBackoff(5),
          const Duration(minutes: 80),
        );
      });

      test('caps backoff at 2 hours', () {
        // attempt 6: 5 minutes * 2^5 = 160 minutes, capped at 120 minutes
        expect(
          SyncTuning.calculateBackoff(6),
          const Duration(hours: 2),
        );
        // High attempt counts should all cap at 2 hours
        expect(
          SyncTuning.calculateBackoff(10),
          SyncTuning.backfillBackoffMax,
        );
        expect(
          SyncTuning.calculateBackoff(100),
          SyncTuning.backfillBackoffMax,
        );
      });

      test('backoff constants have expected values', () {
        expect(
          SyncTuning.backfillBackoffBase,
          const Duration(minutes: 5),
        );
        expect(
          SyncTuning.backfillBackoffMax,
          const Duration(hours: 2),
        );
      });
    });

    group('constants', () {
      test('backfill constants have expected values', () {
        expect(
          SyncTuning.backfillRequestInterval,
          const Duration(minutes: 5),
        );
        expect(SyncTuning.backfillMaxRequestCount, 10);
        expect(SyncTuning.backfillBatchSize, 100);
        expect(SyncTuning.backfillProcessingBatchSize, 50);
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
          const Duration(seconds: 3),
        );
      });

      test('live-scan and catchup constants have expected values', () {
        expect(
          SyncTuning.minLiveScanGap,
          const Duration(seconds: 1),
        );
        expect(
          SyncTuning.trailingLiveScanDebounce,
          const Duration(milliseconds: 120),
        );
        expect(
          SyncTuning.minCatchupGap,
          const Duration(seconds: 1),
        );
        expect(
          SyncTuning.trailingCatchupDelay,
          const Duration(seconds: 1),
        );
      });

      test('historical window constants have expected values', () {
        expect(SyncTuning.catchupPreContextCount, 80);
        expect(SyncTuning.catchupMaxLookback, 10000);
      });
    });
  });
}
