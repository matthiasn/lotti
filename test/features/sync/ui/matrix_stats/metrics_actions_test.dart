import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_actions.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('MetricsActions shows labeled buttons and triggers callbacks',
      (tester) async {
    var forceRescan = 0;
    var retryNow = 0;
    var copied = 0;
    var refreshed = 0;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        MetricsActions(
          onForceRescan: () => forceRescan++,
          onRetryNow: () => retryNow++,
          onCopyDiagnostics: () => copied++,
          onRefresh: () => refreshed++,
        ),
      ),
    );

    // Legend tooltip present
    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
    expect(
        tooltips.any((t) => t.message?.startsWith('Legend:') ?? false), isTrue);

    await tester.tap(find.byKey(const Key('matrixStats.forceRescan')));
    await tester.tap(find.byKey(const Key('matrixStats.retryNow')));
    await tester.tap(find.byKey(const Key('matrixStats.copyDiagnostics')));
    await tester.tap(find.byKey(const Key('matrixStats.refresh.metrics')));
    await tester.pump();

    expect(forceRescan, 1);
    expect(retryNow, 1);
    expect(copied, 1);
    expect(refreshed, 1);

    // Labels visible
    expect(find.text('Legend'), findsOneWidget);
    expect(find.text('Force Rescan'), findsOneWidget);
    expect(find.text('Retry Now'), findsOneWidget);
    expect(find.text('Copy Diagnostics'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });
}
