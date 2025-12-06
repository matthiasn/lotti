import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/tuning.dart';

void main() {
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
        expect(SyncTuning.backfillProcessingBatchSize, 20);
      });
    });
  });
}
