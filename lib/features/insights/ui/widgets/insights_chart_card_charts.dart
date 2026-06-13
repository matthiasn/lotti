import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class StackedBarChart extends StatelessWidget {
  const StackedBarChart({
    required this.chartData,
    required this.resolver,
    this.comparisonTotals,
    super.key,
  });

  final InsightsChartData chartData;
  final InsightsCategoryResolver resolver;

  /// Previous-period totals per bucket; when set, each group gets a second
  /// muted ghost rod next to the current stacked bar.
  final List<int>? comparisonTotals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final data = chartData;
    final bucketCount = data.bucketStarts.length;
    final axisStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      color: tokens.colors.text.mediumEmphasis,
    );

    // Only compare when the totals line up one-per-bucket; a mismatched
    // length would throw RangeError on the indexed reads below.
    // `alignedPreviousTotals` already guarantees this, but the guard keeps a
    // future miswiring from crashing the chart.
    final rawComparison = comparisonTotals;
    final comparison =
        rawComparison != null && rawComparison.length == bucketCount
        ? rawComparison
        : null;
    final comparing = comparison != null;
    // The previous bar is an OUTLINE, not a fill: it reads unmistakably as a
    // reference frame and never collides with the solid greys already in play
    // (Uncategorized neutral, Other slate).
    final ghostColor = tokens.colors.text.mediumEmphasis;

    var maxTotal = 0;
    for (var i = 0; i < bucketCount; i++) {
      final total = bucketTotal(data, i);
      if (total > maxTotal) maxTotal = total;
      if (comparing && comparison[i] > maxTotal) maxTotal = comparison[i];
    }
    // Floor the scale at 30 min so a near-empty range isn't wildly inflated,
    // but low enough that genuinely small-but-real days still fill the plot
    // rather than hugging the baseline.
    final maxY = maxTotal < 1800 ? 1800.0 : maxTotal * 1.05;
    final interval = _axisInterval(maxY);
    // Label every bar when there's room (≤7); thin out for longer ranges.
    final labelEvery = bucketCount <= 7
        ? 1
        : (bucketCount / 6).ceil().clamp(1, bucketCount);
    final today = epochDay(clock.now());
    // The not-yet-elapsed tail of an in-progress period. Shaded and
    // dim-labelled so empty future buckets read as "upcoming", not as a
    // productivity cliff or a broken chart.
    final firstFutureIndex = _firstFutureBucket(data, today);
    final hasFuture = firstFutureIndex < bucketCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dense ranges get proportionally wider gaps so 30+ bars don't
        // shimmer into each other.
        final widthFactor = bucketCount > 20 ? 0.52 : 0.62;
        // Two bars share each group when comparing, so each is slimmer and
        // the floor drops to keep both readable in dense ranges.
        final barWidth =
            (constraints.maxWidth /
                    bucketCount *
                    widthFactor /
                    (comparing ? 2 : 1))
                .clamp(comparing ? 3.0 : 6.0, 44.0);

        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            rangeAnnotations: hasFuture
                ? RangeAnnotations(
                    verticalRangeAnnotations: [
                      VerticalRangeAnnotation(
                        x1: firstFutureIndex - 0.5,
                        x2: bucketCount - 0.5,
                        color: tokens.colors.surface.hover,
                      ),
                    ],
                  )
                : const RangeAnnotations(),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) => FlLine(
                color: tokens.colors.decorative.level01,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      // Hide zero and the ragged max-value tick fl_chart
                      // appends — only clean interval multiples earn ink.
                      // Rounded modulo: tick values are doubles and FP
                      // error in interval multiples would hide labels.
                      value == 0 || value.round() % interval.round() != 0
                          ? ''
                          : _axisLabel(value),
                      style: axisStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= bucketCount) {
                      return const SizedBox.shrink();
                    }
                    final label = _bottomAxisLabel(
                      context,
                      data,
                      index,
                      labelEvery,
                    );
                    if (label == null) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        label,
                        style: index >= firstFutureIndex
                            ? axisStyle.copyWith(
                                color: tokens.colors.text.lowEmphasis,
                              )
                            : axisStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => tokens.colors.background.level03,
                tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final style = tokens.typography.styles.others.caption
                      .copyWith(color: tokens.colors.text.highEmphasis);
                  final headerStyle = style.copyWith(
                    fontWeight: tokens.typography.weight.semiBold,
                  );
                  // The ghost rod (index 1) reads out the previous period's
                  // total on its own; no category breakdown to show.
                  if (comparing && rodIndex == 1) {
                    return BarTooltipItem(
                      '${context.messages.insightsComparePrevious}  '
                      '${formatDurationCompact(comparison[group.x])}',
                      headerStyle.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      textAlign: TextAlign.left,
                    );
                  }
                  return BarTooltipItem(
                    _tooltipHeader(context, data, group.x),
                    headerStyle,
                    textAlign: TextAlign.left,
                    children: [
                      ..._tooltipRows(
                        data,
                        resolver,
                        data.values,
                        group.x,
                        style,
                        brightness,
                      ),
                      if (comparing)
                        _comparisonTooltipSpan(
                          context,
                          bucketTotal(data, group.x),
                          comparison[group.x],
                          style,
                        ),
                    ],
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < bucketCount; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: comparing ? tokens.spacing.step1 : 0,
                  barRods: [
                    () {
                      var from = 0.0;
                      final stack = <BarChartRodStackItem>[];
                      for (var s = 0; s < data.seriesKeys.length; s++) {
                        final value = data.values[s][i].toDouble();
                        if (value <= 0) continue;
                        stack.add(
                          BarChartRodStackItem(
                            from,
                            from + value,
                            chartColorFor(
                              resolver.colorHexFor(data.seriesKeys[s]),
                              brightness,
                              seriesKey: data.seriesKeys[s],
                            ),
                          ),
                        );
                        from += value;
                      }
                      // Quiet "today" cue: only today's bar gets an edge.
                      final isToday =
                          data.granularity == InsightsGranularity.day &&
                          epochDay(data.bucketStarts[i]) == today;
                      return BarChartRodData(
                        toY: from,
                        width: barWidth,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.radii.xs / 2),
                        ),
                        borderSide: isToday
                            ? BorderSide(
                                color: tokens.colors.text.mediumEmphasis,
                              )
                            : BorderSide.none,
                        rodStackItems: stack,
                      );
                    }(),
                    if (comparing)
                      BarChartRodData(
                        toY: comparison[i].toDouble(),
                        width: barWidth,
                        color: Colors.transparent,
                        borderSide: BorderSide(color: ghostColor, width: 1.5),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.radii.xs / 2),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class StackedAreaChart extends StatelessWidget {
  const StackedAreaChart({
    required this.chartData,
    required this.resolver,
    super.key,
  });

  final InsightsChartData chartData;
  final InsightsCategoryResolver resolver;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final data = chartData;
    final bucketCount = data.bucketStarts.length;
    final axisStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      color: tokens.colors.text.mediumEmphasis,
    );

    // Running totals per series, then stacked tops: series i's line sits at
    // the sum of cumulative series 0..i. Painted top-down so each lower
    // band overdraws the one above, producing clean stacked areas.
    final cumulative = accumulate(data.values);
    final stackedTops = List.generate(
      data.seriesKeys.length,
      (s) => List.generate(bucketCount, (i) {
        var top = 0;
        for (var j = 0; j <= s; j++) {
          top += cumulative[j][i];
        }
        return top;
      }),
    );

    final maxTop = stackedTops.isEmpty || bucketCount == 0
        ? 0
        : stackedTops.last.last;
    // Slight top headroom so the stack never kisses the top gridline.
    final maxY = maxTop < 1800 ? 1800.0 : maxTop * 1.08;
    final interval = _axisInterval(maxY);
    final labelEvery = bucketCount <= 7
        ? 1
        : (bucketCount / 6).ceil().clamp(1, bucketCount);
    final today = epochDay(clock.now());
    final firstFutureIndex = _firstFutureBucket(data, today);
    final hasFuture = firstFutureIndex < bucketCount;
    // Stop the running total at the last elapsed bucket — carrying a flat
    // line across the not-yet-elapsed remainder of the period reads as a
    // stall, and wastes most of the canvas on dead plateau.
    final lastDrawnBucket = hasFuture ? firstFutureIndex : bucketCount;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        rangeAnnotations: hasFuture
            ? RangeAnnotations(
                verticalRangeAnnotations: [
                  VerticalRangeAnnotation(
                    x1: firstFutureIndex - 0.5,
                    x2: bucketCount - 0.5,
                    color: tokens.colors.surface.hover,
                  ),
                ],
              )
            : const RangeAnnotations(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: tokens.colors.decorative.level01, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value == 0 || value.round() % interval.round() != 0
                      ? ''
                      : _axisLabel(value),
                  style: axisStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= bucketCount) {
                  return const SizedBox.shrink();
                }
                final label = _bottomAxisLabel(context, data, index, labelEvery);
                if (label == null) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: index >= firstFutureIndex
                        ? axisStyle.copyWith(
                            color: tokens.colors.text.lowEmphasis,
                          )
                        : axisStyle,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.colors.background.level03,
            tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
            getTooltipItems: (spots) {
              final style = tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.highEmphasis,
              );
              return [
                for (var i = 0; i < spots.length; i++)
                  if (i == 0)
                    LineTooltipItem(
                      '${_bucketLabel(context, data, spots.first.x.toInt())}'
                      '  ${formatDurationCompact(stackedTops.isEmpty ? 0 : stackedTops.last[spots.first.x.toInt()])}',
                      style.copyWith(
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                      textAlign: TextAlign.left,
                      children: _tooltipRows(
                        data,
                        resolver,
                        cumulative,
                        spots.first.x.toInt(),
                        style,
                        brightness,
                      ),
                    )
                  else
                    null,
              ];
            },
          ),
        ),
        // Top-most band painted first; lower bands overdraw it. Each band
        // carries a lightened edge stroke so adjacent muted fills stay
        // separable instead of smearing together.
        lineBarsData: [
          for (var s = data.seriesKeys.length - 1; s >= 0; s--)
            () {
              final fill = chartColorFor(
                resolver.colorHexFor(data.seriesKeys[s]),
                brightness,
                seriesKey: data.seriesKeys[s],
              );
              return LineChartBarData(
                spots: [
                  for (var i = 0; i < lastDrawnBucket; i++)
                    FlSpot(i.toDouble(), stackedTops[s][i].toDouble()),
                ],
                color: bandEdgeColor(fill, brightness),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: fill),
              );
            }(),
        ],
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({
    required this.seriesKeys,
    required this.rolledUpCount,
    required this.resolver,
    this.showPrevious = false,
    this.previousLabel,
    super.key,
  });

  final List<String?> seriesKeys;
  final int rolledUpCount;
  final InsightsCategoryResolver resolver;

  /// Append an outlined ring for the previous-period reference (compare mode).
  final bool showPrevious;

  /// Names the comparison baseline in the legend, e.g. "Previous week". Falls
  /// back to a bare "Previous" when null.
  final String? previousLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;

    String legendLabel(String? key) {
      final label = resolver.labelFor(key);
      // Disclose how many categories the rollup hides; the table below
      // itemizes them.
      if (key == kInsightsOtherCategoryKey && rolledUpCount > 0) {
        return '$label (+$rolledUpCount)';
      }
      return label;
    }

    Widget item(Color color, String label, {bool outlined = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tokens.spacing.step3,
          height: tokens.spacing.step3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // The previous-period reference reads as a ring, matching its
            // outlined bars — never a solid swatch that could pass for a
            // category.
            color: outlined ? null : color,
            border: outlined ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        // step3 matches the table's swatch gap — one reading rhythm.
        SizedBox(width: tokens.spacing.step3),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: tokens.spacing.step5,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final key in seriesKeys)
          item(
            swatchColorFor(
              resolver.colorHexFor(key),
              brightness,
              seriesKey: key,
            ),
            legendLabel(key),
          ),
        if (showPrevious)
          item(
            tokens.colors.text.mediumEmphasis,
            previousLabel ?? context.messages.insightsComparePrevious,
            outlined: true,
          ),
      ],
    );
  }
}

