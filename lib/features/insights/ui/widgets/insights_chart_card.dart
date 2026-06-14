import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card_charts.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
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
    this.comparing = false,
    super.key,
  });

  final InsightsChartData chartData;
  final InsightsCategoryResolver resolver;

  /// Whether period comparison is active. The chart stays single-series by
  /// design (a previous-period reference bar reads as a loading/empty bar), so
  /// when true the card signposts where the comparison actually lives — the
  /// table below — instead of letting an unchanged chart read as "no change".
  final bool comparing;

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

  /// The per-bucket toggle label, named for the actual bucket so it never
  /// reads "Per day" over weekly or hourly bars (the old fixed "Daily").
  String _perBucketLabel(AppLocalizations messages) =>
      switch (widget.chartData.granularity) {
        InsightsGranularity.hour => messages.insightsChartPerHour,
        InsightsGranularity.day => messages.insightsChartPerDay,
        InsightsGranularity.week => messages.insightsChartPerWeek,
      };

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
    final showBars = _mode == InsightsChartMode.daily || _cumulativeFallsBack;

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
                      // In compare mode the chart deliberately shows only the
                      // current period; point the eye to the table where the
                      // deltas live so "Compare" doesn't read as "no change".
                      if (widget.comparing) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          messages.insightsChartCompareHint,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // The shared segmented toggle (same control as the Daily OS
                // plan-view switch) so the dashboard speaks one visual
                // language. Labels are plain and granularity-accurate — "Per
                // week" over weekly bars, never a wrong "Daily".
                DsSegmentedToggle<InsightsChartMode>(
                  selected: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                  segments: [
                    DsSegment(
                      InsightsChartMode.daily,
                      _perBucketLabel(messages),
                    ),
                    DsSegment(
                      InsightsChartMode.cumulative,
                      messages.insightsChartRunningTotal,
                    ),
                  ],
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
