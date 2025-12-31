import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats/message_counts_view.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class _FakeMatrixStatsController extends MatrixStatsController {
  _FakeMatrixStatsController(this.stats);

  final MatrixStats stats;

  @override
  Future<MatrixStats> build() async => stats;
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

  testWidgets('MessageCountsView renders stats from controller',
      (tester) async {
    const stats = MatrixStats(
      sentCount: 2,
      messageCounts: {'m.text': 1, 'm.image': 1},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MessageCountsView(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Sent messages: 2'), findsOneWidget);
    expect(find.text('Sent (m.image)'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('MessageCountsView closes subscription on dispose',
      (tester) async {
    const stats = MatrixStats(
      sentCount: 1,
      messageCounts: {'m.text': 1},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MessageCountsView(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );

    await tester.pump();

    final state = tester.state<MessageCountsViewState>(
      find.byType(MessageCountsView),
    );
    expect(state.subscriptionClosed, isFalse);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox.shrink(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider
              .overrideWith(() => _FakeMatrixStatsController(stats)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(state.subscriptionClosed, isTrue);
  });
}
