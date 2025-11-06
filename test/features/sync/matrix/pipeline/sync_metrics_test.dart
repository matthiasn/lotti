import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';

void main() {
  test('fromMap handles missing keys gracefully', () {
    final metrics = SyncMetrics.fromMap(const <String, dynamic>{});

    expect(metrics.processed, 0);
    expect(metrics.skipped, 0);
    expect(metrics.processedByType, isEmpty);
    expect(metrics.droppedByType, isEmpty);
    expect(metrics.dbApplied, 0);
    expect(metrics.staleAttachmentPurges, 0);
  });

  test('fromMap deserializes processedByType and droppedByType entries', () {
    final metrics = SyncMetrics.fromMap(const <String, dynamic>{
      'processed.journalEntity': 5,
      'processed.entryLink': 1,
      'droppedByType.journalEntity': 2,
    });

    expect(metrics.processedByType['journalEntity'], 5);
    expect(metrics.processedByType['entryLink'], 1);
    expect(metrics.droppedByType['journalEntity'], 2);
  });

  test('toMap includes persisted counters', () {
    const metrics = SyncMetrics(
      processed: 2,
      skipped: 1,
      failures: 0,
      flushes: 1,
      catchupBatches: 4,
      skippedByRetryLimit: 0,
      retriesScheduled: 1,
      circuitOpens: 2,
      dbApplied: 7,
      dbIgnoredByVectorClock: 9,
      conflictsCreated: 11,
      staleAttachmentPurges: 13,
      processedByType: {'journalEntity': 2},
      droppedByType: {'entryLink': 1},
    );

    final map = metrics.toMap();

    expect(map['processed'], 2);
    expect(map['processed.journalEntity'], 2);
    expect(map['droppedByType.entryLink'], 1);
    expect(map['staleAttachmentPurges'], 13);
  });

  test('metrics counters track stale purges and missing base', () {
    final counters = MetricsCounters(collect: true)
      ..incStaleAttachmentPurges()
      ..incDbMissingBase()
      ..incDbMissingBase();

    final snapshot = counters.snapshot(
      retryStateSize: 0,
      circuitIsOpen: false,
    );

    expect(snapshot['staleAttachmentPurges'], 1);
    expect(snapshot['dbMissingBase'], 2);
  });
}
