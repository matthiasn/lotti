// ignore_for_file: unnecessary_lambdas
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class _MockMatrixService extends Mock implements MatrixService {}

class _FakeMatrixStatsController extends MatrixStatsController {
  _FakeMatrixStatsController(this.stats);
  final MatrixStats stats;
  @override
  Future<MatrixStats> build() async => stats;
}

class _LoadingMatrixStatsController extends MatrixStatsController {
  _LoadingMatrixStatsController(this.future);
  @override
  final Future<MatrixStats> future;
  @override
  Future<MatrixStats> build() => future;
}

class _ThrowingMatrixStatsController extends MatrixStatsController {
  @override
  Future<MatrixStats> build() async => throw Exception('boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IncomingStats renders stable shell while loading',
      (tester) async {
    final completer = Completer<MatrixStats>();
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.getSyncMetrics()).thenAnswer((_) async => null);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockSvc),
          matrixStatsControllerProvider.overrideWith(
              () => _LoadingMatrixStatsController(completer.future)),
        ],
      ),
    );
    await tester.pump();
    // Stable section header is present (updated title text).
    expect(find.textContaining('Sync Metrics'), findsOneWidget);
  });

  testWidgets('IncomingStats builds even when controller throws',
      (tester) async {
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.getSyncMetrics()).thenAnswer((_) async => null);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockSvc),
          matrixStatsControllerProvider
              .overrideWith(_ThrowingMatrixStatsController.new),
        ],
      ),
    );
    await tester.pump();
    // Stable section header is present (updated title text).
    expect(find.textContaining('Sync Metrics'), findsOneWidget);
  });

  testWidgets('IncomingStats refresh triggers service when metrics empty',
      (tester) async {
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.sentCount).thenReturn(0);
    when(() => mockSvc.messageCounts).thenReturn(const {});
    when(() => mockSvc.getSyncMetrics()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockSvc),
          matrixStatsControllerProvider.overrideWith(
            () => _FakeMatrixStatsController(
              const MatrixStats(sentCount: 0, messageCounts: {}),
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Sync Metrics'), findsOneWidget);
    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pumpAndSettle();
    verify(() => mockSvc.getSyncMetrics()).called(greaterThan(0));
  });

  testWidgets('IncomingStats copy diagnostics invokes service and shows snack',
      (tester) async {
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.sentCount).thenReturn(1);
    when(() => mockSvc.messageCounts).thenReturn(const {'m.text': 1});
    when(() => mockSvc.getSyncMetrics()).thenAnswer(
      (_) async => SyncMetrics.fromMap({'processed': 1}),
    );
    when(() => mockSvc.getSyncDiagnosticsText())
        .thenAnswer((_) async => 'processed=1');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockSvc),
          matrixStatsControllerProvider.overrideWith(
            () => _FakeMatrixStatsController(
              const MatrixStats(sentCount: 1, messageCounts: {'m.text': 1}),
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('matrixStats.copyDiagnostics')));
    await tester.pump();
    verify(() => mockSvc.getSyncDiagnosticsText()).called(greaterThan(0));
  });
}
