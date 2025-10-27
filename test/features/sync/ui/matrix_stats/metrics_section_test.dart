import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_section.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets(
      'SyncMetricsSection renders KPIs, groups, labels, actions, and diagnostics',
      (tester) async {
    final metrics = <String, int>{
      // KPIs
      'processed': 12,
      'failures': 1,
      'retriesScheduled': 3,
      // Throughput
      'prefetch': 5,
      'flushes': 2,
      'catchupBatches': 1,
      'processed.journalEntity': 7,
      // Reliability
      'skipped': 0,
      'skippedByRetryLimit': 0,
      'circuitOpens': 0,
      'droppedByType.entryLink': 1,
      // DB
      'dbApplied': 9,
      'dbIgnoredByVectorClock': 2,
      'conflictsCreated': 1,
      'dbMissingBase': 0,
    };

    var force = 0;
    var retry = 0;
    var copy = 0;
    var refresh = 0;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: SyncMetricsSection(
            metrics: metrics,
            lastUpdated: DateTime(2025, 1, 1, 12),
            title: 'Sync Metrics',
            lastUpdatedLabel: 'Last updated:',
            onForceRescan: () => force++,
            onRetryNow: () => retry++,
            onCopyDiagnostics: () => copy++,
            onRefresh: () => refresh++,
            fetchDiagnostics: () async => 'dbMissingBase=0',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Header labels
    expect(find.text('Sync Metrics'), findsOneWidget);
    expect(find.textContaining('Last updated:'), findsOneWidget);

    // KPIs section present
    expect(find.text('Top KPIs'), findsOneWidget);

    // Group headers
    expect(find.text('Throughput'), findsOneWidget);
    expect(find.text('Reliability'), findsOneWidget);
    expect(find.text('DB Apply'), findsOneWidget);

    // Friendly labels
    expect(find.text('Processed'), findsWidgets);
    expect(find.text('Prefetched'), findsOneWidget);
    expect(find.text('Catch-up Batches'), findsOneWidget);
    expect(find.text('Dropped (entryLink)'), findsOneWidget);
    expect(find.text('Processed (journalEntity)'), findsOneWidget);
    expect(find.text('DB Applied'), findsOneWidget);
    expect(find.text('DB Ignored (VectorClock)'), findsOneWidget);
    expect(find.text('Conflicts'), findsOneWidget);

    // Action bar
    await tester.tap(find.byKey(const Key('matrixStats.forceRescan')));
    await tester.tap(find.byKey(const Key('matrixStats.retryNow')));
    await tester.tap(find.byKey(const Key('matrixStats.copyDiagnostics')));
    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();
    expect(force, 1);
    expect(retry, 1);
    expect(copy, 1);
    expect(refresh, 1);

    // Diagnostics panel present
    expect(find.text('Diagnostics'), findsOneWidget);
  });
}
