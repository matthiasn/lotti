import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';

void main() {
  group('SyncMetrics', () {
    test('constructor initializes fields and defaults', () {
      const m = SyncMetrics(
        processed: 1,
        skipped: 2,
        failures: 3,
        prefetch: 4,
        flushes: 5,
        catchupBatches: 6,
        skippedByRetryLimit: 7,
        retriesScheduled: 8,
        circuitOpens: 9,
        dbMissingBase: 0,
      );
      expect(m.processed, 1);
      expect(m.skipped, 2);
      expect(m.failures, 3);
      expect(m.prefetch, 4);
      expect(m.flushes, 5);
      expect(m.catchupBatches, 6);
      expect(m.skippedByRetryLimit, 7);
      expect(m.retriesScheduled, 8);
      expect(m.circuitOpens, 9);
      expect(m.processedByType, isEmpty);
      expect(m.droppedByType, isEmpty);
      expect(m.dbApplied, 0);
      expect(m.dbIgnoredByVectorClock, 0);
      expect(m.conflictsCreated, 0);
    });

    test('fromMap parses scalars and typed entries', () {
      final m = SyncMetrics.fromMap({
        'processed': 10,
        'skipped': 1,
        'failures': 2,
        'prefetch': 3,
        'flushes': 4,
        'catchupBatches': 5,
        'skippedByRetryLimit': 6,
        'retriesScheduled': 7,
        'circuitOpens': 8,
        'dbApplied': 9,
        'dbIgnoredByVectorClock': 11,
        'conflictsCreated': 12,
        'processed.journalEntity': 2,
        'processed.entryLink': 3,
        'droppedByType.journalEntity': 1,
      });
      expect(m.processed, 10);
      expect(m.flushes, 4);
      expect(m.dbApplied, 9);
      expect(m.dbIgnoredByVectorClock, 11);
      expect(m.conflictsCreated, 12);
      expect(m.processedByType['journalEntity'], 2);
      expect(m.processedByType['entryLink'], 3);
      expect(m.droppedByType['journalEntity'], 1);
    });

    test('fromMap handles missing fields with defaults', () {
      final m = SyncMetrics.fromMap({});
      expect(m.processed, 0);
      expect(m.skipped, 0);
      expect(m.processedByType, isEmpty);
      expect(m.droppedByType, isEmpty);
    });

    test('toMap formats all fields including typed and DB metrics', () {
      const m = SyncMetrics(
        processed: 1,
        skipped: 0,
        failures: 0,
        prefetch: 1,
        flushes: 2,
        catchupBatches: 0,
        skippedByRetryLimit: 0,
        retriesScheduled: 0,
        circuitOpens: 0,
        processedByType: {'journalEntity': 2},
        droppedByType: {'entryLink': 1},
        dbApplied: 5,
        dbIgnoredByVectorClock: 1,
        conflictsCreated: 1,
        dbMissingBase: 0,
      );
      final map = m.toMap();
      expect(map['processed'], 1);
      expect(map['flushes'], 2);
      expect(map['processed.journalEntity'], 2);
      expect(map['droppedByType.entryLink'], 1);
      expect(map['dbApplied'], 5);
      expect(map['dbIgnoredByVectorClock'], 1);
      expect(map['conflictsCreated'], 1);
    });

    test('round-trip preserves values', () {
      const original = SyncMetrics(
        processed: 9,
        skipped: 8,
        failures: 7,
        prefetch: 6,
        flushes: 5,
        catchupBatches: 4,
        skippedByRetryLimit: 3,
        retriesScheduled: 2,
        circuitOpens: 1,
        processedByType: {'A': 1},
        droppedByType: {'B': 2},
        dbApplied: 3,
        dbIgnoredByVectorClock: 4,
        conflictsCreated: 5,
        dbMissingBase: 0,
      );
      final rt = SyncMetrics.fromMap(original.toMap());
      expect(rt.processed, original.processed);
      expect(rt.skipped, original.skipped);
      expect(rt.processedByType, original.processedByType);
      expect(rt.droppedByType, original.droppedByType);
      expect(rt.dbApplied, original.dbApplied);
      expect(rt.dbIgnoredByVectorClock, original.dbIgnoredByVectorClock);
      expect(rt.conflictsCreated, original.conflictsCreated);
    });
  });
}
