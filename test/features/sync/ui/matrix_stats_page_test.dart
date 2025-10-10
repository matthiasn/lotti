import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
