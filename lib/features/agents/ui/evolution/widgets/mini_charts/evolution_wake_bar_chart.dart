import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Mini stacked bar chart showing daily success/failure counts.
///
/// Green bars for successes, red bars for failures, stacked vertically.
/// Returns [SizedBox.shrink] when fewer than 2 data points.
class EvolutionWakeBarChart extends StatelessWidget {
  const EvolutionWakeBarChart({
    required this.buckets,
    super.key,
  });

  final List<DailyWakeBucket> buckets;

  static const _chartHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    final maxY = buckets.fold<int>(
      0,
      (max, b) {
        final total = b.successCount + b.failureCount;
        return total > max ? total : max;
      },
    );

    return SizedBox(
      height: _chartHeight,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: const BarTouchData(enabled: false),
          maxY: maxY > 0 ? maxY.toDouble() : 1,
          barGroups: buckets.indexed.map((entry) {
            final (index, bucket) = entry;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (bucket.successCount + bucket.failureCount).toDouble(),
                  width: _barWidth(buckets.length),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                  rodStackItems: [
                    BarChartRodStackItem(
                      0,
                      bucket.successCount.toDouble(),
                      GameyColors.primaryGreen.withValues(alpha: 0.8),
                    ),
                    BarChartRodStackItem(
                      bucket.successCount.toDouble(),
                      (bucket.successCount + bucket.failureCount).toDouble(),
                      GameyColors.primaryRed.withValues(alpha: 0.8),
                    ),
                  ],
                  color: Colors.transparent,
                ),
              ],
            );
          }).toList(),
        ),
        duration: Duration.zero,
      ),
    );
  }

  double _barWidth(int count) {
    if (count <= 7) return 8;
    if (count <= 14) return 5;
    return 3;
  }
}
