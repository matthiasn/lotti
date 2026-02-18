import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('MetricsGrid', () {
    final testEntries = [
      const MapEntry('processed', 10),
      const MapEntry('skipped', 2),
      const MapEntry('failures', 1),
    ];

    testWidgets('renders labels and values for each entry', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k.toUpperCase(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PROCESSED'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('SKIPPED'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('FAILURES'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('applies correct Key to each tile', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      for (final e in testEntries) {
        expect(
          find.byKey(Key('metric:${e.key}')),
          findsOneWidget,
          reason: 'tile for ${e.key} should have correct key',
        );
      }
    });

    testWidgets('renders empty grid when entries is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: const [],
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MetricTile), findsNothing);
    });

    testWidgets('transforms labels using labelFor function', (tester) async {
      final labelMap = {'processed': 'Synced', 'failures': 'Errors'};
      final entries = [
        const MapEntry('processed', 42),
        const MapEntry('failures', 3),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: entries,
              labelFor: (k) => labelMap[k] ?? k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Errors'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Raw keys should not appear as labels
      expect(find.text('processed'), findsNothing);
      expect(find.text('failures'), findsNothing);
    });

    testWidgets('uses 2 columns at narrow width (< 380)', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 370,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      // With 2 columns and 3 items, all tiles should still render
      expect(find.byType(MetricTile), findsNWidgets(3));

      // Verify tile width is based on 2-column layout:
      // (370 - (2-1)*8) / 2 = 181
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo(181, 1));
    });

    testWidgets('uses 3 columns at medium width (380-559)', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MetricTile), findsNWidgets(3));

      // (400 - (3-1)*8) / 3 = 128
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo(128, 1));
    });
  });
}
