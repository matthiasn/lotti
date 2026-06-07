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
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Chart mode: per-bucket values or running cumulative totals.
enum InsightsChartMode { daily, cumulative }

const double _chartHeight = 260;

/// The main visualization: stacked bars per bucket (daily mode) or a
/// stacked cumulative area (cumulative mode).
///
/// Stephen Few rules applied: zero-based axis, horizontal gridlines only,
/// no chart border, muted series fills with the largest category on the
/// baseline, at most [kInsightsMaxChartSeries] bands plus a slate "Other",
/// and a tooltip that reads out *every* band for the hovered bucket —
/// middle stack bands are otherwise uncomparable.
class InsightsChartCard extends StatefulWidget {
  const InsightsChartCard({
    required this.chartData,
    required this.resolver,
    super.key,
  });

  final InsightsChartData chartData;
  final InsightsCategoryResolver resolver;

  @override
  State<InsightsChartCard> createState() => _InsightsChartCardState();
}

class _InsightsChartCardState extends State<InsightsChartCard> {
  InsightsChartMode _mode = InsightsChartMode.daily;

  String _captionText(AppLocalizations messages) {
    final base = _mode == InsightsChartMode.daily
        ? messages.insightsChartDailyCaption
        : messages.insightsChartCumulativeCaption;
    final keys = widget.chartData.seriesKeys;
    if (keys.length != 1) return base;
    return '$base · ${widget.resolver.labelFor(keys.single)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card title sits a full type tier above the in-tile
                      // eyebrow labels so the hierarchy reads correctly.
                      Text(
                        messages.insightsChartTitle,
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      // The mode caption spells out what the chart shows so
                      // "Cumulative" never needs guessing. With a single
                      // series (legend suppressed) it also names the sole
                      // category so the mono-color bars read as intended.
                      Text(
                        _captionText(messages),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Same pill idiom as the range selector — one "pick one of
                // N" language across the dashboard.
                InsightsPillButton(
                  label: messages.insightsChartDaily,
                  active: _mode == InsightsChartMode.daily,
                  onTap: () => setState(() => _mode = InsightsChartMode.daily),
                ),
                SizedBox(width: tokens.spacing.step2),
                InsightsPillButton(
                  label: messages.insightsChartCumulative,
                  active: _mode == InsightsChartMode.cumulative,
                  onTap: () =>
                      setState(() => _mode = InsightsChartMode.cumulative),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step5),
            SizedBox(
              height: _chartHeight,
              child: widget.chartData.isEmpty
                  ? _EmptyChart(message: messages.insightsEmptyChart)
                  : _mode == InsightsChartMode.daily
                  ? _StackedBarChart(
                      chartData: widget.chartData,
                      resolver: widget.resolver,
                    )
                  : _StackedAreaChart(
                      chartData: widget.chartData,
                      resolver: widget.resolver,
                    ),
            ),
            // A one-item legend restates the obvious — only render when
            // there is something to disambiguate.
            if (widget.chartData.seriesKeys.length > 1) ...[
              SizedBox(height: tokens.spacing.step4),
              _ChartLegend(
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
      '${formatDurationCompact(_bucketTotal(data, index))}';
  final isPartial =
      data.granularity == InsightsGranularity.week &&
      ((index == 0 && data.partialFirstBucket) ||
          (index == data.bucketStarts.length - 1 && data.partialLastBucket));
  if (!isPartial) return base;
  return '$base · ${context.messages.insightsPartialWeek}';
}

/// Total seconds in the bucket at [index] across all series.
int _bucketTotal(InsightsChartData data, int index) {
  var total = 0;
  for (final row in data.values) {
    total += row[index];
  }
  return total;
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

class _StackedBarChart extends StatelessWidget {
  const _StackedBarChart({required this.chartData, required this.resolver});

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

    var maxTotal = 0;
    for (var i = 0; i < bucketCount; i++) {
      final total = _bucketTotal(data, i);
      if (total > maxTotal) maxTotal = total;
    }
    // Floor the scale at one hour so sparse data is not visually inflated.
    final maxY = maxTotal < 3600 ? 3600.0 : maxTotal * 1.05;
    final interval = _axisInterval(maxY);
    // Label every bar when there's room (≤7); thin out for longer ranges.
    final labelEvery = bucketCount <= 7
        ? 1
        : (bucketCount / 6).ceil().clamp(1, bucketCount);
    final today = epochDay(clock.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dense ranges get proportionally wider gaps so 30+ bars don't
        // shimmer into each other.
        final widthFactor = bucketCount > 20 ? 0.52 : 0.62;
        final barWidth = (constraints.maxWidth / bucketCount * widthFactor)
            .clamp(6.0, 44.0);

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
                  reservedSize: 44,
                  interval: interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      // Hide zero and the ragged max-value tick fl_chart
                      // appends — only clean interval multiples earn ink.
                      value == 0 || value % interval != 0
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
                    if (index % labelEvery != 0 ||
                        index < 0 ||
                        index >= bucketCount) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _bucketLabel(context, data, index),
                        style: axisStyle,
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
                  return BarTooltipItem(
                    _tooltipHeader(context, data, group.x),
                    style.copyWith(
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                    textAlign: TextAlign.left,
                    children: _tooltipRows(
                      data,
                      resolver,
                      data.values,
                      group.x,
                      style,
                      brightness,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < bucketCount; i++)
                BarChartGroupData(
                  x: i,
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
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StackedAreaChart extends StatelessWidget {
  const _StackedAreaChart({required this.chartData, required this.resolver});

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
    final maxY = maxTop < 3600 ? 3600.0 : maxTop * 1.05;
    final interval = _axisInterval(maxY);
    final labelEvery = bucketCount <= 7
        ? 1
        : (bucketCount / 6).ceil().clamp(1, bucketCount);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
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
                  value == 0 || value % interval != 0 ? '' : _axisLabel(value),
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
                if (index % labelEvery != 0 ||
                    index < 0 ||
                    index >= bucketCount) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _bucketLabel(context, data, index),
                    style: axisStyle,
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
                  for (var i = 0; i < bucketCount; i++)
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

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
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
      // Disclose how many categories the rollup hides; the table below
      // itemizes them.
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
              // step3 matches the table's swatch gap — one reading rhythm.
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

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

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
