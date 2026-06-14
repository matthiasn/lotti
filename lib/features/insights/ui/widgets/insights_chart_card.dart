import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card_charts.dart';
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
/// baseline, at most `kInsightsMaxChartSeries` bands plus a slate "Other",
/// and a tooltip that reads out *every* band for the hovered bucket —
/// middle stack bands are otherwise uncomparable.
///
/// Period comparison is intentionally NOT drawn here: a previous-period
/// reference series fights the focal data and reads as a loading/empty bar.
/// The comparison lives where it is precise and legible instead — the KPI
/// deltas and the table's Δ% / Previous columns.
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

  /// A running total needs at least two elapsed buckets to draw a line; with
  /// one it falls back to bars rather than a lone floating point.
  bool get _cumulativeFallsBack =>
      _mode == InsightsChartMode.cumulative &&
      elapsedBucketCount(widget.chartData) < 2;

  String _captionText(AppLocalizations messages) {
    if (_cumulativeFallsBack) return messages.insightsChartCumulativeShort;
    if (_mode == InsightsChartMode.cumulative) {
      return messages.insightsChartCumulativeCaption;
    }
    // The daily caption must name the bucket the bars actually represent —
    // "Time per day" over weekly or hourly bars misreads their magnitude.
    final base = switch (widget.chartData.granularity) {
      InsightsGranularity.hour => messages.insightsChartHourlyCaption,
      InsightsGranularity.day => messages.insightsChartDailyCaption,
      InsightsGranularity.week => messages.insightsChartWeeklyCaption,
    };
    final keys = widget.chartData.seriesKeys;
    if (keys.length != 1) return base;
    return '$base · ${widget.resolver.labelFor(keys.single)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Bars whenever the running-total line can't be drawn, so the cumulative
    // toggle never yields a blank or single-dot card.
    final showBars =
        _mode == InsightsChartMode.daily || _cumulativeFallsBack;

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
                        // mediumEmphasis, not lowEmphasis: this caption names
                        // what the bars represent (per hour/day/week) — it is
                        // load-bearing and must stay legible at small size in
                        // both themes.
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Same pill idiom as the range selector — one "pick one of N"
                // language across the dashboard.
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
                  ? EmptyChart(message: messages.insightsEmptyChart)
                  : showBars
                  ? StackedBarChart(
                      chartData: widget.chartData,
                      resolver: widget.resolver,
                    )
                  : StackedAreaChart(
                      chartData: widget.chartData,
                      resolver: widget.resolver,
                    ),
            ),
            // A one-item legend restates the obvious — only render when there
            // is more than one category to disambiguate.
            if (widget.chartData.seriesKeys.length > 1) ...[
              SizedBox(height: tokens.spacing.step4),
              ChartLegend(
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
