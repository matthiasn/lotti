import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Above this width all five KPI tiles sit in one row; between the two
/// breakpoints they wrap to three-per-row; below, two-per-row. Equal-width
/// tiles throughout so figures never get crushed on phone-width panes.
const double _kFiveAcrossMinWidth = 900;
const double _kThreeAcrossMinWidth = 560;

/// Headline totals for the selected period: one quiet bordered tile per
/// consumption metric (cost, energy, CO₂e, tokens, requests) — plain figures,
/// no gauges, mirroring the Insights KPI idiom. All metrics are always shown
/// regardless of which one the chart/table toggle selects, followed by a
/// subtle note that cost/energy/CO₂e are measured for cloud models only.
class ImpactKpiRow extends StatelessWidget {
  const ImpactKpiRow({required this.totals, this.previousTotals, super.key});

  /// Field-wise consumption totals across the selected period.
  final ConsumptionMetrics totals;

  /// Totals for the previous equal-length period, when it is in the loaded
  /// window (e.g. last month for a month view). Drives the per-tile trend
  /// delta; null when there is no comparable prior period to show.
  final ConsumptionMetrics? previousTotals;

  /// A signed "▲/▼ N%" trend versus [previousTotals] for [metric], or null
  /// when there is no prior value to compare against.
  String? _delta(ConsumptionMetric metric) {
    final prev = previousTotals;
    if (prev == null) return null;
    final before = metric.valueOf(prev);
    if (before <= 0) return null;
    final now = metric.valueOf(totals);
    final pct = ((now - before) / before * 100).round();
    if (pct == 0) return '– 0%';
    return pct > 0 ? '▲ $pct%' : '▼ ${-pct}%';
  }

  String _label(AppLocalizations messages, ConsumptionMetric metric) =>
      switch (metric) {
        ConsumptionMetric.cost => messages.aiImpactKpiCost,
        ConsumptionMetric.energy => messages.aiImpactKpiEnergy,
        ConsumptionMetric.carbon => messages.aiImpactKpiCarbon,
        ConsumptionMetric.tokens => messages.aiImpactKpiTokens,
        ConsumptionMetric.requests => messages.aiImpactKpiRequests,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    Widget tile(ConsumptionMetric metric) => _ImpactKpiTile(
      label: _label(messages, metric),
      figure: metric.formatValue(metric.valueOf(totals)),
      delta: _delta(metric),
    );

    // A grid of equal-width tiles, [columns] per row, with empty flex slots
    // padding the final row so every tile keeps the same width.
    Widget grid(int columns) {
      const metrics = ConsumptionMetric.values;
      final rows = <Widget>[];
      for (var start = 0; start < metrics.length; start += columns) {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) SizedBox(width: tokens.spacing.cardItemSpacing),
                  Expanded(
                    child: start + c < metrics.length
                        ? tile(metrics[start + c])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.spacing.cardItemSpacing),
            rows[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _kFiveAcrossMinWidth
            ? 5
            : constraints.maxWidth >= _kThreeAcrossMinWidth
            ? 3
            : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            grid(columns),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.aiImpactCoverageNote,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One quiet bordered KPI tile: eyebrow label, the formatted figure, and an
/// optional trend delta versus the previous period.
class _ImpactKpiTile extends StatelessWidget {
  const _ImpactKpiTile({required this.label, required this.figure, this.delta});

  final String label;
  final String figure;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

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
            Text(
              label,
              // mediumEmphasis: the default lowEmphasis eyebrow is
              // near-illegible on the light theme.
              style: calmEyebrowStyle(
                tokens,
                color: tokens.colors.text.mediumEmphasis,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              figure,
              style: calmDisplayStyle(tokens),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (delta != null) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                context.messages.aiImpactKpiDelta(delta!),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
