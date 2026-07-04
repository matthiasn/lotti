import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart'
    show formatShare;
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Exhaustive per-category breakdown of the selected metric: swatch ·
/// resolved name · formatted value · share of the period total.
///
/// The table — not the stacked chart — is the precise per-category readout
/// (Few: graphs for shape, tables for lookup). It lists **every** category,
/// including the ones the chart rolled into "Other". Numerals use the mono
/// metadata style so digits align down the column. Columns degrade with
/// available width (share, then value) instead of overflowing; renders
/// nothing when [entries] is empty (the chart's empty placeholder carries
/// that state).
class ImpactRankedTable extends StatelessWidget {
  const ImpactRankedTable({
    required this.entries,
    required this.resolver,
    required this.metric,
    super.key,
  });

  /// Ranked (descending, zero-free) category totals for the period — the
  /// output of `rankedImpactCategoryTotals`. Keys are category ids with
  /// `null` for uncategorized.
  final List<MapEntry<String?, double>> entries;

  /// Resolves category ids to labels and raw color hexes.
  final InsightsCategoryResolver resolver;

  /// The metric the values are measured in — drives the value formatting.
  final ConsumptionMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final brightness = Theme.of(context).brightness;
    if (entries.isEmpty) return const SizedBox.shrink();

    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final headerStyle = calmEyebrowStyle(
      tokens,
      color: tokens.colors.text.mediumEmphasis,
    );
    final numberStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      base: tokens.typography.styles.body.bodySmall,
      color: tokens.colors.text.highEmphasis,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Degrade columns gracefully on narrow panes (share → value); only
        // the flexible category column is guaranteed to survive.
        final showShare = constraints.maxWidth >= 280;
        final showValue = constraints.maxWidth >= 180;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: insightsCardSurface(context),
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.cardPadding,
              vertical: tokens.spacing.step3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImpactTableRowLayout(
                  showValue: showValue,
                  showShare: showShare,
                  category: Text(
                    messages.insightsTableCategory,
                    style: headerStyle,
                  ),
                  value: Text(
                    messages.insightsTableTotal,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                  share: Text(
                    messages.insightsTableShare,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Divider(height: 1, color: tokens.colors.decorative.level01),
                for (final entry in entries)
                  _ImpactTableRowLayout(
                    showValue: showValue,
                    showShare: showShare,
                    category: Row(
                      children: [
                        Container(
                          width: tokens.spacing.step3,
                          height: tokens.spacing.step3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: swatchColorFor(
                              resolver.colorHexFor(entry.key),
                              brightness,
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Text(
                            resolver.labelFor(entry.key),
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    value: Text(
                      metric.formatValue(entry.value),
                      style: numberStyle,
                      textAlign: TextAlign.right,
                    ),
                    share: Text(
                      formatShare(total > 0 ? entry.value / total : 0),
                      style: numberStyle.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fixed column layout shared by the header and data rows so everything
/// aligns: category (flex) · [value] · [share].
class _ImpactTableRowLayout extends StatelessWidget {
  const _ImpactTableRowLayout({
    required this.category,
    required this.value,
    required this.share,
    required this.showValue,
    required this.showShare,
  });

  final Widget category;
  final Widget value;
  final Widget share;
  final bool showValue;
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final numberColumnWidth = tokens.spacing.step10;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(child: category),
          if (showValue) SizedBox(width: numberColumnWidth, child: value),
          if (showShare) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: share),
          ],
        ],
      ),
    );
  }
}
