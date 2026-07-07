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

/// Chart mode: per-bucket values or running cumulative totals.
enum ImpactChartMode { perBucket, cumulative }

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
                  widget.title ??
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
                  ? ImpactStackedBars(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
                    )
                  : ImpactStackedArea(
                      data: widget.chartData,
                      resolver: widget.resolver,
                      metric: widget.metric,
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
