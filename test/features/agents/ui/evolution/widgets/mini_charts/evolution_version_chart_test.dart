import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_version_chart.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('EvolutionVersionChart', () {
    testWidgets('renders LineChart when >= 2 data points', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionVersionChart(buckets: _makeVersionBuckets(3)),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders LineChart with single data point', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionVersionChart(buckets: _makeVersionBuckets(1)),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink for empty data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EvolutionVersionChart(buckets: []),
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('maps version number and successRate to spots', (tester) async {
      const buckets = [
        VersionPerformanceBucket(
          versionId: 'v1',
          versionNumber: 1,
          totalRuns: 10,
          successRate: 0.7,
          averageDuration: Duration(seconds: 10),
        ),
        VersionPerformanceBucket(
          versionId: 'v2',
          versionNumber: 2,
          totalRuns: 8,
          successRate: 0.9,
          averageDuration: Duration(seconds: 8),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EvolutionVersionChart(buckets: buckets),
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.first.spots;

      expect(spots, hasLength(2));
      expect(spots[0].x, 1.0);
      expect(spots[0].y, 0.7);
      expect(spots[1].x, 2.0);
      expect(spots[1].y, 0.9);
    });

    testWidgets('shows dot markers on data points', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EvolutionVersionChart(buckets: _makeVersionBuckets(3)),
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.dotData.show, isTrue);
    });
  });
}

List<VersionPerformanceBucket> _makeVersionBuckets(int count) {
  return List.generate(
    count,
    (i) => VersionPerformanceBucket(
      versionId: 'v${i + 1}',
      versionNumber: i + 1,
      totalRuns: 10,
      successRate: 0.8,
      averageDuration: const Duration(seconds: 10),
    ),
  );
}
