import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/tuning.dart';

void main() {
  group('SyncTuning', () {
    group('calculateBackoff', () {
      test('returns zero for requestCount <= 0', () {
        expect(SyncTuning.calculateBackoff(0), Duration.zero);
        expect(SyncTuning.calculateBackoff(-1), Duration.zero);
        expect(SyncTuning.calculateBackoff(-100), Duration.zero);
      });

      test('returns base backoff for first request', () {
        expect(
          SyncTuning.calculateBackoff(1),
          SyncTuning.backfillBaseBackoff,
        );
      });

      test('doubles backoff for each subsequent request', () {
        // 2^0 = 1 -> 5 min
        expect(
          SyncTuning.calculateBackoff(1),
          const Duration(minutes: 5),
        );
        // 2^1 = 2 -> 10 min
        expect(
          SyncTuning.calculateBackoff(2),
          const Duration(minutes: 10),
        );
        // 2^2 = 4 -> 20 min
        expect(
          SyncTuning.calculateBackoff(3),
          const Duration(minutes: 20),
        );
        // 2^3 = 8 -> 40 min
        expect(
          SyncTuning.calculateBackoff(4),
          const Duration(minutes: 40),
        );
        // 2^4 = 16 -> 80 min
        expect(
          SyncTuning.calculateBackoff(5),
          const Duration(minutes: 80),
        );
      });

      test('caps at maxBackoff (2 hours)', () {
        // 2^5 = 32 -> 160 min, but capped at 120 min
        expect(
          SyncTuning.calculateBackoff(6),
          SyncTuning.backfillMaxBackoff,
        );
        // Higher counts should also be capped
        expect(
          SyncTuning.calculateBackoff(10),
          SyncTuning.backfillMaxBackoff,
        );
        expect(
          SyncTuning.calculateBackoff(100),
          SyncTuning.backfillMaxBackoff,
        );
      });

      test('handles edge case of very high requestCount', () {
        // Should not overflow and should be capped
        expect(
          SyncTuning.calculateBackoff(1000),
          SyncTuning.backfillMaxBackoff,
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
        expect(
          SyncTuning.backfillBaseBackoff,
          const Duration(minutes: 5),
        );
        expect(
          SyncTuning.backfillMaxBackoff,
          const Duration(hours: 2),
        );
      });
    });
  });
}
