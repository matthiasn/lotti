import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats/message_counts_view.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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

    when(
      () => mockMatrixService.messageCountsController,
    ).thenReturn(matrixStatsController);
    when(() => mockMatrixService.messageCounts).thenReturn(<String, int>{});
    when(() => mockMatrixService.sentCount).thenReturn(0);
  });

  tearDown(() async {
    await matrixStatsController.close();
  });

  testWidgets('MessageCountsView renders stats from controller', (
    tester,
  ) async {
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
          matrixStatsControllerProvider.overrideWith(
            () => _FakeMatrixStatsController(stats),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Sent messages: 2'), findsOneWidget);
    expect(find.text('Sent (m.image)'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('the sent-messages heading matches the other group headings', (
    tester,
  ) async {
    // This label names the grid beneath it, exactly as "Top KPIs" and the
    // grouped section headings do. It used to be a bare
    // `TextStyle(fontWeight: bold)`, which took its size from whatever the
    // ambient Material theme supplied and outweighed its peers.
    const stats = MatrixStats(
      sentCount: 2,
      messageCounts: {'m.text': 1},
    );

    when(() => mockMatrixService.sentCount).thenReturn(stats.sentCount);
    when(() => mockMatrixService.messageCounts).thenReturn(stats.messageCounts);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MessageCountsView(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsControllerProvider.overrideWith(
            () => _FakeMatrixStatsController(stats),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final tokens = tester.element(find.byType(MessageCountsView)).designTokens;
    final heading = tester.widget<Text>(
      find.textContaining('Sent messages: 2'),
    );

    expect(
      heading.style?.fontSize,
      tokens.typography.styles.subtitle.subtitle2.fontSize,
    );
    expect(heading.style?.fontWeight, tokens.typography.weight.semiBold);
    expect(heading.style?.color, tokens.colors.text.highEmphasis);
    // `bold` is the tier above; using it here made this one heading shout
    // over the identically-ranked ones on the same page.
    expect(
      heading.style?.fontWeight,
      isNot(tokens.typography.weight.bold),
    );
  });
}
