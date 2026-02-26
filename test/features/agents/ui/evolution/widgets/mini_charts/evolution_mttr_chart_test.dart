import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_mttr_chart.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('EvolutionMttrChart', () {
    testWidgets('renders LineChart when >= 2 non-zero duration data points',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: _makeBuckets(3)),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots, hasLength(3));
      // Multi-point: dots hidden, area shown.
      expect(chart.data.lineBarsData.first.dotData.show, isFalse);
      expect(chart.data.lineBarsData.first.belowBarData.show, isTrue);
    });

    testWidgets('renders dot for single non-zero data point', (tester) async {
      final buckets = [
        DailyWakeBucket(
          date: DateTime(2024, 3, 15),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 10),
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 16),
          successCount: 0,
          failureCount: 0,
          successRate: 0,
          averageDuration: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: buckets),
        ),
      );
      await tester.pump();

      // Only one non-zero bucket → renders as a single dot
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.dotData.show, isTrue);
      expect(chart.data.lineBarsData.first.spots, hasLength(1));
    });

    testWidgets('converts durations to seconds for Y values', (tester) async {
      final buckets = [
        DailyWakeBucket(
          date: DateTime(2024, 3, 15),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 10),
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 16),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 20),
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 17),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(milliseconds: 5500),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: buckets),
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.first.spots;

      expect(spots, hasLength(3));
      expect(spots[0].y, 10.0);
      expect(spots[1].y, 20.0);
      expect(spots[2].y, 5.5);
    });

    testWidgets('filters out zero-duration buckets', (tester) async {
      final buckets = [
        DailyWakeBucket(
          date: DateTime(2024, 3, 15),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 10),
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 16),
          successCount: 0,
          failureCount: 0,
          successRate: 0,
          averageDuration: Duration.zero,
        ),
        DailyWakeBucket(
          date: DateTime(2024, 3, 17),
          successCount: 5,
          failureCount: 0,
          successRate: 1,
          averageDuration: const Duration(seconds: 20),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: buckets),
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.first.spots;

      // Zero-duration day filtered out, only 2 data points
      expect(spots, hasLength(2));
      expect(spots[0].y, 10.0);
      expect(spots[1].y, 20.0);
    });
  });
}

List<DailyWakeBucket> _makeBuckets(int count) {
  return List.generate(
    count,
    (i) => DailyWakeBucket(
      date: DateTime(2024, 3, 15 + i),
      successCount: 5,
      failureCount: 1,
      successRate: 5 / 6,
      averageDuration: Duration(seconds: 10 + i * 5),
    ),
  );
}
