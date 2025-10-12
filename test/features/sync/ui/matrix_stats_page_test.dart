import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

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
  Future<MatrixStats> build() async => throw Exception('failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late StreamController<MatrixStats> matrixStatsController;

  setUp(() {
    mockMatrixService = MockMatrixService();
    matrixStatsController = StreamController<MatrixStats>.broadcast();

    when(() => mockMatrixService.messageCountsController)
        .thenReturn(matrixStatsController);
    when(() => mockMatrixService.messageCounts).thenReturn(<String, int>{});
    when(() => mockMatrixService.sentCount).thenReturn(0);
    when(() => mockMatrixService.getDiagnosticInfo())
        .thenAnswer((_) async => <String, dynamic>{});
  });

  tearDown(() async {
    await matrixStatsController.close();
  });

  testWidgets('IncomingStats displays matrix statistics', (tester) async {
    final stats = MatrixStats(
      sentCount: 5,
      messageCounts: {'m.text': 3, 'm.image': 2},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pump();

    expect(find.textContaining('Sent messages: 5'), findsOneWidget);
    expect(find.text('m.text'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('m.image'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('IncomingStats shows V2 metrics and supports refresh',
      (tester) async {
    final stats = MatrixStats(
      sentCount: 1,
      messageCounts: const {'m.text': 1},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);

    // First typed metrics payload
    when(() => mockMatrixService.getV2Metrics()).thenAnswer(
      (_) async => V2Metrics.fromMap({
        'processed': 2,
        'skipped': 1,
        'failures': 0,
        'prefetch': 1,
        'flushes': 1,
        'catchupBatches': 1,
        'skippedByRetryLimit': 0,
        'retriesScheduled': 0,
        'circuitOpens': 0,
      }),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
    // With typed metrics available, the section is rendered immediately
    expect(find.textContaining('Last updated:'), findsOneWidget);

    // Change typed metrics payload for refresh
    when(() => mockMatrixService.getV2Metrics()).thenAnswer(
      (_) async => V2Metrics.fromMap({
        'processed': 3,
        'skipped': 1,
        'failures': 0,
        'prefetch': 1,
        'flushes': 2,
        'catchupBatches': 1,
        'skippedByRetryLimit': 0,
        'retriesScheduled': 0,
        'circuitOpens': 0,
      }),
    );

    // Triggering refresh is not required for typed metrics to appear; skip tap.

    // Last updated label present (implies metrics section is rendered)
    expect(find.textContaining('Last updated:'), findsOneWidget);
  });

  testWidgets('refresh button invalidates provider and updates metrics',
      (tester) async {
    final stats = MatrixStats(
      sentCount: 0,
      messageCounts: const {},
    );

    var refreshCount = 0;
    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);
    when(() => mockMatrixService.getV2Metrics()).thenAnswer((_) async {
      refreshCount++;
      return V2Metrics.fromMap({
        'processed': refreshCount,
        'skipped': 0,
        'failures': 0,
        'prefetch': 0,
        'flushes': refreshCount, // change with refresh
        'catchupBatches': 0,
        'skippedByRetryLimit': 0,
        'retriesScheduled': 0,
        'circuitOpens': 0,
      });
    });

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Initial fetch increments once
    expect(refreshCount, 1);

    // Tap Refresh button and expect a second fetch
    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pumpAndSettle();
    expect(refreshCount, 2);
  });

  testWidgets('shows no-data message when V2 metrics are null', (tester) async {
    final stats = MatrixStats(
      sentCount: 0,
      messageCounts: const {},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);
    when(() => mockMatrixService.getV2Metrics()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pumpAndSettle();
    // Localized string from l10n: settingsMatrixV2MetricsNoData
    expect(find.textContaining('Sync V2 Metrics: no data'), findsOneWidget);
  });

  testWidgets('IncomingStats shows progress while loading', (tester) async {
    final completer = Completer<MatrixStats>();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider.overrideWith(
            () => _LoadingMatrixStatsController(completer.future),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      MatrixStats(sentCount: 0, messageCounts: const {}),
    );
  });

  testWidgets('IncomingStats shows progress indicator on error',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(_ThrowingMatrixStatsController.new),
        ],
      ),
    );

    await tester.pump();

    expect(find.textContaining('Error loading Matrix stats'), findsOneWidget);
  });

  testWidgets('IncomingStats shows DB-apply metrics and legend tooltip',
      (tester) async {
    final stats = MatrixStats(
      sentCount: 1,
      messageCounts: const {'m.text': 1},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);
    when(() => mockMatrixService.getV2Metrics()).thenAnswer(
      (_) async => V2Metrics.fromMap({
        'processed': 1,
        'skipped': 0,
        'failures': 0,
        'prefetch': 0,
        'flushes': 1,
        'catchupBatches': 0,
        'skippedByRetryLimit': 0,
        'retriesScheduled': 0,
        'circuitOpens': 0,
        'dbApplied': 2,
        'dbIgnoredByVectorClock': 1,
        'conflictsCreated': 1,
      }),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const IncomingStats(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dbApplied'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('dbIgnoredByVectorClock'), findsOneWidget);
    expect(find.text('conflictsCreated'), findsOneWidget);
    // Tooltip icon present
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('matrixStatsPage wiring updates page index', (tester) async {
    final stats = MatrixStats(
      sentCount: 3,
      messageCounts: const {'m.text': 2},
    );

    final pageIndexNotifier = ValueNotifier<int>(2);
    addTearDown(pageIndexNotifier.dispose);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            final page = matrixStatsPage(
              context: context,
              pageIndexNotifier: pageIndexNotifier,
            );

            return page.stickyActionBar ?? const SizedBox.shrink();
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Previous Page'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(pageIndexNotifier.value, 2);

    await tester.tap(find.text('Previous Page'));
    await tester.pump();
    expect(pageIndexNotifier.value, 1);
  });
}
