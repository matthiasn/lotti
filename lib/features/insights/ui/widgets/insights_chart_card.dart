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

part 'insights_chart_card_charts.dart';

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