class EmptyChart extends StatelessWidget {
  const EmptyChart({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Text(
        message,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );
  }
}

/// Picks a readable hour-based axis interval so the chart shows roughly
/// 3-5 horizontal gridlines regardless of data magnitude.
double _axisInterval(double maxY) {
  const hours = <double>[
    0.25,
    0.5,
    1,
    2,
    4,
    8,
    12,
    24,
    48,
    96,
    168,
    336,
    672,
    1344,
  ];
  for (final h in hours) {
    final step = h * 3600;
    if (maxY / step <= 4.5) return step;
  }
  return hours.last * 3600;
}

String _axisLabel(double seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final h = minutes / 60;
  return h == h.roundToDouble() ? '${h.round()}h' : '${h.toStringAsFixed(1)}h';
}

/// Index of the first bucket that starts after [today] (the not-yet-elapsed
/// tail), or the bucket count when the whole period has elapsed.
int _firstFutureBucket(InsightsChartData data, int today) {
  for (var i = 0; i < data.bucketStarts.length; i++) {
    if (epochDay(data.bucketStarts[i]) > today) return i;
  }
  return data.bucketStarts.length;
}

/// Bottom-axis tick text for bucket [index], or null to skip it. Weekly
/// (year-view) buckets label only the first week of each month with the
/// month name, so ticks land on clean month boundaries instead of arbitrary
/// week-start dates; shorter ranges thin evenly via [labelEvery].
String? _bottomAxisLabel(
  BuildContext context,
  InsightsChartData data,
  int index,
  int labelEvery,
) {
  if (data.granularity == InsightsGranularity.week) {
    final month = data.bucketStarts[index].month;
    final prevMonth = index == 0 ? -1 : data.bucketStarts[index - 1].month;
    if (month == prevMonth) return null;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMM(locale).format(data.bucketStarts[index]);
  }
  if (index % labelEvery != 0) return null;
  return _bucketLabel(context, data, index);
}

String _bucketLabel(BuildContext context, InsightsChartData data, int index) {
  final locale = Localizations.localeOf(context).toString();
  final start = data.bucketStarts[index];
  return switch (data.granularity) {
    InsightsGranularity.hour => DateFormat.H(locale).format(start),
    // Short ranges answer "where did my week go" — users think in
    // weekdays there, not dates.
    InsightsGranularity.day when data.bucketStarts.length <= 7 => DateFormat(
      'EEE d',
      locale,
    ).format(start),
    InsightsGranularity.day ||
    InsightsGranularity.week => DateFormat.MMMd(locale).format(start),
  };
}

/// Tooltip header: bucket label + total, with a "partial week" flag on
/// truncated edge buckets so they aren't misread as dips.
String _tooltipHeader(BuildContext context, InsightsChartData data, int index) {
  final base =
      '${_bucketLabel(context, data, index)}  '
      '${formatDurationCompact(bucketTotal(data, index))}';
  final isPartial =
      data.granularity == InsightsGranularity.week &&
      ((index == 0 && data.partialFirstBucket) ||
          (index == data.bucketStarts.length - 1 && data.partialLastBucket));
  if (!isPartial) return base;
  return '$base · ${context.messages.insightsPartialWeek}';
}

/// Multi-row tooltip text: every series for the hovered bucket, largest
/// first, zero rows skipped.
List<TextSpan> _tooltipRows(
  InsightsChartData data,
  InsightsCategoryResolver resolver,
  List<List<int>> values,
  int index,
  TextStyle style,
  Brightness brightness,
) {
  final rows = <(String?, int)>[
    for (var s = 0; s < data.seriesKeys.length; s++)
      if (values[s][index] > 0) (data.seriesKeys[s], values[s][index]),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  return [
    for (final (key, seconds) in rows)
      TextSpan(
        text: '\n● ',
        style: style.copyWith(
          color: chartColorFor(
            resolver.colorHexFor(key),
            brightness,
            seriesKey: key,
          ),
        ),
        children: [
          TextSpan(
            text:
                '${resolver.labelFor(key)}  '
                '${formatDurationCompact(seconds)}',
            style: style,
          ),
        ],
      ),
  ];
}

/// Comparison footer for a current-bar tooltip: the previous period's total
/// for the same bucket, with the percent change in the same teal-up /
/// clay-down accents as [InsightsDeltaChip].
TextSpan _comparisonTooltipSpan(
  BuildContext context,
  int current,
  int previous,
  TextStyle style,
) {
  final tokens = context.designTokens;
  final messages = context.messages;
  final pct = insightsDeltaPercent(current, previous);
  final (String deltaText, Color deltaColor) = switch (pct) {
    null => (
      messages.insightsDeltaNew,
      tokens.colors.alert.success.defaultColor,
    ),
    > 0 => ('↑$pct%', tokens.colors.alert.success.defaultColor),
    < 0 => ('↓${-pct}%', tokens.colors.alert.error.defaultColor),
    _ => ('0%', tokens.colors.text.mediumEmphasis),
  };
  return TextSpan(
    text:
        '\n${messages.insightsComparePrevious}  '
        '${formatDurationCompact(previous)}  ',
    style: style.copyWith(color: tokens.colors.text.mediumEmphasis),
    children: [
      TextSpan(
        text: deltaText,
        style: style.copyWith(color: deltaColor),
      ),
    ],
  );
}
