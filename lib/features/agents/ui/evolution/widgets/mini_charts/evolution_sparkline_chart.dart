import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Mini sparkline chart showing daily success rate over time.
///
/// Renders a line chart with area fill, ~60px tall, no labels or tooltips.
/// With a single data point, shows a dot. Returns [SizedBox.shrink] when empty.
class EvolutionSparklineChart extends StatelessWidget {
  const EvolutionSparklineChart({
    required this.buckets,
    super.key,
  });

  final List<DailyWakeBucket> buckets;

  static const _chartHeight = 60.0;
  static const Color _color = GameyColors.primaryGreen;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    final isSingle = buckets.length == 1;
    final spots = buckets.indexed.map((entry) {
      final (index, bucket) = entry;
      return FlSpot(index.toDouble(), bucket.successRate);
    }).toList();

    return SizedBox(
      height: _chartHeight,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: 0,
          maxY: 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _color,
              isStrokeCapRound: true,
              dotData: FlDotData(show: isSingle),
              belowBarData: BarAreaData(
                show: !isSingle,
                color: _color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
