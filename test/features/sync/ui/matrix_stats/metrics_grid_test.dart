import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('MetricsGrid renders tiles for entries', (tester) async {
    final entries = [
      const MapEntry('processed', 10),
      const MapEntry('skipped', 2),
      const MapEntry('failures', 1),
    ];

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          width: 360,
          child: MetricsGrid(
            entries: entries,
            labelFor: (k) => k,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('processed'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('skipped'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('failures'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
