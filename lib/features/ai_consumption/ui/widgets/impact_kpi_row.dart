import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Above this width all five KPI tiles sit in one row; between the two
/// breakpoints they wrap to three-per-row; below, two-per-row. Equal-width
/// tiles throughout so figures never get crushed on phone-width panes.
const double _kFiveAcrossMinWidth = 900;
const double _kThreeAcrossMinWidth = 560;

/// Metric doubles are scaled to ints for the shared [InsightsDeltaChip]. The
/// percent change is scale-invariant, so a large fixed multiplier preserves it
/// exactly while keeping sub-cent/-Wh values from collapsing to zero.
const int _kDeltaScale = 1000000;

/// Headline totals for the selected period **and** the metric selector: one
/// tile per consumption metric (cost, energy, CO₂e, tokens, requests). The
/// tiles double as the breakdown-metric picker — tapping one selects it (the
/// active tile carries a teal selected treatment), which drops the separate
/// segmented toggle that used to duplicate these same five labels.
///
/// The selected tile also carries a period-over-period trend delta, sign-
/// coloured by valence (rising cost/energy/CO₂e reads clay, falling reads
/// green; tokens/requests stay neutral) against a named baseline — the one
/// figure that turns "am I trending the wrong way" into an at-a-glance answer.
/// A caption below notes that cost/energy/CO₂e are cloud-model-only.
class ImpactKpiRow extends StatelessWidget {
  const ImpactKpiRow({
    required this.totals,
    required this.selectedMetric,
    required this.onSelectMetric,
    this.previousTotals,
    this.previousLabel,
    super.key,
  });

  /// Field-wise consumption totals across the selected period.
  final ConsumptionMetrics totals;

  /// The metric the chart + breakdown table split by — its tile reads as
  /// selected and is the only one to carry a trend delta.
  final ConsumptionMetric selectedMetric;

  /// Tapping a tile selects that metric for the whole dashboard.
  final ValueChanged<ConsumptionMetric> onSelectMetric;

  /// Totals for the previous equal-length period, when it is in the loaded
  /// window (e.g. last month for a month view). Drives the selected tile's
  /// trend delta; null when there is no comparable prior period to show.
  final ConsumptionMetrics? previousTotals;

  /// Short name of that previous period for the "vs …" baseline (e.g. "May").
  final String? previousLabel;

  /// Whether a rising value of [metric] is good, bad, or value-free — decides
  /// how the trend delta is coloured.
  InsightsTrendValence _valence(ConsumptionMetric metric) => switch (metric) {
    ConsumptionMetric.cost ||
    ConsumptionMetric.energy ||
    ConsumptionMetric.carbon => InsightsTrendValence.lessIsBetter,
    ConsumptionMetric.tokens ||
    ConsumptionMetric.requests => InsightsTrendValence.neutral,
  };

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

    final prev = previousTotals;

    Widget tile(ConsumptionMetric metric) {
      final selected = metric == selectedMetric;
      // Only the selected tile shows a delta, and only when the prior period
      // has a value to divide by — so it's always a real percentage, never a
      // "brand new" placeholder competing with the four plain totals.
      final showDelta = selected && prev != null && metric.valueOf(prev) > 0;
      return _ImpactKpiTile(
        label: _label(messages, metric),
        figure: metric.formatValue(metric.valueOf(totals)),
        selected: selected,
        onTap: () => onSelectMetric(metric),
        current: showDelta ? metric.valueOf(totals) : null,
        previous: showDelta ? metric.valueOf(prev) : null,
        valence: _valence(metric),
        previousLabel: previousLabel,
      );
    }

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

/// One KPI tile that doubles as a metric selector: eyebrow label, the formatted
/// figure, and — on the selected tile — a valence-coloured trend delta against
/// a named baseline. Tapping selects the metric; the active tile carries a teal
/// border + tint, matching the design-system segmented-toggle selected state.
class _ImpactKpiTile extends StatelessWidget {
  const _ImpactKpiTile({
    required this.label,
    required this.figure,
    required this.selected,
    required this.onTap,
    this.current,
    this.previous,
    this.valence = InsightsTrendValence.neutral,
    this.previousLabel,
  });

  final String label;
  final String figure;
  final bool selected;
  final VoidCallback onTap;

  /// Selected-period and previous-period values of this tile's metric — set
  /// only on the selected tile with a comparable prior period, else null.
  final double? current;
  final double? previous;
  final InsightsTrendValence valence;
  final String? previousLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? teal.withValues(alpha: 0.10)
                  : insightsCardSurface(context),
              borderRadius: BorderRadius.circular(tokens.radii.m),
              border: Border.all(
                color: selected ? teal : tokens.colors.decorative.level01,
                width: selected ? 1.5 : 1,
              ),
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
                      color: selected
                          ? teal
                          : tokens.colors.text.mediumEmphasis,
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
                  if (current != null && previous != null) ...[
                    SizedBox(height: tokens.spacing.step2),
                    _DeltaLine(
                      current: current!,
                      previous: previous!,
                      valence: valence,
                      previousLabel: previousLabel,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected tile's trend line: the shared [InsightsDeltaChip] (arrow + sign
/// + valence colour) followed by the named "vs …" baseline.
class _DeltaLine extends StatelessWidget {
  const _DeltaLine({
    required this.current,
    required this.previous,
    required this.valence,
    required this.previousLabel,
  });

  final double current;
  final double previous;
  final InsightsTrendValence valence;
  final String? previousLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Flexible(
          child: InsightsDeltaChip(
            current: (current * _kDeltaScale).round(),
            previous: (previous * _kDeltaScale).round(),
            valence: valence,
          ),
        ),
        if (previousLabel != null) ...[
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              context.messages.aiImpactKpiDeltaBaseline(previousLabel!),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
