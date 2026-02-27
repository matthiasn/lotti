import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_mttr_chart.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('EvolutionMttrChart', () {
    testWidgets('renders LineChart when >= 2 non-zero MTTR data points',
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
        DailyResolutionBucket(
          date: DateTime(2024, 3, 15),
          resolvedCount: 3,
          averageMttr: const Duration(hours: 2),
        ),
        DailyResolutionBucket(
          date: DateTime(2024, 3, 16),
          resolvedCount: 0,
          averageMttr: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: buckets),
        ),
      );
      await tester.pump();

      // Only one non-zero bucket -> renders as a single dot
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.dotData.show, isTrue);
      expect(chart.data.lineBarsData.first.spots, hasLength(1));
    });

    testWidgets('converts durations to minutes for Y values', (tester) async {
      final buckets = [
        DailyResolutionBucket(
          date: DateTime(2024, 3, 15),
          resolvedCount: 1,
          averageMttr: const Duration(hours: 1), // 60 min
        ),
        DailyResolutionBucket(
          date: DateTime(2024, 3, 16),
          resolvedCount: 1,
          averageMttr: const Duration(hours: 2), // 120 min
        ),
        DailyResolutionBucket(
          date: DateTime(2024, 3, 17),
          resolvedCount: 1,
          averageMttr: const Duration(minutes: 90), // 90 min
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
      expect(spots[0].y, 60.0);
      expect(spots[1].y, 120.0);
      expect(spots[2].y, 90.0);
    });

    testWidgets('filters out zero-duration buckets', (tester) async {
      final buckets = [
        DailyResolutionBucket(
          date: DateTime(2024, 3, 15),
          resolvedCount: 2,
          averageMttr: const Duration(hours: 1),
        ),
        DailyResolutionBucket(
          date: DateTime(2024, 3, 16),
          resolvedCount: 0,
          averageMttr: Duration.zero,
        ),
        DailyResolutionBucket(
          date: DateTime(2024, 3, 17),
          resolvedCount: 1,
          averageMttr: const Duration(hours: 3),
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
      expect(spots[0].y, 60.0); // 1 hour = 60 min
      expect(spots[1].y, 180.0); // 3 hours = 180 min
    });

    testWidgets('returns SizedBox.shrink for all-zero buckets', (tester) async {
      final buckets = [
        DailyResolutionBucket(
          date: DateTime(2024, 3, 15),
          resolvedCount: 0,
          averageMttr: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionMttrChart(buckets: buckets),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('returns SizedBox.shrink for empty buckets', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EvolutionMttrChart(buckets: []),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
    });
  });

  group('formatResolutionDuration', () {
    test('formats minutes for < 1 hour', () {
      expect(formatResolutionDuration(const Duration(minutes: 45)), '45m');
      expect(formatResolutionDuration(const Duration(minutes: 5)), '5m');
      expect(formatResolutionDuration(Duration.zero), '0m');
    });

    test('formats hours for 1h–24h', () {
      expect(
        formatResolutionDuration(const Duration(hours: 3, minutes: 30)),
        '3.5h',
      );
      expect(formatResolutionDuration(const Duration(hours: 1)), '1.0h');
      expect(formatResolutionDuration(const Duration(hours: 23)), '23.0h');
    });

    test('formats days for > 24h', () {
      expect(formatResolutionDuration(const Duration(hours: 48)), '2.0d');
      expect(
        formatResolutionDuration(const Duration(hours: 36)),
        '1.5d',
      );
    });
  });
}

List<DailyResolutionBucket> _makeBuckets(int count) {
  return List.generate(
    count,
    (i) => DailyResolutionBucket(
      date: DateTime(2024, 3, 15 + i),
      resolvedCount: 3,
      averageMttr: Duration(hours: 2 + i),
    ),
  );
}
