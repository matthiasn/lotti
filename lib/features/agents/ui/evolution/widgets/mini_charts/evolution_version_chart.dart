import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Mini line chart showing per-version success rate with dot markers.
///
/// Returns [SizedBox.shrink] when fewer than 2 data points.
class EvolutionVersionChart extends StatelessWidget {
  const EvolutionVersionChart({
    required this.buckets,
    super.key,
  });

  final List<VersionPerformanceBucket> buckets;

  static const _chartHeight = 60.0;
  static const Color _color = GameyColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    if (buckets.length < 2) return const SizedBox.shrink();

    final spots = buckets.map((bucket) {
      return FlSpot(bucket.versionNumber.toDouble(), bucket.successRate);
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
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: _color,
                    strokeWidth: 1,
                    strokeColor: Colors.white.withValues(alpha: 0.5),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _color.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
