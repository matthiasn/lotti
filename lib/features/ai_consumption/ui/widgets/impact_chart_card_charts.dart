import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart'
    show bandEdgeColor;
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show epochDay;
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity, kInsightsOtherCategoryKey;
import 'package:lotti/features/insights/ui/widgets/insights_format.dart'
    show formatShare;
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// How many leading buckets of [data] have elapsed (start on or before today).
///
/// A cumulative running total needs at least two points to draw a line; the
/// chart card falls back to bars below this.
int elapsedImpactBucketCount(ImpactChartData data) =>
    firstFutureBucket(data, epochDay(clock.now()));

/// The stacked bar plot: one bar per bucket, split into the category series
/// of the chart data. Only elapsed buckets are plotted (an in-progress
/// month shows the days so far, not a tail of empty future slots) and
/// today's bar carries a quiet edge cue.
class ImpactStackedBars extends StatelessWidget {
  const ImpactStackedBars({
    required this.data,
    required this.resolver,
    required this.metric,
    this.shareMode = false,
    this.isolatedKey,
    this.selectedBucketIndex,
    this.onBucketTap,
    super.key,
  });

  final ImpactChartData data;
  final SeriesResolver resolver;
  final ConsumptionMetric metric;

  /// When true, each bar is normalized to its own 100% (per-bucket
  /// composition) instead of the absolute metric value — the "mix over time"
  /// view where a series overtaking another is visible independent of overall
  /// growth.
  final bool shareMode;

  /// When set, every other series is dimmed so the isolated one stands out.
  /// The axis is left unscaled so bars keep their relative heights.
  final String? isolatedKey;

  /// The drilled bucket (the ledger is scoped to it): the selected bar keeps
  /// full opacity and gains an accent outline while its siblings dim, so the
  /// drill has feedback at the tap site regardless of scroll position.
  final int? selectedBucketIndex;

