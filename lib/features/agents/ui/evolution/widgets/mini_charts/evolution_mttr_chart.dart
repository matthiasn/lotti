import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Mini line chart showing daily average task resolution time (MTTR) trend.
///
/// Y-axis adapts to the magnitude of the durations:
/// - < 1 hour: minutes
/// - 1h–24h: hours
/// - > 24h: days
///
/// Returns [SizedBox.shrink] when there are no non-zero data points.
class EvolutionMttrChart extends StatelessWidget {
  const EvolutionMttrChart({
    required this.buckets,
    super.key,
  });

  final List<DailyResolutionBucket> buckets;

  static const _chartHeight = 60.0;
  static const Color _color = GameyColors.primaryPurple;

  @override
  Widget build(BuildContext context) {
    final nonZeroBuckets =
        buckets.where((b) => b.averageMttr > Duration.zero).toList();
    if (nonZeroBuckets.isEmpty) return const SizedBox.shrink();

    final isSingle = nonZeroBuckets.length == 1;
    final spots = nonZeroBuckets.indexed.map((entry) {
      final (index, bucket) = entry;
      return FlSpot(
        index.toDouble(),
        _durationToMinutes(bucket.averageMttr),
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

  /// Converts a duration to minutes for the Y-axis.
  static double _durationToMinutes(Duration d) => d.inMilliseconds / 60000.0;
}

/// Formats a duration for human display in chart labels / tooltips.
///
/// - < 1 hour → "45m"
/// - 1h–24h → "3.5h"
/// - > 24h → "2.1d"
String formatResolutionDuration(Duration d) {
  final totalMinutes = d.inMilliseconds / 60000.0;
  if (totalMinutes < 60) {
    return '${totalMinutes.round()}m';
  }
  final totalHours = totalMinutes / 60;
  if (totalHours < 24) {
    return '${totalHours.toStringAsFixed(1)}h';
  }
  final totalDays = totalHours / 24;
  return '${totalDays.toStringAsFixed(1)}d';
}
