import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/habit_chart_stats.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The habit completion-rate trend chart.
///
/// Reads the same per-day maps as the heatmap but plots them as a single hero
/// line: a **rolling 7-day average** (smooth, shows direction) over a quiet
/// scatter of the raw daily rates, with the on-track band (≥ target) shaded
/// green. Above the plot sits a headline — the current 7-day average, the
/// trend vs the previous week, the count of on-track days, and a nudge at the
/// single laggard habit — so the card answers "how am I doing, and on what?"
/// at a glance, not just "here is a wiggly line". Tapping a day swaps the
/// headline for that day's success/skip/fail split (tap again to clear).
class HabitCompletionRateChart extends ConsumerWidget
    implements PreferredSizeWidget {
  const HabitCompletionRateChart({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);
    final stats = habitChartStats(state);

    final days = state.days;
    final n = days.length;
    final maxX = (n > 1 ? n - 1 : 1).toDouble();

    // 3–4 date labels, inset one step from each edge so they don't clip, plus
    // the interior thirds on the longer (14/30-day) spans.
    final tickIdx = <int>{};
    if (n >= 2) {
      final last = n - 1;
      tickIdx
        ..add(1)
        ..add(last - 1);
      if (last >= 12) {
        tickIdx
          ..add((last / 3).round())
          ..add((last * 2 / 3).round());
      }
    }

    Widget bottomTitleWidgets(double value, TitleMeta meta) {
      final idx = value.toInt();
      if (idx < 0 || idx >= n || !tickIdx.contains(idx)) {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        child: ChartLabel(chartDateFormatter(days[idx])),
      );
    }

    final rollingSpots = [
      for (var i = 0; i < stats.rollingAverage.length; i++)
        FlSpot(i.toDouble(), stats.rollingAverage[i]),
    ];
    final dailySpots = [
      for (var i = 0; i < stats.dailyRates.length; i++)
        FlSpot(i.toDouble(), stats.dailyRates[i]),
    ];

    return Column(
      children: [
        SizedBox(
          // Tall enough for the two-line headline (big number + on-track count
          // + laggard nudge); the one-line day breakdown centres within it, so
          // selecting/clearing a day doesn't shift the chart below.
          height: 64,
          child: state.selectedInfoYmd.isNotEmpty
              ? Center(
                  // A selected day swaps the headline for its split; it
                  // auto-clears back to the headline after the controller's
                  // idle debounce.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoLabel('${state.selectedInfoYmd}:'),
                      InfoLabel('${state.successPercentage}% successful'),
                      InfoLabel('${state.skippedPercentage}% skipped'),
                      InfoLabel('${state.failedPercentage}% recorded fails'),
                    ],
                  ),
                )
              : _ChartHeadline(stats: stats),
        ),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(right: tokens.spacing.step2),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    getTooltipItems: (List<LineBarSpot> spots) {
                      if (spots.isNotEmpty) {
                        final index = spots.first.x.toInt();
                        if (index >= 0 && index < state.days.length) {
                          final ymd = state.days[index];
                          // Defer the state write past paint.
                          SchedulerBinding.instance.addPostFrameCallback((_) {
                            controller.setInfoYmd(ymd);
                          });
                        }
                      }
                      // We render the breakdown in our own header, not a tooltip.
                      return spots.map((_) => null).toList();
                    },
                  ),
                ),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    // The "on track" band: at/above target reads as a calm green
                    // zone the line should live in, not a hard pass/fail border.
                    HorizontalRangeAnnotation(
                      y1: stats.target,
                      y2: 100,
                      color: successColor.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                gridData: FlGridData(
                  horizontalInterval: 20,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    if (value == stats.target) {
                      // The target line — the floor of the on-track band, tinted
                      // to match it rather than a neutral hairline.
                      return chartEmphasisLine(
                        successColor.withValues(alpha: 0.5),
                      );
                    }
                    return chartGridLine(context);
                  },
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: bottomTitleWidgets,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: leftTitleWidgets,
                      // Wide enough that the 5-glyph "100%" label keeps its "%".
                      reservedSize: 44,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: tokens.colors.decorative.level01,
                  ),
                ),
                minX: 0,
                maxX: maxX,
                minY: state.zeroBased ? 0 : state.minY,
                maxY: 100,
                lineBarsData: [
                  // The raw daily rates as a quiet scatter behind the average,
                  // so the line reads as a smoothing of real points (no line of
                  // its own — just dots). Lifted toward white so they separate
                  // from the green gradient fill instead of dissolving into it.
                  LineChartBarData(
                    spots: dailySpots,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 2,
                            color: Color.lerp(successColor, Colors.white, 0.5)!
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                  // The hero: a smoothed rolling 7-day average with a green→clear
                  // gradient fill (no stacked skip/fail bands beneath to muddy
                  // it — the heatmap carries the per-outcome detail now).
                  LineChartBarData(
                    spots: rollingSpots,
                    color: successColor,
                    barWidth: 3,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          successColor.withValues(alpha: 0.28),
                          successColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              curve: Curves.easeInOut,
            ),
          ),
        ),
      ],
    );
  }
}

/// The headline above the trend line: the current 7-day average as the lead
/// number, the on-track day count, the trend chip vs the previous week, and a
/// single-laggard nudge — additive, non-punitive framing for "how am I doing?".
class _ChartHeadline extends StatelessWidget {
  const _ChartHeadline({required this.stats});

  final HabitChartStats stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final avg = stats.currentAverage.round();
    // Only compare to "last week" once a full prior 7-day window exists; on the
    // 7-day span there's nothing meaningful to trend against.
    final showTrend = stats.windowDays >= 14;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$avg%',
              style: tokens.typography.styles.heading.heading2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    messages.habitsRollingAverageLabel,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                  if (stats.windowDays > 0)
                    Text(
                      messages.habitsDaysOnTrack(
                        stats.daysOnTrack,
                        stats.windowDays,
                      ),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                ],
              ),
            ),
            if (showTrend) _TrendChip(delta: stats.trendDelta.round()),
          ],
        ),
        if (stats.laggardName != null)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: tokens.spacing.step4,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                SizedBox(width: tokens.spacing.step1),
                Flexible(
                  child: Text(
                    messages.habitsLaggardHint(
                      stats.laggardName!,
                      stats.laggardMissed,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The trend pill: a direction arrow + the absolute week-over-week delta. A
/// rise is the success colour; a dip stays neutral (not alarm red) so a quiet
/// week reads as information, not a scolding.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final up = delta > 0;
    final flat = delta == 0;
    final color = up ? successColor : tokens.colors.text.mediumEmphasis;
    final icon = flat
        ? Icons.trending_flat_rounded
        : up
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final sign = up ? '+' : (flat ? '' : '−');

    return Semantics(
      label: '$sign${delta.abs()}% ${messages.habitsVsPreviousWeek}',
      child: Tooltip(
        message: messages.habitsVsPreviousWeek,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: tokens.spacing.step4, color: color),
            SizedBox(width: tokens.spacing.step1),
            Text(
              '${delta.abs()}%',
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  String text;
  switch (value.toInt()) {
    case 20:
      text = '20%';
    case 40:
      text = '40%';
    case 60:
      text = '60%';
    case 80:
      text = '80%';
    case 100:
      text = '100%';
    default:
      return Container();
  }

  return ChartLabel(text);
}

class InfoLabel extends StatelessWidget {
  const InfoLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
