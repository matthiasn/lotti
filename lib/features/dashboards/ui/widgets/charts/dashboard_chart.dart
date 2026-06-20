import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Card shell shared by every dashboard chart.
///
/// Renders a design-system surface (`background.level02` with a
/// `decorative.level01` hairline and `radii.m` corners — the same treatment
/// the Insights time-analysis cards use) with the [chartHeader] stacked above
/// a fixed-[height] chart area and an optional [footer] (e.g. a series legend).
/// The header lives in normal layout flow, so its trailing affordances (e.g.
/// the measurement "+" button) stay inside the card on every viewport —
/// including the narrower desktop detail pane, where the previous
/// full-window-width header pushed them off-screen.
///
/// The chart area distinguishes three states so a background fetch never
/// masquerades as data: [isLoading] (initial load only — never on a
/// stale-while-revalidate refresh) shows a subtle progress affordance, and
/// [isEmpty] shows [emptyMessage] so "no data in range" is never confused with
/// a flat run of real zeros.
///
/// An empty card collapses to a compact, single-line notice directly under the
/// header instead of reserving the full [height]: on a dashboard with many
/// charts, the cards that have no data in range stay out of the way and give
/// the room to the charts that actually have something to show.
class DashboardChart extends StatelessWidget {
  const DashboardChart({
    required this.chart,
    required this.chartHeader,
    required this.height,
    this.dateAxis,
    this.footer,
    this.overlay,
    this.isLoading = false,
    this.isEmpty = false,
    this.emptyMessage,
    super.key,
  });

  final Widget chart;
  final Widget chartHeader;

  /// Optional shared date-axis row rendered directly under the chart area (a
  /// `DashboardChartDateAxis`). Replaces fl_chart's per-chart bottom date labels
  /// so every bar and line card shows identical, aligned dates at all widths.
  /// Only rendered when the chart itself is shown (never in the loading or
  /// empty states).
  final Widget? dateAxis;

  /// Optional content rendered below the chart area (e.g. a series legend).
  final Widget? footer;

  /// Optional widget painted on top of the chart area. Positioned relative to
  /// the chart area, not the whole card.
  final Widget? overlay;

  /// Height of the chart area below the header.
  final double height;

  final bool isLoading;
  final bool isEmpty;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // A chart with no data in range never reserves the full [height]: it
    // collapses to a one-line notice under the header. The initial load
    // ([isLoading]) keeps the full height so the spinner sits where the chart
    // will land — only a settled, genuinely-empty card shrinks.
    final showEmpty = isEmpty && !isLoading;

    final Widget chartArea;
    if (isLoading) {
      chartArea = Center(
        child: SizedBox.square(
          dimension: tokens.spacing.sectionGap,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      );
    } else if (overlay != null) {
      chartArea = Stack(
        children: [
          Positioned.fill(child: chart),
          overlay!,
        ],
      );
    } else {
      chartArea = chart;
    }

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
          mainAxisSize: MainAxisSize.min,
          children: [
            chartHeader,
            if (showEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                emptyMessage ?? '',
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ] else ...[
              SizedBox(height: tokens.spacing.step3),
              SizedBox(height: height, child: chartArea),
              if (dateAxis != null && !isLoading) ...[
                SizedBox(height: tokens.spacing.step2),
                dateAxis!,
              ],
              if (footer != null) ...[
                SizedBox(height: tokens.spacing.step3),
                footer!,
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The header row inside a [DashboardChart]: a [title] (with optional
/// [subtitle] caption), an optional [trailing] widget (e.g. a value readout),
/// and an optional [action] affordance pinned to the end (e.g. an add button).
///
/// Replaces the per-chart `Positioned` + fixed-width `SizedBox` headers that
/// sized themselves to the whole window and clipped their trailing controls on
/// desktop.
class DashboardChartHeader extends StatelessWidget {
  const DashboardChartHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (hasSubtitle) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  subtitle!,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: tokens.spacing.step2),
          trailing!,
        ],
        ?action,
      ],
    );
  }
}

/// The "log a value" affordance used in a chart card header.
///
/// A tonal IconButton (subtle interactive-token fill + interactive-token glyph)
/// so it reads as the card's primary action rather than as decoration on a
/// busy chart, while staying within the design system.
class DashboardChartAddButton extends StatelessWidget {
  const DashboardChartAddButton({
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // Keep the full 48x48 tap target (no compact density) so the control is
      // comfortably tappable on touch devices.
      style: IconButton.styleFrom(
        backgroundColor: tokens.colors.interactive.enabled.withValues(
          alpha: 0.14,
        ),
        foregroundColor: tokens.colors.interactive.enabled,
      ),
      icon: const Icon(Icons.add_rounded),
    );
  }
}

/// One entry in a [DashboardChartLegend].
class DashboardLegendEntry {
  const DashboardLegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}

/// Compact, wrapping series legend rendered in a chart card [DashboardChart.footer].
///
/// Sits below the plot (never overlapping the data) so multi-series charts —
/// blood pressure's systolic/diastolic lines, the BMI range bands — are
/// self-identifying without relying on hover.
class DashboardChartLegend extends StatelessWidget {
  const DashboardChartLegend({required this.entries, super.key});

  final List<DashboardLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step5,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.xs),
                child: ColoredBox(
                  color: entry.color,
                  child: SizedBox.square(dimension: tokens.spacing.step5),
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                entry.label,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
