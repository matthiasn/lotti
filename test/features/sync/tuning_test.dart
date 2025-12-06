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

      test('returns 12h for any retry (requestCount >= 1)', () {
        expect(
          SyncTuning.calculateBackoff(1),
          SyncTuning.backfillMinRetryInterval,
        );
        expect(
          SyncTuning.calculateBackoff(2),
          SyncTuning.backfillMinRetryInterval,
        );
        expect(
          SyncTuning.calculateBackoff(10),
          SyncTuning.backfillMinRetryInterval,
        );
        expect(
          SyncTuning.calculateBackoff(100),
          SyncTuning.backfillMinRetryInterval,
        );
      });

      test('backfillMinRetryInterval is 12 hours', () {
        expect(
          SyncTuning.backfillMinRetryInterval,
          const Duration(hours: 12),
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
          SyncTuning.backfillMinRetryInterval,
          const Duration(hours: 12),
        );
      });
    });
  });
}
