import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show epochDay;
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity, kInsightsOtherCategoryKey;
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Fixed plot height, matching the Insights chart card so the two
/// dashboards read as siblings.
const double _chartHeight = 260;

/// Chart mode: per-bucket values or running cumulative totals.
enum ImpactChartMode { perBucket, cumulative }

/// How many leading buckets of [data] have elapsed (start on or before today).
///
/// A cumulative running total needs at least two points to draw a line; the
/// chart card falls back to bars below this.
int elapsedImpactBucketCount(ImpactChartData data) =>
    _firstFutureBucket(data, epochDay(clock.now()));

/// Display label for a metric — shared by the chart card title and the
/// dashboard's metric toggle so the two always agree.
String consumptionMetricLabel(
  AppLocalizations messages,
  ConsumptionMetric metric,
) => switch (metric) {
  ConsumptionMetric.cost => messages.aiImpactMetricCost,
  ConsumptionMetric.energy => messages.aiImpactMetricEnergy,
  ConsumptionMetric.carbon => messages.aiImpactMetricCarbon,
  ConsumptionMetric.tokens => messages.aiImpactMetricTokens,
};

/// The impact dashboard's main visualization: per-bucket stacked bars of the
/// selected metric, split by category.
///
/// A consumption-specific sibling of the Insights chart card — same Few
/// rules (zero-based axis, horizontal gridlines only, muted fills, largest
/// series on the baseline, "Other" rollup, exhaustive tooltip), but every
/// number is formatted through the metric's own adaptive-unit formatter
/// instead of the Insights seconds/duration helpers.
class ImpactChartCard extends StatefulWidget {
  const ImpactChartCard({
    required this.chartData,
    required this.resolver,
    required this.metric,
    super.key,
  });

  /// Pre-derived stacked series (see `buildImpactChartData`).
  final ImpactChartData chartData;

  /// Resolves series keys to labels and raw category color hexes.
  final InsightsCategoryResolver resolver;

  /// The metric the series values are measured in — drives every axis,
  /// tooltip, and caption format.
  final ConsumptionMetric metric;

  @override
  State<ImpactChartCard> createState() => _ImpactChartCardState();
}

class _ImpactChartCardState extends State<ImpactChartCard> {
  ImpactChartMode _mode = ImpactChartMode.perBucket;

  bool get _cumulativeFallsBack =>
      _mode == ImpactChartMode.cumulative &&
      elapsedImpactBucketCount(widget.chartData) < 2;

  String _perBucketLabel(AppLocalizations messages) =>
      widget.chartData.granularity == InsightsGranularity.week
      ? messages.insightsChartPerWeek
      : messages.insightsChartPerDay;

