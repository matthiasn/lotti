import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_sparkline_chart.dart';

import '../../../../../../widget_test_utils.dart';

List<DailyWakeBucket> _makeBuckets(int count, {double successRate = 0.8}) {
  return List.generate(
    count,
    (i) => DailyWakeBucket(
      date: DateTime(2024, 3, 15 + i),
      successCount: 8,
      failureCount: 2,
      successRate: successRate,
      averageDuration: const Duration(seconds: 10),
    ),
  );
}

void main() {
  group('EvolutionSparklineChart', () {
    testWidgets('renders LineChart when >= 2 data points', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionSparklineChart(buckets: _makeBuckets(5)),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when < 2 data points', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionSparklineChart(buckets: _makeBuckets(1)),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders SizedBox.shrink for empty data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EvolutionSparklineChart(buckets: []),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('maps bucket successRate values to chart spots',
        (tester) async {
      final buckets = [
        DailyWakeBucket(
          date: _day1,
          successCount: 10,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 5),
        ),
        DailyWakeBucket(
          date: _day2,
          successCount: 5,
          failureCount: 5,
          successRate: 0.5,
          averageDuration: const Duration(seconds: 8),
        ),
        DailyWakeBucket(
          date: _day3,
          successCount: 0,
          failureCount: 10,
          successRate: 0,
          averageDuration: const Duration(seconds: 12),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionSparklineChart(buckets: buckets),
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.first.spots;

      expect(spots, hasLength(3));
      expect(spots[0].y, 1.0);
      expect(spots[1].y, 0.5);
      expect(spots[2].y, 0.0);
    });
  });
}

final _day1 = DateTime(2024, 3, 15);
final _day2 = DateTime(2024, 3, 16);
final _day3 = DateTime(2024, 3, 17);
