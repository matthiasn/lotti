import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Below this width the four KPI tiles wrap into a 2×2 grid; a single row
/// would crush the figures on phone-width panes.
const double _kFourAcrossMinWidth = 640;

/// Headline totals for the selected period: one quiet bordered tile per
/// consumption metric (cost, energy, CO₂e, tokens) — plain figures, no
/// gauges, mirroring the Insights KPI idiom. All four metrics are always
/// shown regardless of which one the chart/table toggle selects.
class ImpactKpiRow extends StatelessWidget {
  const ImpactKpiRow({required this.totals, super.key});

  /// Field-wise consumption totals across the selected period.
  final ConsumptionMetrics totals;

  String _label(AppLocalizations messages, ConsumptionMetric metric) =>
      switch (metric) {
        ConsumptionMetric.cost => messages.aiImpactKpiCost,
        ConsumptionMetric.energy => messages.aiImpactKpiEnergy,
        ConsumptionMetric.carbon => messages.aiImpactKpiCarbon,
        ConsumptionMetric.tokens => messages.aiImpactKpiTokens,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    Widget tile(ConsumptionMetric metric) => _ImpactKpiTile(
      label: _label(messages, metric),
      figure: metric.formatValue(metric.valueOf(totals)),
    );

    Widget row(List<ConsumptionMetric> metrics) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) SizedBox(width: tokens.spacing.cardItemSpacing),
            Expanded(child: tile(metrics[i])),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kFourAcrossMinWidth) {
          return row(ConsumptionMetric.values);
        }
        // Narrow panes: 2×2 so each figure keeps room to breathe.
        return Column(
          children: [
            row(const [ConsumptionMetric.cost, ConsumptionMetric.energy]),
            SizedBox(height: tokens.spacing.cardItemSpacing),
            row(const [ConsumptionMetric.carbon, ConsumptionMetric.tokens]),
          ],
        );
      },
    );
  }
}

/// One quiet bordered KPI tile: eyebrow label over the formatted figure.
class _ImpactKpiTile extends StatelessWidget {
  const _ImpactKpiTile({required this.label, required this.figure});

  final String label;
  final String figure;

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
          ],
        ),
      ),
    );
  }
}
