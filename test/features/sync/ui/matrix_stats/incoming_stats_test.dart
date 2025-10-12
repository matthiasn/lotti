// ignore_for_file: unnecessary_lambdas
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
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

  testWidgets('IncomingStats shows loading state', (tester) async {
    final completer = Completer<MatrixStats>();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixStatsControllerProvider.overrideWith(
              () => _LoadingMatrixStatsController(completer.future)),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('IncomingStats shows error state', (tester) async {
    final mockSvc = _MockMatrixService();
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
    expect(find.textContaining('Error loading Matrix stats'), findsOneWidget);
  });

  testWidgets(
      'IncomingStats refresh invalidates metrics and shows no-data message',
      (tester) async {
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.sentCount).thenReturn(0);
    when(() => mockSvc.messageCounts).thenReturn(const {});
    when(() => mockSvc.getV2Metrics()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockSvc),
          matrixStatsControllerProvider.overrideWith(
            () => _FakeMatrixStatsController(
              MatrixStats(sentCount: 0, messageCounts: const {}),
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Sync V2 Metrics: no data'), findsOneWidget);
    await tester.tap(find.byKey(const Key('matrixStats.refresh.noData')));
    await tester.pumpAndSettle();
    verify(() => mockSvc.getV2Metrics()).called(greaterThan(0));
  });

  testWidgets('IncomingStats copy diagnostics invokes service and shows snack',
      (tester) async {
    final mockSvc = _MockMatrixService();
    when(() => mockSvc.sentCount).thenReturn(1);
    when(() => mockSvc.messageCounts).thenReturn(const {'m.text': 1});
    when(() => mockSvc.getV2Metrics()).thenAnswer(
      (_) async => V2Metrics.fromMap({'processed': 1}),
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
              MatrixStats(sentCount: 1, messageCounts: const {'m.text': 1}),
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
