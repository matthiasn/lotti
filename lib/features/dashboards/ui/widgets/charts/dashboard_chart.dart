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
    this.embedded = false,
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

  /// When embedded inside another card (e.g. an entry summary) the chart drops
  /// its own frame (border/background/padding) so it reads as part of the host
  /// card instead of a transplanted dashboard tile, and its header title is
  /// demoted so the host card's own value line stays the headline.
  final bool embedded;

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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chartHeader,
        if (showEmpty) ...[
          // Skip the gap + Text entirely when there's no message, so an empty
          // card collapses to just its header rather than leaving a stray
          // spacer hanging under it. In a Column with start alignment the
          // notice sits on the same left gutter as the rest of the card.
          if (emptyMessage != null && emptyMessage!.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              emptyMessage!,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ] else ...[
          SizedBox(
            height: embedded ? tokens.spacing.step2 : tokens.spacing.step3,
          ),
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
    );

    // Embedded: no frame of its own, so it sits flush inside the host card.
    if (embedded) {
      return content;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: content,
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
    this.embedded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? action;

  /// When the chart is embedded in another card, the title is demoted to a
  /// quiet subtitle weight so it reads as a subordinate section label rather
  /// than competing with the host card's own bold value line.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Embedded in an entry card, the host's value lines already carry the units
    // (Energy: 632 kcal / Duration: 60 min), so the chart's separate unit
    // caption is just an orphaned extra line — drop it and let the demoted title
    // stand alone.
    final hasSubtitle = !embedded && subtitle != null && subtitle!.isNotEmpty;

    // Embedded: a quiet, regular-weight label (not a semibold heading) so the
    // host card's bold value line stays the dominant text and the chart title
    // reads as a subordinate section caption.
    final titleStyle = embedded
        ? tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          )
        : tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          );

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
                style: titleStyle,
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
