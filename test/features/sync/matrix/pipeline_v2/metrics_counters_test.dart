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
}
