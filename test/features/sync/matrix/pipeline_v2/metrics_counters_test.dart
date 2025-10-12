// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';

void main() {
  group('MetricsCounters', () {
    test('increments, ring buffers, and snapshot', () {
      final m = MetricsCounters(
          collect: true, lastIgnoredMax: 2, lastPrefetchedMax: 2);

      // Basic counters
      m
        ..incProcessed()
        ..incSkipped()
        ..incFailures()
        ..incPrefetch()
        ..incFlushes()
        ..incCatchupBatches()
        ..incSkippedByRetryLimit()
        ..incRetriesScheduled()
        ..incCircuitOpens();

      // By type
      m
        ..bumpProcessedType('journalEntity')
        ..bumpDroppedType('entryLink');

      // DB metrics
      m
        ..incDbApplied()
        ..incDbIgnoredByVectorClock()
        ..incConflictsCreated()
        ..incDbMissingBase();

      // Ring buffers (max 2)
      m
        ..addLastIgnored('a:older')
        ..addLastIgnored('b:equal')
        ..addLastIgnored('c:older') // evicts 'a:older'
        ..addLastPrefetched('/a')
        ..addLastPrefetched('/b')
        ..addLastPrefetched('/c'); // evicts '/a'

      final snap = m.snapshot(retryStateSize: 3, circuitIsOpen: true);
      expect(snap['processed'], 1);
      expect(snap['skipped'], 1);
      expect(snap['failures'], 1);
      expect(snap['prefetch'], 1);
      expect(snap['flushes'], 1);
      expect(snap['catchupBatches'], 1);
      expect(snap['skippedByRetryLimit'], 1);
      expect(snap['retriesScheduled'], 1);
      expect(snap['circuitOpens'], 1);
      expect(snap['processed.journalEntity'], 1);
      expect(snap['droppedByType.entryLink'], 1);
      expect(snap['dbApplied'], 1);
      expect(snap['dbIgnoredByVectorClock'], 1);
      expect(snap['conflictsCreated'], 1);
      expect(snap['dbMissingBase'], 1);
      expect(snap['retryStateSize'], 3);
      expect(snap['circuitOpen'], 1);
      expect(snap['lastIgnoredCount'], 2);
      expect(snap['lastPrefetchedCount'], 2);

      // Ensure ring buffers capped at 2
      expect(m.lastIgnored.length, 2);
      expect(m.lastPrefetched.length, 2);

      // Log line contains key counters
      final log = m.buildFlushLog(retriesPending: 10);
      expect(log.contains('flush=1'), isTrue);
      expect(log.contains('processed=1'), isTrue);
      expect(log.contains('retriesPending=10'), isTrue);
    });
  });
}
