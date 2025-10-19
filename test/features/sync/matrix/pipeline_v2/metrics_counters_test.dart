import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/metrics_counters.dart';

void main() {
  test('buildFlushLog works when processedByType is empty', () {
    final metrics = MetricsCounters(collect: true);
    final log = metrics.buildFlushLog(retriesPending: 0);
    expect(log, contains('flush='));
    expect(log, isNot(contains('byType=')));
  });

  test('buildFlushLog includes sorted byType breakdown', () {
    final metrics = MetricsCounters(collect: true)
      ..incProcessedWithType('journalEntity')
      ..incProcessedWithType('entryLink')
      ..incProcessedWithType('journalEntity');
    final log = metrics.buildFlushLog(retriesPending: 0);
    expect(log, contains('byType=entryLink=1,journalEntity=2'));
  });

  test('recordLookBehindMerge tracks count and last tail', () {
    final metrics = MetricsCounters(collect: true)
      ..recordLookBehindMerge(100)
      ..recordLookBehindMerge(200)
      ..recordLookBehindMerge(300);
    final snapshot = metrics.snapshot(retryStateSize: 0, circuitIsOpen: false);
    expect(snapshot['lookBehindMerges'], 3);
    expect(snapshot['lastLookBehindTail'], 300);
  });

  test('recordLookBehindMerge respects collect flag', () {
    final metrics = MetricsCounters()..recordLookBehindMerge(100);
    final snapshot = metrics.snapshot(retryStateSize: 0, circuitIsOpen: false);
    expect(snapshot['lookBehindMerges'], 0);
    expect(snapshot['lastLookBehindTail'], 0);
  });
}
