import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/ui/matrix_stats/matrix_metrics_panel.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_section.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Pump one full poll cycle (slightly over the poll interval).
Future<void> _pumpPollCycle(WidgetTester tester) async {
  await tester.pump(MatrixSyncMetricsPanelState.pollInterval);
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();

    when(() => mockMatrixService.getSyncMetrics()).thenAnswer(
      (_) async => SyncMetrics.fromMap({
        'processed': 2,
        'skipped': 1,
        'failures': 0,
      }),
    );
    when(
      () => mockMatrixService.getSyncDiagnosticsText(),
    ).thenAnswer((_) async => 'diagnostics');
    when(() => mockMatrixService.forceRescan()).thenAnswer((_) async {});
    when(() => mockMatrixService.retryNow()).thenAnswer((_) async {});
  });

  testWidgets('initial metrics load prevents overlapping timer polls', (
    tester,
  ) async {
    final initial = Completer<SyncMetrics?>();
    when(
      () => mockMatrixService.getSyncMetrics(),
    ).thenAnswer((_) => initial.future);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MatrixSyncMetricsPanel(),
        overrides: [matrixServiceProvider.overrideWithValue(mockMatrixService)],
      ),
    );
    await _pumpPollCycle(tester);
    await _pumpPollCycle(tester);
    verify(() => mockMatrixService.getSyncMetrics()).called(1);
    initial.complete(SyncMetrics.fromMap({'dbApplied': 7}));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<SyncMetricsSection>(find.byType(SyncMetricsSection))
          .metrics['dbApplied'],
      7,
    );
    await _pumpPollCycle(tester);
    verify(() => mockMatrixService.getSyncMetrics()).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'manual refreshes during a slow poll coalesce into one fresh load',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncMetricsPanel(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();
      clearInteractions(mockMatrixService);
      final pending = Completer<SyncMetrics?>();
      final refreshed = Completer<SyncMetrics?>();
      var calls = 0;
      when(() => mockMatrixService.getSyncMetrics()).thenAnswer((_) {
        calls++;
        return calls == 1 ? pending.future : refreshed.future;
      });
      await _pumpPollCycle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.byKey(
            Key(
              i == 0 ? 'matrixStats.retryNow' : 'matrixStats.refresh.metrics',
            ),
          ),
        );
        await tester.pump();
      }
      expect(
        calls,
        1,
        reason: 'manual actions must not overlap the running poll',
      );
      pending.complete(SyncMetrics.fromMap({'dbApplied': 3}));
      await tester.pump();
      expect(
        calls,
        2,
        reason: 'one trailing load must observe post-action state',
      );
      await _pumpPollCycle(tester);
      expect(calls, 2);
      refreshed.complete(SyncMetrics.fromMap({'dbApplied': 8}));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<SyncMetricsSection>(find.byType(SyncMetricsSection))
            .metrics['dbApplied'],
        8,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('disposal discards a pending manual refresh', (tester) async {
    final pending = Completer<SyncMetrics?>();
    when(
      () => mockMatrixService.getSyncMetrics(),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MatrixSyncMetricsPanel(),
        overrides: [matrixServiceProvider.overrideWithValue(mockMatrixService)],
      ),
    );
    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(SyncMetrics.fromMap({'dbApplied': 9}));
    await tester.pump();
    await _pumpPollCycle(tester);
    verify(() => mockMatrixService.getSyncMetrics()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null metrics result still runs the pending manual refresh', (
    tester,
  ) async {
    final pending = Completer<SyncMetrics?>();
    var calls = 0;
    when(() => mockMatrixService.getSyncMetrics()).thenAnswer((_) {
      calls++;
      return calls == 1
          ? pending.future
          : Future.value(SyncMetrics.fromMap({'dbApplied': 11}));
    });
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MatrixSyncMetricsPanel(),
        overrides: [matrixServiceProvider.overrideWithValue(mockMatrixService)],
      ),
    );
    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();
    expect(calls, 1);
    pending.complete(null);
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(
      tester
          .widget<SyncMetricsSection>(find.byType(SyncMetricsSection))
          .metrics['dbApplied'],
      11,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in ['forceRescan', 'retryNow']) {
    testWidgets(
      '$action completing after disposal does not refresh providers',
      (tester) async {
        final pending = Completer<void>();
        when(
          () => mockMatrixService.forceRescan(),
        ).thenAnswer((_) => pending.future);
        when(
          () => mockMatrixService.retryNow(),
        ).thenAnswer((_) => pending.future);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const MatrixSyncMetricsPanel(),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );
        await tester.pump();
        clearInteractions(mockMatrixService);
        await tester.tap(find.byKey(Key('matrixStats.$action')));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
        verifyNever(() => mockMatrixService.getSyncMetrics());
      },
    );
  }

  testWidgets('MatrixSyncMetricsPanel renders metrics and handles actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MatrixSyncMetricsPanel(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('Last updated:'), findsOneWidget);
    verify(() => mockMatrixService.getSyncMetrics()).called(greaterThan(0));

    await tester.tap(find.byKey(const Key('matrixStats.forceRescan')));
    await tester.pump();
    verify(() => mockMatrixService.forceRescan()).called(1);

    await tester.tap(find.byKey(const Key('matrixStats.retryNow')));
    await tester.pump();
    verify(() => mockMatrixService.retryNow()).called(1);

    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();
    // Allow refresh to complete.
    await tester.pump(const Duration(milliseconds: 10));

    verify(() => mockMatrixService.getSyncMetrics()).called(greaterThan(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'pollInterval is at least 5 seconds — the 2-second cadence used '
    'until 2026-05-12 drove `GROUP BY status, producer FROM '
    'inbound_event_queue` to 223 hits/day on the desktop slow-query '
    'log; widening the window cuts that polling pressure without '
    'losing perceived liveness',
    (tester) async {
      expect(
        MatrixSyncMetricsPanelState.pollInterval,
        greaterThanOrEqualTo(const Duration(seconds: 5)),
      );
    },
  );

  testWidgets(
    'poll timer fires after pollInterval and calls getSyncMetrics again',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncMetricsPanel(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      // Initial pump — triggers _refreshOnce.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      clearInteractions(mockMatrixService);

      // Advance past the poll interval to trigger the periodic timer.
      await _pumpPollCycle(tester);

      verify(() => mockMatrixService.getSyncMetrics()).called(greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'poll timer skips fetch when app is backgrounded '
    '(didChangeAppLifecycleState paused → resumed)',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncMetricsPanel(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      clearInteractions(mockMatrixService);

      // Background the app — _appActive becomes false.
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );

      // Poll cycle fires but should not call getSyncMetrics because
      // _appActive is false.
      await _pumpPollCycle(tester);
      verifyNever(() => mockMatrixService.getSyncMetrics());

      // Resume the app — _appActive becomes true.
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      // Next poll cycle fires and should call getSyncMetrics again.
      await _pumpPollCycle(tester);
      verify(() => mockMatrixService.getSyncMetrics()).called(greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'fetchDiagnostics callback calls getSyncDiagnosticsText when '
    'DiagnosticsPanel is expanded',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncMetricsPanel(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      clearInteractions(mockMatrixService);

      // Expand the DiagnosticsPanel expansion tile.
      final diagnosticsTile = find.text('Diagnostics');
      await tester.ensureVisible(diagnosticsTile);
      await tester.tap(diagnosticsTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // The fetchDiagnostics callback (lines 147–148) should have been invoked.
      verify(() => mockMatrixService.getSyncDiagnosticsText()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
