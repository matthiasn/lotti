import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_section.dart';

import '../../../../widget_test_utils.dart';

/// Finds the value `Text` rendered inside the metric tile keyed `metric:<key>`.
///
/// Each tile renders the formatted label and `value.toString()` as separate
/// `Text` widgets; scoping by the tile key lets us assert the exact value even
/// when the same number appears in several tiles.
Finder _metricValue(String key, String value) => find.descendant(
  of: find.byKey(Key('metric:$key')),
  matching: find.text(value),
);

void main() {
  // Shared fixture exercising every group: KPIs, throughput, reliability and
  // DB apply. Values are distinct so tile-scoped assertions are unambiguous.
  final fullMetrics = <String, int>{
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

  Future<void> pumpFull(
    WidgetTester tester, {
    void Function()? onForceRescan,
    void Function()? onRetryNow,
    void Function()? onCopyDiagnostics,
    void Function()? onRefresh,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: SyncMetricsSection(
            metrics: fullMetrics,
            lastUpdated: DateTime(2025, 1, 1, 12, 34, 56),
            title: 'Sync Metrics',
            lastUpdatedLabel: 'Last updated:',
            onForceRescan: onForceRescan ?? () {},
            onRetryNow: onRetryNow ?? () {},
            onCopyDiagnostics: onCopyDiagnostics ?? () {},
            onRefresh: onRefresh ?? () {},
            fetchDiagnostics: () async => 'dbMissingBase=0',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('SyncMetricsSection header', () {
    testWidgets('renders title and the formatted HH:mm:ss timestamp', (
      tester,
    ) async {
      await pumpFull(tester);

      expect(find.text('Sync Metrics'), findsOneWidget);
      // _formatTime takes the ISO time substring [11, 19) → "12:34:56".
      expect(find.text('Last updated: 12:34:56'), findsOneWidget);
    });
  });

  group('SyncMetricsSection KPIs', () {
    testWidgets('renders the Top KPIs block with exact values', (tester) async {
      await pumpFull(tester);

      expect(find.text('Top KPIs'), findsOneWidget);
      expect(_metricValue('processed', '12'), findsWidgets);
      expect(_metricValue('failures', '1'), findsWidgets);
      expect(_metricValue('retriesScheduled', '3'), findsWidgets);
    });
  });

  group('SyncMetricsSection groups', () {
    testWidgets('renders Throughput labels and values', (tester) async {
      await pumpFull(tester);

      expect(find.text('Throughput'), findsOneWidget);
      expect(find.text('Catch-up Batches'), findsOneWidget);
      expect(find.text('Processed (journalEntity)'), findsOneWidget);
      expect(_metricValue('flushes', '2'), findsWidgets);
      expect(_metricValue('catchupBatches', '1'), findsWidgets);
      expect(_metricValue('processed.journalEntity', '7'), findsWidgets);
    });

    testWidgets('renders Reliability and dropped-by-type tile', (tester) async {
      await pumpFull(tester);

      expect(find.text('Reliability'), findsOneWidget);
      // droppedByType.* belongs to the DB Apply group, not Reliability.
      expect(find.text('Dropped (entryLink)'), findsOneWidget);
      expect(_metricValue('droppedByType.entryLink', '1'), findsWidgets);
      expect(_metricValue('skipped', '0'), findsWidgets);
      expect(_metricValue('circuitOpens', '0'), findsWidgets);
    });

    testWidgets('renders DB Apply labels and values', (tester) async {
      await pumpFull(tester);

      expect(find.text('DB Apply'), findsOneWidget);
      expect(find.text('DB Applied'), findsOneWidget);
      expect(find.text('DB Ignored (VectorClock)'), findsOneWidget);
      expect(find.text('Conflicts'), findsOneWidget);
      expect(_metricValue('dbApplied', '9'), findsWidgets);
      expect(_metricValue('dbIgnoredByVectorClock', '2'), findsWidgets);
      expect(_metricValue('conflictsCreated', '1'), findsWidgets);
    });

    testWidgets('does not render the removed Prefetched label', (tester) async {
      await pumpFull(tester);

      expect(find.text('Prefetched'), findsNothing);
    });
  });

  group('SyncMetricsSection actions', () {
    testWidgets('each action button invokes exactly its own callback', (
      tester,
    ) async {
      var force = 0;
      var retry = 0;
      var copy = 0;
      var refresh = 0;

      await pumpFull(
        tester,
        onForceRescan: () => force++,
        onRetryNow: () => retry++,
        onCopyDiagnostics: () => copy++,
        onRefresh: () => refresh++,
      );

      await tester.tap(find.byKey(const Key('matrixStats.forceRescan')));
      await tester.pump();
      expect(force, 1);
      expect(retry, 0);
      expect(copy, 0);
      expect(refresh, 0);

      await tester.tap(find.byKey(const Key('matrixStats.retryNow')));
      await tester.pump();
      expect(retry, 1);

      await tester.tap(find.byKey(const Key('matrixStats.copyDiagnostics')));
      await tester.pump();
      expect(copy, 1);

      await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
      await tester.pump();
      expect(refresh, 1);
    });
  });

  group('SyncMetricsSection diagnostics', () {
    testWidgets('embeds the collapsed diagnostics panel', (tester) async {
      await pumpFull(tester);

      expect(find.text('Diagnostics'), findsOneWidget);
      // Panel is collapsed by default, so its parsed rows are not rendered.
      expect(find.text('dbMissingBase: 0'), findsNothing);
    });
  });

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
