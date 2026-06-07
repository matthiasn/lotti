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
      expect(find.text('Prefetched'), findsNothing);
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
    },
  );

  testWidgets(
    'empty metrics hide the KPI block and render the em-dash timestamp',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: SyncMetricsSection(
              metrics: const {},
              lastUpdated: null,
              title: 'Sync Metrics',
              lastUpdatedLabel: 'Last updated:',
              onForceRescan: () {},
              onRetryNow: () {},
              onCopyDiagnostics: () {},
              onRefresh: () {},
              fetchDiagnostics: () async => '',
            ),
          ),
        ),
      );
      await tester.pump();

      // No KPI entries → the KPI header is omitted entirely.
      expect(find.text('Top KPIs'), findsNothing);
      // Null lastUpdated renders the em-dash placeholder.
      expect(find.textContaining('Last updated: \u2014'), findsOneWidget);
      // The fixed group headers still render (with empty grids), but the
      // conditional Signals group is absent.
      expect(find.text('Throughput'), findsOneWidget);
      expect(find.text('Reliability'), findsOneWidget);
      expect(find.text('DB Apply'), findsOneWidget);
      expect(find.text('Signals'), findsNothing);
    },
  );

  testWidgets(
    'Signals group appears only when a signal metric is non-zero',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: SyncMetricsSection(
              metrics: const {
                'signalClientStream': 5,
                // Zero-valued signals are filtered out of the group.
                'signalConnectivity': 0,
              },
              lastUpdated: DateTime(2025, 1, 1, 12),
              title: 'Sync Metrics',
              lastUpdatedLabel: 'Last updated:',
              onForceRescan: () {},
              onRetryNow: () {},
              onCopyDiagnostics: () {},
              onRefresh: () {},
              fetchDiagnostics: () async => '',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Signals'), findsOneWidget);
      expect(find.text('Signals (client stream)'), findsOneWidget);
      expect(find.text('Signals (connectivity)'), findsNothing);
    },
  );
}
