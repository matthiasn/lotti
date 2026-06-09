import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Exhaustive per-category breakdown: swatch · name · total · share ·
/// avg/day · inline data bar.
///
/// The table — not the stacked chart — is the precise per-category
/// readout (Few: graphs for shape, tables for lookup). Numerals use the
/// mono metadata style so digits align down the column; the inline bars
/// encode share normalized to the largest category.
class InsightsTable extends StatelessWidget {
  const InsightsTable({
    required this.rows,
    required this.resolver,
    this.showAvgPerDay = true,
    this.previousSecondsByCategory,
    super.key,
  });

  final List<InsightsTableRow> rows;
  final InsightsCategoryResolver resolver;

  /// Hidden for single-day ranges, where avg/day would just repeat the
  /// total.
  final bool showAvgPerDay;

  /// Previous-period seconds per category when comparison is on. When set,
  /// the table swaps to a focused current-vs-previous view (Δ% + previous
  /// columns instead of share/avg/bar).
  final Map<String?, int>? previousSecondsByCategory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final brightness = Theme.of(context).brightness;
    if (rows.isEmpty) return const SizedBox.shrink();

    // Max across all rows: buildTableRows sorts descending, but the
    // normalization must not silently distort if a caller ever doesn't.
    final maxShare = rows.fold<double>(
      0,
      (max, row) => row.share > max ? row.share : max,
    );
    // mediumEmphasis: lowEmphasis column headers wash out on light theme.
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
      builder: (context, constraints) => _buildTable(
        context,
        tokens: tokens,
        messages: messages,
        brightness: brightness,
        maxShare: maxShare,
        headerStyle: headerStyle,
        numberStyle: numberStyle,
        maxWidth: constraints.maxWidth,
      ),
    );
  }

  Widget _buildTable(
    BuildContext context, {
    required DsTokens tokens,
    required AppLocalizations messages,
    required Brightness brightness,
    required double maxShare,
    required TextStyle headerStyle,
    required TextStyle numberStyle,
    required double maxWidth,
  }) {
    // The detail pane is user-resizable down to ~90px; degrade columns
    // gracefully (bar → avg/day → share → total) instead of overflowing.
    // Below ~180px only the flexible category column survives. A single
    // row also drops the data bar: a maxed 100% bar encodes nothing.
    // Compare mode is a focused current-vs-previous view: Δ% + previous
    // replace share/avg/bar so the columns never overflow a narrow pane.
    final compare = previousSecondsByCategory != null;
    final showDelta = compare && maxWidth >= 240;
    final showPrevious = compare && maxWidth >= 360;
    final showBar = !compare && maxWidth >= 520 && rows.length > 1;
    final showAvg = !compare && showAvgPerDay && maxWidth >= 400;
    final showShare = !compare && maxWidth >= 280;
    final showTotal = maxWidth >= 180;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.cardPadding,
          vertical: tokens.spacing.step3,
        ),
        child: Column(
          children: [
            _TableRowLayout(
              showTotal: showTotal,
              showShare: showShare,
              showAvgPerDay: showAvg,
              showBar: showBar,
              showDelta: showDelta,
              showPrevious: showPrevious,
              category: Text(
                messages.insightsTableCategory,
                style: headerStyle,
              ),
              total: Text(
                messages.insightsTableTotal,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              delta: Text(
                messages.insightsTableDelta,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              previous: Text(
                messages.insightsTablePrevious,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              share: Text(
                messages.insightsTableShare,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              avgPerDay: Text(
                messages.insightsTableAvgPerDay,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              bar: const SizedBox.shrink(),
            ),
            Divider(height: 1, color: tokens.colors.decorative.level01),
            for (final row in rows)
              _TableRowLayout(
                showTotal: showTotal,
                showShare: showShare,
                showAvgPerDay: showAvg,
                showBar: showBar,
                showDelta: showDelta,
                showPrevious: showPrevious,
                delta: Align(
                  alignment: Alignment.centerRight,
                  child: InsightsDeltaChip(
                    current: row.seconds,
                    previous: previousSecondsByCategory?[row.categoryId] ?? 0,
                  ),
                ),
                previous: Text(
                  formatDurationTable(
                    previousSecondsByCategory?[row.categoryId] ?? 0,
                  ),
                  style: numberStyle.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  textAlign: TextAlign.right,
                ),
                category: Row(
                  children: [
                    Container(
                      width: tokens.spacing.step3,
                      height: tokens.spacing.step3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: swatchColorFor(
                          resolver.colorHexFor(row.categoryId),
                          brightness,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        resolver.labelFor(row.categoryId),
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                total: Text(
                  formatDurationTable(row.seconds),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
                share: Text(
                  formatShare(row.share),
                  style: numberStyle.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  textAlign: TextAlign.right,
                ),
                avgPerDay: Text(
                  formatAvgDuration(row.avgSecondsPerDay),
                  style: numberStyle.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  textAlign: TextAlign.right,
                ),
                bar: DesignSystemProgressBar(
                  value: maxShare > 0 ? row.share / maxShare : 0,
                  fillColor: chartColorFor(
                    resolver.colorHexFor(row.categoryId),
                    brightness,
                  ),
                  // Explicit track so the bar's reference frame stays
                  // visible on the light background too.
                  trackColor: tokens.colors.decorative.level01,
                  semanticsLabel: resolver.labelFor(row.categoryId),
                  semanticsValue: formatShare(row.share),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fixed column layout shared by header and data rows so everything
/// aligns: category (flex) · [total] · [share] · [avg/day] · [data bar].
/// Columns degrade with available width — only the flexible category
/// column is guaranteed to survive extreme pane resizes.
class _TableRowLayout extends StatelessWidget {
  const _TableRowLayout({
    required this.category,
    required this.total,
    required this.delta,
    required this.previous,
    required this.share,
    required this.avgPerDay,
    required this.bar,
    required this.showTotal,
    required this.showDelta,
    required this.showPrevious,
    required this.showShare,
    required this.showAvgPerDay,
    required this.showBar,
  });

  final Widget category;
  final Widget total;
  final Widget delta;
  final Widget previous;
  final Widget share;
  final Widget avgPerDay;
  final Widget bar;
  final bool showTotal;
  final bool showDelta;
  final bool showPrevious;
  final bool showShare;
  final bool showAvgPerDay;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final numberColumnWidth = tokens.spacing.step10;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(child: category),
          if (showTotal) SizedBox(width: numberColumnWidth, child: total),
          if (showDelta) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: delta),
          ],
          if (showPrevious) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: previous),
          ],
          if (showShare) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: share),
          ],
          if (showAvgPerDay) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: avgPerDay),
          ],
          if (showBar) ...[
            SizedBox(width: tokens.spacing.step5),
            SizedBox(width: tokens.spacing.step12, child: bar),
          ],
        ],
      ),
    );
  }
}
