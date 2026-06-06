import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Future<void> pumpChart(
    WidgetTester tester,
    List<DailyWakeCountBucket> buckets,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EvolutionWakeActivityChart(buckets: buckets),
      ),
    );
    await tester.pump();
  }

  List<DailyWakeCountBucket> makeBuckets(List<int> counts) => [
    for (final (i, count) in counts.indexed)
      DailyWakeCountBucket(date: DateTime(2026, 5, 1 + i), wakeCount: count),
  ];

  group('EvolutionWakeActivityChart', () {
    testWidgets('renders nothing for an empty bucket list', (tester) async {
      await pumpChart(tester, const []);

      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(
        tester.getSize(find.byType(EvolutionWakeActivityChart)),
        Size.zero,
      );
    });

    testWidgets('renders one bar per bucket and a single date label', (
      tester,
    ) async {
      await pumpChart(tester, makeBuckets([3]));

      expect(find.byType(FractionallySizedBox), findsOneWidget);
      expect(find.text('May 1'), findsOneWidget);
    });

    testWidgets('scales bar heights against the busiest day', (tester) async {
      await pumpChart(tester, makeBuckets([0, 2, 4]));

      final factors = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.heightFactor)
          .toList();

      expect(factors, hasLength(3));
      // Zero wakes renders a 0.04 hairline; the busiest day fills the
      // 0.16 + 0.84 range; intermediate days scale linearly.
      expect(factors[0], closeTo(0.04, 0.001));
      expect(factors[1], closeTo(0.16 + 0.5 * 0.84, 0.001));
      expect(factors[2], closeTo(1.0, 0.001));
    });

    testWidgets('labels the five quartile dates for a 30-day window', (
      tester,
    ) async {
      await pumpChart(tester, makeBuckets(List.filled(30, 1)));

      // Indexes 0, 7, 15, 22, 29 → May 1/8/16/23/30.
      for (final label in ['May 1', 'May 8', 'May 16', 'May 23', 'May 30']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byType(FractionallySizedBox), findsNWidgets(30));
    });
  });
}
