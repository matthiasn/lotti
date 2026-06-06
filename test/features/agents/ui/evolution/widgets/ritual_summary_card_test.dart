import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_summary_card.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  RitualSummaryMetrics makeMetrics({
    int lifetimeWakeCount = 1234,
    int wakesSinceLastSession = 7,
    int totalTokenUsageSinceLastSession = 56789,
    List<DailyWakeCountBucket> dailyWakeCounts = const [],
  }) {
    return RitualSummaryMetrics(
      lifetimeWakeCount: lifetimeWakeCount,
      wakesSinceLastSession: wakesSinceLastSession,
      totalTokenUsageSinceLastSession: totalTokenUsageSinceLastSession,
      dailyWakeCounts: dailyWakeCounts,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    RitualSummaryMetrics metrics, {
    bool compact = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: RitualSummaryCard(metrics: metrics, compact: compact),
        ),
      ),
    );
    await tester.pump();
  }

  group('RitualSummaryCard', () {
    testWidgets('renders title, subtitle, and formatted metric tiles', (
      tester,
    ) async {
      await pumpCard(tester, makeMetrics());

      expect(find.text('Performance'), findsOneWidget);
      expect(
        find.text(
          'Recent 1-on-1s, real wake activity, and the changes you agreed to.',
        ),
        findsOneWidget,
      );
      // Metric values are number-formatted with grouping separators.
      expect(find.text('1,234'), findsOneWidget);
      expect(find.text('Total Wakes'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Wakes since last 1-on-1'), findsOneWidget);
      expect(find.text('56,789'), findsOneWidget);
      expect(find.text('Tokens since last 1-on-1'), findsOneWidget);
      expect(find.text('Wake activity (last 30 days)'), findsOneWidget);
    });

    testWidgets('renders the wake activity chart with the given buckets', (
      tester,
    ) async {
      await pumpCard(
        tester,
        makeMetrics(
          dailyWakeCounts: [
            DailyWakeCountBucket(date: DateTime(2026, 5), wakeCount: 2),
            DailyWakeCountBucket(date: DateTime(2026, 5, 2), wakeCount: 5),
          ],
        ),
      );

      final chart = tester.widget<EvolutionWakeActivityChart>(
        find.byType(EvolutionWakeActivityChart),
      );
      expect(chart.buckets, hasLength(2));
      expect(find.byType(FractionallySizedBox), findsNWidgets(2));
    });

    testWidgets('empty wake history collapses the chart to nothing', (
      tester,
    ) async {
      await pumpCard(tester, makeMetrics());

      // The chart widget mounts but renders an empty box for zero buckets.
      expect(
        tester.getSize(find.byType(EvolutionWakeActivityChart)),
        Size.zero,
      );
    });

    testWidgets('zero-valued metrics render as zeros', (tester) async {
      await pumpCard(
        tester,
        makeMetrics(
          lifetimeWakeCount: 0,
          wakesSinceLastSession: 0,
          totalTokenUsageSinceLastSession: 0,
        ),
      );

      expect(find.text('0'), findsNWidgets(3));
    });
  });
}
