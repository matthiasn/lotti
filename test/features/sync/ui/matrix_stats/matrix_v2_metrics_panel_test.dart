import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/ui/matrix_stats/matrix_v2_metrics_panel.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();

    when(() => mockMatrixService.getV2Metrics()).thenAnswer(
      (_) async => V2Metrics.fromMap({
        'processed': 2,
        'skipped': 1,
        'failures': 0,
      }),
    );
    when(() => mockMatrixService.getSyncDiagnosticsText())
        .thenAnswer((_) async => 'diagnostics');
    when(() => mockMatrixService.forceV2Rescan()).thenAnswer((_) async {});
    when(() => mockMatrixService.retryV2Now()).thenAnswer((_) async {});
  });

  testWidgets('MatrixV2MetricsPanel renders metrics and handles actions',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MatrixV2MetricsPanel(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('Last updated:'), findsOneWidget);
    verify(() => mockMatrixService.getV2Metrics()).called(greaterThan(0));

    await tester.tap(find.byKey(const Key('matrixStats.forceRescan')));
    await tester.pump();
    verify(() => mockMatrixService.forceV2Rescan()).called(1);

    await tester.tap(find.byKey(const Key('matrixStats.retryNow')));
    await tester.pump();
    verify(() => mockMatrixService.retryV2Now()).called(1);

    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();
    // Allow refresh to complete.
    await tester.pump(const Duration(milliseconds: 10));

    verify(() => mockMatrixService.getV2Metrics()).called(greaterThan(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