  /// Called with a bucket index when the user taps that bar — drives the
  /// drill-down into the call ledger for that period.
  final ValueChanged<int>? onBucketTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final axisStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      color: tokens.colors.text.mediumEmphasis,
    );

    final today = epochDay(clock.now());
    final firstFutureIndex = firstFutureBucket(data, today);
    final drawCount = firstFutureIndex == 0
        ? data.bucketStarts.length
        : firstFutureIndex;

    // In share mode every non-empty bar reaches 1.0; otherwise the axis snaps
    // to a nice ceiling above the largest bucket total.
    final plotValues = shareMode ? shareValues(data.values) : data.values;
    // Isolating a series shows ONLY it, drawn from the baseline, so its
    // week-over-week trend is readable instead of a band floating mid-stack.
    final isolatedIndex = isolatedKey == null
        ? -1
        : data.seriesKeys.indexOf(isolatedKey);
    final isolating = isolatedIndex >= 0;
    var maxValue = 0.0;
    for (var i = 0; i < drawCount; i++) {
      final v = isolating
          ? plotValues[isolatedIndex][i]
          : impactBucketTotal(data, i);
      if (v > maxValue) maxValue = v;
    }
    // Nice-ceiling axis (1/2/5 × 10ⁿ) with a nice-number tick step, so both
    // the ceiling and every gridline land on round values in each metric's
    // unit (e.g. 10/20/30/40/50, never 13/25/38/50). Share keeps the 0–100%
    // scale even when isolating a single band.
    final maxY = shareMode ? 1.0 : impactNiceCeiling(maxValue);
    final interval = impactNiceInterval(maxY);
    // Label every bar when there's room (≤7); thin out for longer ranges.
    final labelEvery = drawCount <= 7
        ? 1
        : (drawCount / 6).ceil().clamp(1, drawCount);
    // Hairline in the card colour cuts each stacked segment from the next,
    // a non-colour boundary so adjacent muted fills never smear together.
    final cardSurface = insightsCardSurface(context);
    final segmentEdge = BorderSide(color: cardSurface);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dense ranges get proportionally wider gaps so 30+ bars don't
        // shimmer into each other.
        final widthFactor = drawCount > 20 ? 0.52 : 0.62;
        final barWidth = (constraints.maxWidth / drawCount * widthFactor).clamp(
          6.0,
          44.0,
        );

        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
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
                  reservedSize: 56, // fits "€1000" / "999 Wh" style ticks
                  interval: interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      // Zero earns no ink; every other tick is a
                      // nice-number step of the ceiling (a percentage in
                      // share mode).
                      value == 0
                          ? ''
                          : shareMode
                          ? formatShare(value)
                          : metric.formatValue(value),
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
                    // fl_chart can hand non-finite values on degenerate
                    // transitions; toInt() on those throws.
                    if (!value.isFinite) return const SizedBox.shrink();
                    final index = value.toInt();
                    if (index < 0 || index >= drawCount) {
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
                      child: Text(label, style: axisStyle),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchCallback: onBucketTap == null
                  ? null
                  : (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index = response?.spot?.touchedBarGroupIndex;
                      if (index != null && index >= 0 && index < drawCount) {
                        onBucketTap!(index);
                      }
                    },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => tokens.colors.background.level03,
                tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
                maxContentWidth: tokens.spacing.step13 * 1.5,
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  // Guard fl_chart edge events landing outside our own
                  // bar-group range before indexing the series arrays.
                  if (group.x < 0 || group.x >= drawCount) return null;
                  if (impactBucketTotal(data, group.x) <= 0) return null;
                  final style = tokens.typography.styles.others.caption
                      .copyWith(color: tokens.colors.text.highEmphasis);
                  return BarTooltipItem(
                    _tooltipHeader(
                      context,
                      data,
                      metric,
                      group.x,
                      totalOverride: isolating
                          ? plotValues[isolatedIndex][group.x]
                          : null,
                      showTotal: !shareMode,
                    ),
                    style.copyWith(
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                    textAlign: TextAlign.left,
                    children: _tooltipRows(
                      data,
                      resolver,
                      metric,
                      group.x,
                      style,
                      brightness,
                      values: shareMode ? plotValues : null,
                      valueFormat: shareMode ? formatShare : null,
                      isolatedKey: isolatedKey,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < drawCount; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    () {
                      var from = 0.0;
                      final stack = <BarChartRodStackItem>[];
                      // Bars other than the drilled one recede so the
                      // selection reads at a glance.
                      final bucketDimmed =
                          selectedBucketIndex != null &&
                          selectedBucketIndex != i;
                      // A truncated edge week is faded so it can't be misread
                      // as a real dip/spike (the tooltip also flags it). Not
                      // when isolating — a single clean series shouldn't have
                      // one bar shift hue.
                      final isPartialWeek =
                          !isolating &&
                          data.granularity == InsightsGranularity.week &&
                          ((i == 0 && data.partialFirstBucket) ||
                              (i == data.bucketStarts.length - 1 &&
                                  data.partialLastBucket));
                      for (var s = 0; s < data.seriesKeys.length; s++) {
                        // When isolating, draw only that series from the base.
                        if (isolating && s != isolatedIndex) continue;
                        final value = plotValues[s][i];
                        if (value <= 0) continue;
                        final key = data.seriesKeys[s];
                        // Isolation hides the other series outright (the loop
                        // skips them above), so the fill is always full here.
                        var color = resolver.fillColor(key, brightness);
                        if (bucketDimmed) {
                          // Recede a non-selected bucket by lerping its fill
                          // toward the card surface (opaque, hue preserved) —
                          // not toward transparency, which drained the hue and
                          // made Agents-purple vanish. The selected bar's accent
                          // outline still carries the actual selection.
                          color = Color.lerp(color, cardSurface, 0.62) ?? color;
                        }
                        if (isPartialWeek) {
                          color = color.withValues(alpha: color.a * 0.5);
                        }
                        stack.add(
                          BarChartRodStackItem(
                            from,
                            from + value,
                            color,
                            borderSide: segmentEdge,
                          ),
                        );
                        from += value;
                      }
                      // The drilled bar wins the edge cue; else a quiet
                      // "today" edge on the current day's bar.
                      final isSelected = selectedBucketIndex == i;
                      final isToday =
                          data.granularity == InsightsGranularity.day &&
                          epochDay(data.bucketStarts[i]) == today;
                      return BarChartRodData(
                        toY: from,
                        width: barWidth,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.radii.xs / 2),
                        ),
                        borderSide: isSelected
                            ? BorderSide(
                                color: tokens.colors.text.highEmphasis,
                                width: 1.5,
                              )
                            : isToday
                            ? BorderSide(
                                color: tokens.colors.text.mediumEmphasis,
                              )
                            : BorderSide.none,
                        rodStackItems: stack,
                      );
                    }(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Stacked filled-area chart across elapsed buckets. Two flavours:
/// - **cumulative** (default): running totals over time (each series
///   accumulates across buckets), the "where did it add up to" view.
/// - **share** ([shareMode]): each bucket normalized to 100% and the series
///   stacked within it, the smooth "mix over time" crossover view.
///
/// The card falls back to bars when fewer than two buckets have elapsed.
class ImpactStackedArea extends StatelessWidget {
  const ImpactStackedArea({
    required this.data,
    required this.resolver,
    required this.metric,
    this.shareMode = false,
    this.isolatedKey,
    this.onBucketTap,
    super.key,
  });

  final ImpactChartData data;
  final SeriesResolver resolver;
  final ConsumptionMetric metric;

  /// Per-bucket 100% composition instead of cumulative running totals.
  final bool shareMode;

  /// When set, every other series is dimmed so the isolated one stands out.
  final String? isolatedKey;

  /// Called with a bucket index when the user taps that point.
  final ValueChanged<int>? onBucketTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final bucketCount = data.bucketStarts.length;
    final axisStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      color: tokens.colors.text.mediumEmphasis,
    );

    // Share stacks per-bucket shares; cumulative stacks running totals. Both
    // then stack across series to get each band's top edge.
    final baseValues = shareMode
        ? shareValues(data.values)
        : _accumulateImpactValues(data.values);
    final stackedTops = List.generate(
      data.seriesKeys.length,
      (s) => List.generate(bucketCount, (i) {
        var top = 0.0;
        for (var j = 0; j <= s; j++) {
          top += baseValues[j][i];
        }
        return top;
      }),
    );

    final today = epochDay(clock.now());
    final firstFutureIndex = firstFutureBucket(data, today);
    var lastDrawnBucket = firstFutureIndex == 0
        ? bucketCount
        : firstFutureIndex;
    // Share normalizes each bucket, so a trailing empty bucket (e.g. the
    // current week before its first call) would collapse the area to a cliff
    // at zero. Trim those so the mix ends at the last bucket with data.
    if (shareMode) {
      while (lastDrawnBucket > 0 &&
          impactBucketTotal(data, lastDrawnBucket - 1) <= 0) {
        lastDrawnBucket--;
      }
    }

    // Isolating a series draws only it, filled from the baseline, so its own
    // trajectory reads instead of a band floating mid-stack.
    final isolatedIndex = isolatedKey == null
        ? -1
        : data.seriesKeys.indexOf(isolatedKey);
    final isolating = isolatedIndex >= 0;

    var maxTop = 0.0;
    if (stackedTops.isNotEmpty) {
      for (var i = 0; i < lastDrawnBucket; i++) {
        final top = isolating
            ? baseValues[isolatedIndex][i]
            : stackedTops.last[i];
        if (top > maxTop) maxTop = top;
      }
    }
    final niceCeiling = impactNiceCeiling(maxTop * 1.08);
    final maxY = shareMode ? 1.0 : (niceCeiling <= 0 ? 1.0 : niceCeiling);
    final interval = impactNiceInterval(maxY);
    final labelEvery = lastDrawnBucket <= 7
        ? 1
        : (lastDrawnBucket / 6).ceil().clamp(1, lastDrawnBucket);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
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
              reservedSize: 56,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value == 0
                      ? ''
                      : shareMode
                      ? formatShare(value)
                      : metric.formatValue(value),
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
                if (!value.isFinite) return const SizedBox.shrink();
                final index = value.toInt();
                if (index < 0 || index >= lastDrawnBucket) {
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
                  child: Text(label, style: axisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchCallback: onBucketTap == null
              ? null
              : (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) return;
                  final index = spots.first.x.toInt();
                  if (index >= 0 && index < lastDrawnBucket) {
                    onBucketTap!(index);
                  }
                },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.colors.background.level03,
            tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
            maxContentWidth: tokens.spacing.step13 * 1.5,
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) {
              if (spots.isEmpty) return const [];
              final index = spots.first.x.toInt();
              if (index < 0 || index >= lastDrawnBucket) {
                return [for (final _ in spots) null];
              }
              final style = tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.highEmphasis,
              );
              return [
                for (var i = 0; i < spots.length; i++)
                  if (i == 0)
                    LineTooltipItem(
                      _tooltipHeader(
                        context,
                        data,
                        metric,
                        index,
                        totalOverride: isolating
                            ? baseValues[isolatedIndex][index]
                            : stackedTops.last[index],
                        showTotal: !shareMode,
                      ),
                      style.copyWith(
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                      textAlign: TextAlign.left,
                      children: _tooltipRows(
                        data,
                        resolver,
                        metric,
                        index,
                        style,
                        brightness,
                        values: baseValues,
                        valueFormat: shareMode ? formatShare : null,
                        isolatedKey: isolatedKey,
                      ),
                    )
                  else
                    null,
              ];
            },
          ),
        ),
        lineBarsData: isolating
            ? [
                // The single isolated series, filled from the baseline.
                () {
                  final key = data.seriesKeys[isolatedIndex];
                  final fill = resolver.fillColor(key, brightness);
                  return LineChartBarData(
                    spots: [
                      for (var i = 0; i < lastDrawnBucket; i++)
                        FlSpot(i.toDouble(), baseValues[isolatedIndex][i]),
                    ],
                    color: bandEdgeColor(fill, brightness),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: fill),
                  );
                }(),
              ]
            : [
                for (var s = data.seriesKeys.length - 1; s >= 0; s--)
                  () {
                    final key = data.seriesKeys[s];
                    final fill = resolver.fillColor(key, brightness);
                    return LineChartBarData(
                      spots: [
                        for (var i = 0; i < lastDrawnBucket; i++)
                          FlSpot(i.toDouble(), stackedTops[s][i]),
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

/// Legend: a saturated swatch + label per series, plus a "+N" rollup note
/// disclosing how many smaller categories were folded into "Other".
///
/// Tapping an entry isolates that series (via [onToggle]); a second tap
/// clears it. When a series is isolated the other entries dim so the legend
/// mirrors the chart's isolation state.
class ImpactChartLegend extends StatelessWidget {
  const ImpactChartLegend({
    required this.seriesKeys,
    required this.rolledUpCount,
    required this.resolver,
    this.isolatedKey,
    this.onToggle,
    super.key,
  });

  final List<String?> seriesKeys;
  final int rolledUpCount;
  final SeriesResolver resolver;

  /// The currently isolated series, or null when none is.
  final String? isolatedKey;

  /// Called with the tapped series key to toggle its isolation.
  final ValueChanged<String?>? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;

    String legendLabel(String? key) {
      final label = resolver.labelFor(key);
      if (key == kInsightsOtherCategoryKey && rolledUpCount > 0) {
        return '$label (+$rolledUpCount)';
      }
      return label;
    }

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step1,
      children: [
        for (final key in seriesKeys)
          () {
            final isSelected = key == isolatedKey;
            final isDimmed = isolatedKey != null && !isSelected;
            final swatch = resolver.swatchColor(key, brightness);
            return Semantics(
              button: onToggle != null,
              selected: isSelected,
              label: legendLabel(key),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle == null ? null : () => onToggle!(key),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: tokens.spacing.step3,
                        height: tokens.spacing.step3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDimmed
                              ? swatch.withValues(alpha: 0.3)
                              : swatch,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Text(
                        legendLabel(key),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: isSelected
                              ? tokens.colors.text.highEmphasis
                              : isDimmed
                              ? tokens.colors.text.lowEmphasis
                              : tokens.colors.text.mediumEmphasis,
                          fontWeight: isSelected
                              ? tokens.typography.weight.semiBold
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// Index of the first bucket that starts after [today] (the not-yet-elapsed
/// tail), or the bucket count when the whole period has elapsed.
int firstFutureBucket(ImpactChartData data, int today) {
  for (var i = 0; i < data.bucketStarts.length; i++) {
    if (epochDay(data.bucketStarts[i]) > today) return i;
  }
  return data.bucketStarts.length;
}

/// Bottom-axis tick text for bucket [index], or null to skip it. Weekly
/// buckets label only the first week of each month with the month name so
/// ticks land on clean month boundaries; daily ranges thin evenly via
/// [labelEvery].
String? _bottomAxisLabel(
  BuildContext context,
  ImpactChartData data,
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

String _bucketLabel(BuildContext context, ImpactChartData data, int index) {
  final locale = Localizations.localeOf(context).toString();
  final start = data.bucketStarts[index];
  // Short daily ranges read as weekdays ("where did my week go"); longer
  // ranges and weekly buckets carry dates.
  if (data.granularity == InsightsGranularity.day &&
      data.bucketStarts.length <= 7) {
    return DateFormat('EEE d', locale).format(start);
  }
  return DateFormat.MMMd(locale).format(start);
}

/// Tooltip header: bucket label + formatted total, with a "partial week"
/// flag on truncated edge buckets so they aren't misread as dips.
String _tooltipHeader(
  BuildContext context,
  ImpactChartData data,
  ConsumptionMetric metric,
  int index, {
  double? totalOverride,
  bool showTotal = true,
}) {
  // Share mode drops the total: every bucket is 100%, so the figure is noise.
  final base = showTotal
      ? '${_bucketLabel(context, data, index)}  '
            '${metric.formatValue(totalOverride ?? impactBucketTotal(data, index))}'
      : _bucketLabel(context, data, index);
  final isPartial =
      data.granularity == InsightsGranularity.week &&
      ((index == 0 && data.partialFirstBucket) ||
          (index == data.bucketStarts.length - 1 && data.partialLastBucket));
  if (!isPartial) return base;
  return '$base · ${context.messages.insightsPartialWeek}';
}

/// Multi-row tooltip text: every series for the hovered bucket, largest
/// first, zero rows skipped, each value in the metric's own unit.
List<TextSpan> _tooltipRows(
  ImpactChartData data,
  SeriesResolver resolver,
  ConsumptionMetric metric,
  int index,
  TextStyle style,
  Brightness brightness, {
  List<List<double>>? values,
  String Function(double value)? valueFormat,
  String? isolatedKey,
}) {
  final rowValues = values ?? data.values;
  final format = valueFormat ?? metric.formatValue;
  // When a series is isolated only it is drawn, so the tooltip lists only it.
  final rows = <(String?, double)>[
    for (var s = 0; s < data.seriesKeys.length; s++)
      if (rowValues[s][index] > 0 &&
          (isolatedKey == null || data.seriesKeys[s] == isolatedKey))
        (data.seriesKeys[s], rowValues[s][index]),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  return [
    for (final (key, value) in rows)
      TextSpan(
        text: '\n● ',
        style: style.copyWith(
          color: resolver.fillColor(key, brightness),
        ),
        children: [
          TextSpan(
            text: '${resolver.labelFor(key)}  ${format(value)}',
            style: style,
          ),
        ],
      ),
  ];
}

List<List<double>> _accumulateImpactValues(List<List<double>> values) {
  return [
    for (final row in values) _accumulateImpactValueRow(row),
  ];
}

List<double> _accumulateImpactValueRow(List<double> row) {
  final result = <double>[];
  var running = 0.0;

  for (final value in row) {
    running += value;
    result.add(running);
  }

  return result;
}
