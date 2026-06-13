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
class InsightsChartCard extends StatefulWidget {
  const InsightsChartCard({
    required this.chartData,
    required this.resolver,
    this.comparisonTotals,
    this.comparisonInProgress = false,
    this.previousLabel,
    super.key,
  });

  final InsightsChartData chartData;
  final InsightsCategoryResolver resolver;

  /// Previous-period totals aligned to [chartData]'s buckets (via
  /// `alignedPreviousTotals`). When non-null the chart switches to grouped
  /// current-vs-previous bars and hides the daily/cumulative toggle — the
  /// comparison is a per-bucket total view, so the cumulative mode (and the
  /// category stacking it shares with the daily bars) would only muddy it.
  final List<int>? comparisonTotals;

  /// Whether the current period is still unfolding. In compare mode this
  /// switches the caption to the "so far" wording so the partial-vs-elapsed
  /// comparison reads honestly.
  final bool comparisonInProgress;

  /// Names the comparison baseline for the legend (e.g. "Previous week").
  final String? previousLabel;

  @override
  State<InsightsChartCard> createState() => _InsightsChartCardState();
}

class _InsightsChartCardState extends State<InsightsChartCard> {
  InsightsChartMode _mode = InsightsChartMode.daily;

  String _captionText(AppLocalizations messages) {
    if (widget.comparisonTotals != null) {
      return widget.comparisonInProgress
          ? messages.insightsChartCompareCaptionPartial
          : messages.insightsChartCompareCaption;
    }
    // The daily caption must name the bucket the bars actually represent —
    // "Time per day" over weekly or hourly bars misreads their magnitude.
    final base = _mode == InsightsChartMode.cumulative
        ? messages.insightsChartCumulativeCaption
        : switch (widget.chartData.granularity) {
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
                // The daily/cumulative toggle is meaningless in compare mode
                // (the chart is fixed to grouped per-bucket totals), so it
                // drops out while comparing.
                if (widget.comparisonTotals == null) ...[
                  // Same pill idiom as the range selector — one "pick one of
                  // N" language across the dashboard.
                  InsightsPillButton(
                    label: messages.insightsChartDaily,
                    active: _mode == InsightsChartMode.daily,
                    onTap: () =>
                        setState(() => _mode = InsightsChartMode.daily),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  InsightsPillButton(
                    label: messages.insightsChartCumulative,
                    active: _mode == InsightsChartMode.cumulative,
                    onTap: () =>
                        setState(() => _mode = InsightsChartMode.cumulative),
                  ),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.step5),
            SizedBox(
              height: _chartHeight,
              child: widget.chartData.isEmpty
                  ? EmptyChart(message: messages.insightsEmptyChart)
                  : widget.comparisonTotals != null
                  ? StackedBarChart(
                      chartData: widget.chartData,
                      resolver: widget.resolver,
                      comparisonTotals: widget.comparisonTotals,
                    )
                  : _mode == InsightsChartMode.daily
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
            // is something to disambiguate (multiple categories, or the
            // previous-period ghost bar that compare mode adds).
            if (widget.chartData.seriesKeys.length > 1 ||
                widget.comparisonTotals != null) ...[
              SizedBox(height: tokens.spacing.step4),
              ChartLegend(
                seriesKeys: widget.chartData.seriesKeys,
                rolledUpCount: widget.chartData.rolledUpCount,
                resolver: widget.resolver,
                showPrevious: widget.comparisonTotals != null,
                previousLabel: widget.previousLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
