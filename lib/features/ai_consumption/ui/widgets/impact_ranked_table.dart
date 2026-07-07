import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart'
    show largestRemainderPercents;
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_table_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
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
    this.isolatedKey,
    this.onToggleSeries,
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

  /// The isolated series, shared with the chart; when set, the other rows dim.
  final String? isolatedKey;

  /// Tapping a row toggles isolation of that category (chart + legend follow).
  final ValueChanged<String?>? onToggleSeries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final brightness = Theme.of(context).brightness;
    if (entries.isEmpty) return const SizedBox.shrink();

    // Integer shares apportioned so the column sums to exactly 100% (a
    // per-row `value/total` round drifts to 101%). Index-aligned with entries.
    final sharePercents = largestRemainderPercents([
      for (final e in entries) e.value,
    ]);
    final isolatingHere =
        isolatedKey != null && entries.any((e) => e.key == isolatedKey);

    // Interactive rows carry a low-emphasis chevron so they read as tappable
    // at rest; the header reserves the same width to keep columns aligned.
    final interactive = onToggleSeries != null;
    final chevronWidth = tokens.spacing.step5;
    Widget? headerTrailing() =>
        interactive ? SizedBox(width: chevronWidth) : null;
    Widget? rowChevron() => interactive
        ? SizedBox(
            width: chevronWidth,
            child: Icon(
              Icons.chevron_right,
              size: tokens.spacing.step4,
              color: tokens.colors.text.lowEmphasis,
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Degrade columns gracefully on narrow panes (share → value); only
        // the flexible category column is guaranteed to survive.
        final showShare = constraints.maxWidth >= 280;
        final showValue = constraints.maxWidth >= 180;

        return ImpactTableCard(
          title: messages.aiImpactCategoryTitle,
          childrenBuilder: (context, headerStyle, numberStyle) => [
            _ImpactTableRowLayout(
              showValue: showValue,
              showShare: showShare,
              trailing: headerTrailing(),
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
            for (var i = 0; i < entries.length; i++)
              _isolatableRow(
                onTap: onToggleSeries == null
                    ? null
                    : () => onToggleSeries!(entries[i].key),
                dimmed: isolatingHere && entries[i].key != isolatedKey,
                child: _ImpactTableRowLayout(
                  showValue: showValue,
                  showShare: showShare,
                  trailing: rowChevron(),
                  category: Row(
                    children: [
                      Container(
                        width: tokens.spacing.step3,
                        height: tokens.spacing.step3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: swatchColorFor(
                            resolver.colorHexFor(entries[i].key),
                            brightness,
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Text(
                          resolver.labelFor(entries[i].key),
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
                    metric.formatValue(entries[i].value),
                    style: numberStyle,
                    textAlign: TextAlign.right,
                  ),
                  share: Text(
                    // A present-but-rounds-to-zero share reads as "<1%", not a
                    // bald 0%, while the apportioned integers still total 100.
                    sharePercents[i] == 0 && entries[i].value > 0
                        ? '<1%'
                        : '${sharePercents[i]}%',
                    style: numberStyle.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wraps a breakdown row so tapping it toggles isolation of its series, and
/// fades it when another series is isolated.
Widget _isolatableRow({
  required Widget child,
  required bool dimmed,
  required VoidCallback? onTap,
}) {
  final row = dimmed ? Opacity(opacity: 0.4, child: child) : child;
  // No gesture wrapper for a non-interactive row (keeps the tree shallow).
  if (onTap == null) return row;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: row,
  );
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
    this.trailing,
  });

  final Widget category;
  final Widget value;
  final Widget share;
  final bool showValue;
  final bool showShare;

  /// Fixed-width trailing slot (a chevron on interactive rows, empty on the
  /// header) so the value/share columns stay aligned across all rows.
  final Widget? trailing;

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
          if (trailing != null) ...[
            SizedBox(width: tokens.spacing.step2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
