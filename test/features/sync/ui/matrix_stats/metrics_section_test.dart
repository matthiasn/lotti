import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    'dbApplied': 9,
    'conflictsCreated': 1,
    'queueActive': 4,
    // DB apply group
    'dbIgnoredByVectorClock': 2,
    'dbMissingBase': 0,
    'dbEntryLinkNoop': 5,
    'droppedByType.entryLink': 1,
    // Signals group
    'signalConnectivity': 3,
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

    testWidgets('wraps long localized header copy on a narrow screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 301,
            child: SingleChildScrollView(
              child: SyncMetricsSection(
                metrics: {},
                lastUpdated: null,
                title: 'Metriky synchronizace',
                lastUpdatedLabel: 'Naposledy aktualizováno:',
                onForceRescan: _noop,
                onRetryNow: _noop,
                onCopyDiagnostics: _noop,
                onRefresh: _noop,
                fetchDiagnostics: _emptyDiagnostics,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Metriky synchronizace'), findsOneWidget);
      expect(find.text('Naposledy aktualizováno: —'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncMetricsSection KPIs', () {
    testWidgets('renders the Top KPIs block with exact values', (tester) async {
      await pumpFull(tester);

      expect(find.text('Top KPIs'), findsOneWidget);
      expect(_metricValue('dbApplied', '9'), findsWidgets);
      expect(_metricValue('conflictsCreated', '1'), findsWidgets);
      expect(_metricValue('queueActive', '4'), findsWidgets);
    });
  });

  group('SyncMetricsSection groups', () {
    testWidgets('renders the dropped-by-type tile under DB Apply', (
      tester,
    ) async {
      await pumpFull(tester);

      expect(find.text('Dropped (entryLink)'), findsOneWidget);
      expect(_metricValue('droppedByType.entryLink', '1'), findsWidgets);
    });

    testWidgets('no longer renders the removed pre-queue groups', (
      tester,
    ) async {
      // Throughput and Reliability grouped counters that nothing incremented
      // once the inbound queue became the only receive path; they rendered as
      // permanent zeros and read as "nothing is happening".
      await pumpFull(tester);

      expect(find.text('Throughput'), findsNothing);
      expect(find.text('Reliability'), findsNothing);
    });

    testWidgets('renders DB Apply labels and values', (tester) async {
      await pumpFull(tester);

      expect(find.text('DB Apply'), findsOneWidget);
      // dbApplied and conflictsCreated are also Top KPIs, so their labels
      // legitimately appear twice — once in the KPI block, once in the group.
      expect(find.text('DB Applied'), findsNWidgets(2));
      expect(find.text('Conflicts'), findsNWidgets(2));
      expect(find.text('DB Ignored (VectorClock)'), findsOneWidget);
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
      // The DB Apply header still renders (with an empty grid), but the
      // conditional Signals group is absent.
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
                'signalConnectivity': 5,
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
      expect(find.text('Signals (connectivity)'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the connectivity signal only when it has actually fired',
    (tester) async {
      Future<void> pumpWith(Map<String, int> metrics) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: SyncMetricsSection(
                metrics: metrics,
                lastUpdated: DateTime(2025, 1, 1, 12),
                title: 'Sync Metrics',
                lastUpdatedLabel: 'Last updated:',
                onForceRescan: _noop,
                onRetryNow: _noop,
                onCopyDiagnostics: _noop,
                onRefresh: _noop,
                fetchDiagnostics: _emptyDiagnostics,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpWith(const {'signalConnectivity': 3});
      final messages = tester.element(find.byType(SyncMetricsSection)).messages;
      expect(
        find.text(messages.matrixStatsSignalsConnectivity),
        findsOneWidget,
      );

      // A zero is suppressed rather than shown: the whole point of the
      // dead-counter cleanup is that the panel never renders a confident zero
      // for something that has not happened.
      await pumpWith(const {'signalConnectivity': 0});
      expect(find.text(messages.matrixStatsSignalsConnectivity), findsNothing);
    },
  );
}

void _noop() {}

Future<String> _emptyDiagnostics() async => '';
