import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_wake_bar_chart.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('EvolutionWakeBarChart', () {
    testWidgets('renders BarChart when >= 2 data points', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionWakeBarChart(buckets: _makeBuckets(3)),
        ),
      );
      await tester.pump();

      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders BarChart with single data point', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionWakeBarChart(buckets: _makeBuckets(1)),
        ),
      );
      await tester.pump();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(1));
    });

    testWidgets('renders SizedBox.shrink for empty data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EvolutionWakeBarChart(buckets: []),
        ),
      );
      await tester.pump();

      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('creates stacked bars with success and failure counts',
        (tester) async {
      final buckets = [
        DailyWakeBucket(
          date: DateTime(2024, 3, 15),
          successCount: 3,
          failureCount: 2,
          successRate: 0.6,
          averageDuration: const Duration(seconds: 5),
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 16),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 8),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionWakeBarChart(buckets: buckets),
        ),
      );
      await tester.pump();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final groups = chart.data.barGroups;

      expect(groups, hasLength(2));

      // First bar: total = 5 (3 success + 2 failure)
      final rod0 = groups[0].barRods.first;
      expect(rod0.toY, 5.0);
      expect(rod0.rodStackItems, hasLength(2));
      // Success portion: 0 → 3
      expect(rod0.rodStackItems[0].fromY, 0.0);
      expect(rod0.rodStackItems[0].toY, 3.0);
      // Failure portion: 3 → 5
      expect(rod0.rodStackItems[1].fromY, 3.0);
      expect(rod0.rodStackItems[1].toY, 5.0);

      // Second bar: total = 5 (5 success + 0 failure)
      final rod1 = groups[1].barRods.first;
      expect(rod1.toY, 5.0);
    });
  });
}

List<DailyWakeBucket> _makeBuckets(int count) {
  return List.generate(
    count,
    (i) => DailyWakeBucket(
      date: DateTime(2024, 3, 15 + i),
      successCount: 5,
      failureCount: 2,
      successRate: 5 / 7,
      averageDuration: const Duration(seconds: 10),
    ),
  );
}