  String _captionText(AppLocalizations messages) {
    if (_cumulativeFallsBack) return messages.insightsChartCumulativeShort;
    if (_mode == ImpactChartMode.cumulative) {
      return messages.insightsChartCumulativeCaption;
    }
    return _perBucketLabel(messages);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final showBars = _mode == ImpactChartMode.perBucket || _cumulativeFallsBack;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insightsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.aiImpactChartTitle(
                    consumptionMetricLabel(messages, widget.metric),
                  ),
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  _captionText(messages),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.step3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DsSegmentedToggle<ImpactChartMode>(
                    selected: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                    segments: [
                      DsSegment(
                        ImpactChartMode.perBucket,
                        _perBucketLabel(messages),
                      ),
                      DsSegment(
                        ImpactChartMode.cumulative,
                        messages.insightsChartRunningTotal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step5),
            SizedBox(
              height: _chartHeight,
              child: widget.chartData.isEmpty
                  ? Center(
                      child: Text(
                        messages.insightsEmptyChart,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    )
                  : showBars
                  ? _ImpactStackedBars(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
                    )
                  : _ImpactStackedArea(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
                    ),
            ),
            // A one-item legend restates the obvious — only render when
            // there is more than one category to disambiguate.
            if (widget.chartData.seriesKeys.length > 1) ...[
              SizedBox(height: tokens.spacing.step4),
              _ImpactChartLegend(
                seriesKeys: widget.chartData.seriesKeys,
                rolledUpCount: widget.chartData.rolledUpCount,
                resolver: widget.resolver,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The stacked bar plot: one bar per bucket, split into the category series
/// of the chart data. Only elapsed buckets are plotted (an in-progress
/// month shows the days so far, not a tail of empty future slots) and
/// today's bar carries a quiet edge cue.
class _ImpactStackedBars extends StatelessWidget {
  const _ImpactStackedBars({
    required this.data,
    required this.resolver,
    required this.metric,
  });

  final ImpactChartData data;
  final InsightsCategoryResolver resolver;
  final ConsumptionMetric metric;

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
    final firstFutureIndex = _firstFutureBucket(data, today);
    final drawCount = firstFutureIndex == 0
        ? data.bucketStarts.length
        : firstFutureIndex;

    var maxTotal = 0.0;
    for (var i = 0; i < drawCount; i++) {
      final total = impactBucketTotal(data, i);
      if (total > maxTotal) maxTotal = total;
    }
    // Nice-ceiling axis (1/2/5 × 10ⁿ) with four gridline divisions, so tick
    // values are clean fractions of the ceiling in every metric's unit.
    final maxY = impactNiceCeiling(maxTotal);
    final interval = maxY / 4;
    // Label every bar when there's room (≤7); thin out for longer ranges.
    final labelEvery = drawCount <= 7
        ? 1
        : (drawCount / 6).ceil().clamp(1, drawCount);
    // Hairline in the card colour cuts each stacked segment from the next,
    // a non-colour boundary so adjacent muted fills never smear together.
    final segmentEdge = BorderSide(color: insightsCardSurface(context));

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
                      // Zero earns no ink; every other tick is a clean
                      // quarter of the nice ceiling.
                      value == 0 ? '' : metric.formatValue(value),
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
                    _tooltipHeader(context, data, metric, group.x),
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
                      for (var s = 0; s < data.seriesKeys.length; s++) {
                        final value = data.values[s][i];
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
                            borderSide: segmentEdge,
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
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Cumulative running-total area chart: draws pre-stacked category series as
/// filled areas across elapsed buckets. The card falls back to bars when fewer
/// than two buckets have elapsed.
class _ImpactStackedArea extends StatelessWidget {
  const _ImpactStackedArea({
    required this.data,
    required this.resolver,
    required this.metric,
  });

  final ImpactChartData data;
  final InsightsCategoryResolver resolver;
  final ConsumptionMetric metric;

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

    final cumulative = _accumulateImpactValues(data.values);
    final stackedTops = List.generate(
      data.seriesKeys.length,
      (s) => List.generate(bucketCount, (i) {
        var top = 0.0;
        for (var j = 0; j <= s; j++) {
          top += cumulative[j][i];
        }
        return top;
      }),
    );

    final today = epochDay(clock.now());
    final firstFutureIndex = _firstFutureBucket(data, today);
    final lastDrawnBucket = firstFutureIndex == 0
        ? bucketCount
        : firstFutureIndex;

    var maxTop = 0.0;
    if (stackedTops.isNotEmpty) {
      for (var i = 0; i < lastDrawnBucket; i++) {
        if (stackedTops.last[i] > maxTop) maxTop = stackedTops.last[i];
      }
    }
    final niceCeiling = impactNiceCeiling(maxTop * 1.08);
    final maxY = niceCeiling <= 0 ? 1.0 : niceCeiling;
    final interval = maxY / 4;
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
                  value == 0 ? '' : metric.formatValue(value),
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
                        totalOverride: stackedTops.last[index],
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
                        values: cumulative,
                      ),
                    )
                  else
                    null,
              ];
            },
          ),
        ),
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
class _ImpactChartLegend extends StatelessWidget {
  const _ImpactChartLegend({
    required this.seriesKeys,
    required this.rolledUpCount,
    required this.resolver,
  });

  final List<String?> seriesKeys;
  final int rolledUpCount;
  final InsightsCategoryResolver resolver;

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
      spacing: tokens.spacing.step5,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final key in seriesKeys)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: tokens.spacing.step3,
                height: tokens.spacing.step3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatchColorFor(
                    resolver.colorHexFor(key),
                    brightness,
                    seriesKey: key,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Text(
                legendLabel(key),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Index of the first bucket that starts after [today] (the not-yet-elapsed
/// tail), or the bucket count when the whole period has elapsed.
int _firstFutureBucket(ImpactChartData data, int today) {
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
}) {
  final base =
      '${_bucketLabel(context, data, index)}  '
      '${metric.formatValue(totalOverride ?? impactBucketTotal(data, index))}';
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
  InsightsCategoryResolver resolver,
  ConsumptionMetric metric,
  int index,
  TextStyle style,
  Brightness brightness, {
  List<List<double>>? values,
}) {
  final rowValues = values ?? data.values;
  final rows = <(String?, double)>[
    for (var s = 0; s < data.seriesKeys.length; s++)
      if (rowValues[s][index] > 0) (data.seriesKeys[s], rowValues[s][index]),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  return [
    for (final (key, value) in rows)
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
            text: '${resolver.labelFor(key)}  ${metric.formatValue(value)}',
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
