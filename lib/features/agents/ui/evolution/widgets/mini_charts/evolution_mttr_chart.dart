import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Mini line chart showing daily average duration (MTTR) trend.
///
/// Y-axis in seconds. Returns [SizedBox.shrink] when fewer than 2 data points.
class EvolutionMttrChart extends StatelessWidget {
  const EvolutionMttrChart({
    required this.buckets,
    super.key,
  });

  final List<DailyWakeBucket> buckets;

  static const _chartHeight = 60.0;
  static const Color _color = GameyColors.primaryPurple;

  @override
  Widget build(BuildContext context) {
    // Filter out zero-duration days (no completed runs).
    final nonZeroBuckets =
        buckets.where((b) => b.averageDuration > Duration.zero).toList();
    if (nonZeroBuckets.length < 2) return const SizedBox.shrink();

    final spots = nonZeroBuckets.indexed.map((entry) {
      final (index, bucket) = entry;
      return FlSpot(
        index.toDouble(),
        bucket.averageDuration.inMilliseconds / 1000.0,
      );
    }).toList();

    return SizedBox(
      height: _chartHeight,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _color,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
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
