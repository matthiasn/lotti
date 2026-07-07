import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card_charts.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity;
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Fixed plot height, matching the Insights chart card so the two
/// dashboards read as siblings.
const double _chartHeight = 260;

/// Chart mode: per-bucket values, running cumulative totals, or per-bucket
/// 100%-normalized composition (share).
enum ImpactChartMode { perBucket, cumulative, share }

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
  ConsumptionMetric.requests => messages.aiImpactMetricRequests,
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
    this.title,
    this.coverageNote,
    this.selectedBucketIndex,
    this.isolatedKey,
    this.onToggleSeries,
    this.onBucketSelected,
    super.key,
  });

  /// Pre-derived stacked series (see `buildImpactChartData`).
  final ImpactChartData chartData;

  /// Resolves series keys to labels and chart/legend colors.
  final SeriesResolver resolver;

  /// The metric the series values are measured in — drives every axis,
  /// tooltip, and caption format.
  final ConsumptionMetric metric;

  /// Card heading. When null, defaults to the "{metric} by category" title —
  /// callers pass the model title for the model breakdown dimension.
  final String? title;

  /// Optional measurement caveat shown as the per-bucket caption (e.g. that a
  /// cloud-only metric excludes local models on the model breakdown).
  final String? coverageNote;

  /// The drilled bucket index, highlighted in the chart while the ledger is
  /// scoped to it.
  final int? selectedBucketIndex;

  /// The isolated series (shared with the companion table), or null. The card
  /// validates it against the current series so a metric/dimension switch that
  /// drops the key silently clears the isolation.
  final String? isolatedKey;

  /// Toggles isolation of a series — the legend and the companion table both
  /// call this so chart, legend and table move together.
  final ValueChanged<String?>? onToggleSeries;

  /// Called with a bucket's start time when the user taps that bar/point —
  /// drives the drill-down that scopes the call ledger to that period.
  final ValueChanged<DateTime>? onBucketSelected;

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

  /// The caption under the title, or null for none. Per-bucket mode shows
  /// only the optional coverage note — the mode is already named by the
  /// toggle right below, so a "Per week" caption there would be redundant.
  String? _captionText(AppLocalizations messages) {
    if (_mode == ImpactChartMode.share) {
      return messages.aiImpactChartShareCaption;
    }
    if (_cumulativeFallsBack) return messages.insightsChartCumulativeShort;
    if (_mode == ImpactChartMode.cumulative) {
      return messages.insightsChartCumulativeCaption;
    }
    return widget.coverageNote;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = _captionText(messages);
    final isShare = _mode == ImpactChartMode.share;
    // A stacked area needs two elapsed points; a single-bucket share view
    // falls back to a normalized bar.
    final shareFallsBack =
        isShare && elapsedImpactBucketCount(widget.chartData) < 2;
    final showBars =
        _mode == ImpactChartMode.perBucket ||
        _cumulativeFallsBack ||
        shareFallsBack;
    // Drop a stale isolation the moment its series leaves the chart.
    final isolatedKey = widget.chartData.seriesKeys.contains(widget.isolatedKey)
        ? widget.isolatedKey
        : null;
    final onBucketTap = widget.onBucketSelected == null
        ? null
        : (int index) =>
              widget.onBucketSelected!(widget.chartData.bucketStarts[index]);

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
                  widget.title ??
                      messages.aiImpactChartTitle(
                        consumptionMetricLabel(messages, widget.metric),
                      ),
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    caption,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                      DsSegment(
                        ImpactChartMode.share,
                        messages.aiImpactChartShareSegment,
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
                  ? ImpactStackedBars(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
                      shareMode: shareFallsBack,
                      isolatedKey: isolatedKey,
                      selectedBucketIndex: widget.selectedBucketIndex,
                      onBucketTap: onBucketTap,
                    )
                  : ImpactStackedArea(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
                      shareMode: isShare,
                      isolatedKey: isolatedKey,
                      onBucketTap: onBucketTap,
                    ),
            ),
            // A one-item legend restates the obvious — only render when
            // there is more than one category to disambiguate.
            if (widget.chartData.seriesKeys.length > 1) ...[
              SizedBox(height: tokens.spacing.step4),
              ImpactChartLegend(
                seriesKeys: widget.chartData.seriesKeys,
                rolledUpCount: widget.chartData.rolledUpCount,
                resolver: widget.resolver,
                isolatedKey: isolatedKey,
                onToggle: widget.onToggleSeries,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
