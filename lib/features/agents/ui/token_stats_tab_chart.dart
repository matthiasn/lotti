import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Bar chart of daily token totals shared by the Daily Usage hero card and
/// the per-model cards.
///
/// Every bar is a single-tone total. Past days are quiet greys; today takes
/// the page's one semantic accent — amber only while usage is above the
/// running average ([todayIsAboveAverage]), the interactive teal otherwise —
/// so the bar can never contradict the Average/Today stat pair, which
/// resolves its colour from the same flag. A dashed line marks the average
/// of the past days' totals.
///
/// [compact] is the tertiary, per-model form: shorter bars, no average
/// line, and a sparse first/last day-label row.
///
/// Selection is operable three ways, all through [onBarTap]: tapping a
/// full-column bar target, scrubbing horizontally across the bars (the
/// precision answer for 30D columns on touch), and — once the chart is
/// focused — the left/right arrow keys.
class InteractiveWeeklyChart extends StatefulWidget {
  const InteractiveWeeklyChart({
    required this.days,
    required this.selectedIndex,
    required this.onBarTap,
    this.todayIsAboveAverage = false,
    this.compact = false,
    super.key,
  });

  final List<DailyTokenUsage>? days;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  /// Whether today's usage is running above the baseline average. Drives
  /// today's bar (and day label) colour; resolve it from the same
  /// `TokenUsageComparison.isAboveAverage` the stat pair uses.
  final bool todayIsAboveAverage;

  /// Renders the demoted per-model form: shorter bars, no average line,
  /// and only a sparse first/last day-label row — enough to anchor the
  /// column mapping when the hero's full label row has scrolled away.
  final bool compact;

  @override
  State<InteractiveWeeklyChart> createState() => _InteractiveWeeklyChartState();
}

class _InteractiveWeeklyChartState extends State<InteractiveWeeklyChart> {
  /// Whether the focus system wants the chart's focus painted — the ring
  /// that turns arrow-key support from a hidden mode into a visible one.
  bool _focusHighlighted = false;

  double get _chartHeight =>
      widget.compact ? chartCompactHeight : chartHeroHeight;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days == null) return SizedBox(height: _chartHeight);
    return FocusableActionDetector(
      onShowFocusHighlight: (highlighted) =>
          setState(() => _focusHighlighted = highlighted),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepDayIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepDayIntent(1),
      },
      actions: {
        _StepDayIntent: CallbackAction<_StepDayIntent>(
          onInvoke: (intent) {
            final current = widget.selectedIndex ?? days.length - 1;
            widget.onBarTap(
              (current + intent.delta).clamp(0, days.length - 1),
            );
            return null;
          },
        ),
      },
      child: _buildChart(context, days),
    );
  }

  Widget _buildChart(BuildContext context, List<DailyTokenUsage> days) {
    final tokens = context.designTokens;
    final maxTokens = days.fold<int>(0, (m, d) => math.max(m, d.totalTokens));

    if (maxTokens == 0) {
      return SizedBox(
        height: _chartHeight,
        child: Center(
          child: Text(
            context.messages.agentStatsNoUsage,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // The dashed line is the SAME quantity as the Average stat above the
    // chart — mean past-day usage by this time of day — so the page has
    // exactly one "average" and today's bar reads directly against it
    // (today's total IS its by-time total).
    final pastDays = days.where((d) => !d.isToday).toList();
    final avgTotal = pastDays.isEmpty
        ? 0.0
        : pastDays.fold<int>(0, (s, d) => s + d.tokensByTimeOfDay) /
              pastDays.length;
    final avgFraction = maxTokens > 0 ? avgTotal / maxTokens : 0.0;

    // When the width cap engages (wide desktop cards), also cap the whole
    // chart: columns stop growing once their bar has, so the bar:gutter
    // ratio survives instead of the gutters absorbing the extra width.
    // Start-anchored, not centred: every element in a card begins on the
    // same left rail.
    final chartMaxWidth = chartContentMaxWidth(
      context,
      columnCount: days.length,
      compact: widget.compact,
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: chartMaxWidth),
        child: Column(
          children: [
            // Scrub support: dragging across the bars retargets the selection
            // continuously — the precision answer for narrow 30D columns on
            // touch. Bar taps keep their own recognizers; a horizontal drag
            // is a distinct gesture, so the two coexist.
            ChartScrubArea(
              itemCount: days.length,
              onIndex: (index) {
                if (index != widget.selectedIndex) widget.onBarTap(index);
              },
              // Foreground decoration: the focus ring paints over the chart
              // without adding layout height, so gaining focus never shifts
              // the card.
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: _focusHighlighted
                    ? BoxDecoration(
                        border: chartSelectionBorder(context),
                        borderRadius: BorderRadius.circular(tokens.radii.xs),
                      )
                    : const BoxDecoration(),
                child: SizedBox(
                  height: _chartHeight,
                  child: Stack(
                    children: [
                      // Average line — painted at exact Y, no layout hacks.
                      // The Average metric column above the chart names it;
                      // an in-chart text label would only overdraw the bars.
                      if (!widget.compact && avgTotal > 0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: AverageDashedLinePainter(
                              fraction: avgFraction,
                              // One step above the bars' resting grey: the
                              // reference line must stay legible for
                              // low-vision readers, not fade into the card.
                              color: context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: chartAverageLineAlpha),
                              // Card-surface casing under the dashes keeps the
                              // reference readable where it crosses bars — its
                              // most important pixels.
                              casingColor: dsCardSurface(context),
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < days.length; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: days.length > 10
                                      ? chartDenseColumnGutter
                                      : tokens.spacing.step1,
                                ),
                                child: _DayBar(
                                  day: days[i],
                                  maxTokens: maxTokens,
                                  chartHeight: _chartHeight,
                                  todayIsAboveAverage:
                                      widget.todayIsAboveAverage,
                                  compact: widget.compact,
                                  isSelected: widget.selectedIndex == i,
                                  onTap: () => widget.onBarTap(i),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            _DayLabelsRow(
              days: days,
              selectedIndex: widget.selectedIndex,
              todayIsAboveAverage: widget.todayIsAboveAverage,
              onBarTap: widget.onBarTap,
              // A week always labels all seven days, even in the
              // compact cards — a bar tap should be predictable before
              // tapping. Sparse first/last anchors remain for dense
              // ranges.
              sparse: widget.compact && days.length > 10,
            ),
          ],
        ),
      ),
    );
  }
}

/// Steps the chart's day selection by [delta] via the arrow keys.
class _StepDayIntent extends Intent {
  const _StepDayIntent(this.delta);

  final int delta;
}

// ── Shared chart grammar ────────────────────────────────────────────────────

/// Fraction of its column that a painted bar occupies — bars dominate
/// gutters at every viewport width instead of pinning to a fixed pixel cap
/// that wide desktop columns dwarf. Shared by the daily and wake charts,
/// alongside a per-chart height-aware width cap so bars can never grow
/// wider than their chart is tall.
const chartBarWidthFraction = 0.72;

/// Floor for a non-zero bar's painted height, as a fraction of the chart
/// height — the smallest recorded day/hour must stay visible, not shrink
/// to a hairline. One floor for every chart on the page.
const chartBarMinHeightFraction = 0.06;

/// A selected bar's higher floor: the selection ring is a 1px border on
/// the fill, so a ringed minimum-height bar must keep visible fill inside
/// the ring instead of degrading into a bare nub.
const chartSelectedBarMinHeightFraction = 0.18;

/// Per-column horizontal padding for dense (>10 column) charts — the 30D
/// daily chart and the 24h wake histogram share it.
const chartDenseColumnGutter = 0.5;

/// The three chart heights on the page — hero, compact per-model echo,
/// and the wake histogram — named here so no file invents its own.
const chartHeroHeight = 120.0;
const chartCompactHeight = 56.0;
const chartWakeHeight = 72.0;

/// How long a pointer must rest before the value tooltip appears — one
/// wait for every hoverable bar on the page.
const chartTooltipWaitDuration = Duration(milliseconds: 400);

/// One content width per card: the capped width of a chart with
/// [columnCount] columns, shared by the chart itself and any sibling
/// block (divider, detail rows, breakdown bar) that must end on the same
/// rail — two right edges in one card read as two competing layouts.
double chartContentMaxWidth(
  BuildContext context, {
  required int columnCount,
  required bool compact,
}) {
  final tokens = context.designTokens;
  final barCap = compact ? tokens.spacing.step7 : tokens.spacing.step9;
  final gutter = columnCount > 10
      ? chartDenseColumnGutter
      : tokens.spacing.step1;
  return columnCount * (barCap / chartBarWidthFraction + 2 * gutter);
}

/// The dashed average line's alpha step: one step above the bars' resting
/// grey, so the reference stays legible without competing with today.
const chartAverageLineAlpha = 0.55;

/// The shared grey ramp for history bars: hover brightens an unselected
/// bar one step (the desktop pointer's cue that bars are live targets),
/// selection one more. One expression for both stats charts, so the page
/// speaks a single bar grammar.
Color chartHistoryBarColor(
  BuildContext context, {
  required bool selected,
  required bool hovered,
}) {
  final alpha = selected ? 0.75 : (hovered ? 0.55 : 0.45);
  return context.colorScheme.onSurfaceVariant.withValues(alpha: alpha);
}

/// The hue-independent selection/focus ring: the high-emphasis text token
/// reads over grey, teal, and amber fills alike, so ring = "selected"
/// everywhere on the page.
Border chartSelectionBorder(BuildContext context) =>
    Border.all(color: context.designTokens.colors.text.highEmphasis);

/// The shared section heading row: an ellipsizing subtitle1 title, and on
/// the right either a quiet bodySmall scope [caption] (one weight step
/// below the title — a qualifier, never a second headline, truncating
/// before the title ever does) or a custom [trailing] control. One
/// heading grammar for every section on the page, enforced by
/// construction instead of copy-paste.
class StatsSectionHeading extends StatelessWidget {
  const StatsSectionHeading({
    required this.title,
    this.caption,
    this.trailing,
    super.key,
  }) : assert(
         caption == null || trailing == null,
         'Pass a caption or a trailing control, not both',
       );

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      // Text pairs align on their shared baseline; a control (toggle)
      // centres against the title instead.
      crossAxisAlignment: trailing == null
          ? CrossAxisAlignment.baseline
          : CrossAxisAlignment.center,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        if (caption != null)
          Flexible(
            child: Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ?trailing,
      ],
    );
  }
}

/// Maps horizontal drags across [child] to item indices — the shared scrub
/// gesture of both stats charts, the precision answer for narrow columns
/// on touch. Taps keep the per-item detectors; a horizontal drag is a
/// distinct gesture, so the two coexist.
class ChartScrubArea extends StatelessWidget {
  const ChartScrubArea({
    required this.itemCount,
    required this.onIndex,
    required this.child,
    super.key,
  });

  final int itemCount;
  final ValueChanged<int> onIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectFromDx(double dx) {
          final width = constraints.maxWidth;
          if (width <= 0 || itemCount <= 0) return;
          onIndex((dx / width * itemCount).floor().clamp(0, itemCount - 1));
        }

        return GestureDetector(
          onHorizontalDragStart: (d) => selectFromDx(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => selectFromDx(d.localPosition.dx),
          child: child,
        );
      },
    );
  }
}

/// The colour of today's bar, day label, and stat text: the semantic amber
/// only while above average, the interactive teal otherwise. One expression
/// for every consumer, so no surface can disagree with another.
///
/// [forText] swaps in the warning ramp's darker hover step in light mode,
/// where the default amber is legible as a wide bar fill but too faint for
/// small text on a white card.
Color todayAccentColor(
  BuildContext context, {
  required bool aboveAverage,
  bool forText = false,
}) {
  final tokens = context.designTokens;
  if (!aboveAverage) return tokens.colors.interactive.enabled;
  final darkenForText =
      forText && Theme.of(context).brightness == Brightness.light;
  return darkenForText
      ? tokens.colors.alert.warning.hover
      : tokens.colors.alert.warning.defaultColor;
}

/// The amber for small text: the warning ramp's darker hover step in
/// light mode (where the default amber is too faint on a white card),
/// the default step otherwise. One expression for every amber text
/// consumer, so the sentence and the row warning can never drift apart.
Color warningTextColor(BuildContext context) {
  final tokens = context.designTokens;
  return Theme.of(context).brightness == Brightness.light
      ? tokens.colors.alert.warning.hover
      : tokens.colors.alert.warning.defaultColor;
}

// ── Day Labels Row ──────────────────────────────────────────────────────────

class _DayLabelsRow extends StatelessWidget {
  const _DayLabelsRow({
    required this.days,
    required this.selectedIndex,
    required this.todayIsAboveAverage,
    required this.onBarTap,
    this.sparse = false,
  });

  final List<DailyTokenUsage> days;
  final int? selectedIndex;
  final bool todayIsAboveAverage;
  final ValueChanged<int> onBarTap;

  /// Label only the first and last columns — the compact charts' form.
  final bool sparse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Sparse: first + last column only. Otherwise, for 7 days show every
    // label (day-of-week letter); for 30 days every 7th day as a date.
    final showEvery = sparse
        ? days.length - 1
        : days.length <= 10
        ? 1
        : 7;

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onBarTap(i),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: i % showEvery == 0 || i == days.length - 1
                      ? Text(
                          days.length <= 10
                              // Narrow standalone weekday ('ccccc') — the
                              // locale's real one-glyph form, not the
                              // first letter of the short name.
                              ? DateFormat('ccccc').format(days[i].date)
                              : '${days[i].date.day}',
                          // One caption style with colour-only emphasis:
                          // swapping weight on selection would shift the
                          // 30D numeric labels' metrics under the pointer.
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: days[i].isToday
                                    ? todayAccentColor(
                                        context,
                                        aboveAverage: todayIsAboveAverage,
                                        forText: true,
                                      )
                                    : selectedIndex == i
                                    ? context.colorScheme.onSurface
                                    : context.colorScheme.onSurfaceVariant,
                              ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Single Day Bar ──────────────────────────────────────────────────────────

class _DayBar extends StatefulWidget {
  const _DayBar({
    required this.day,
    required this.maxTokens,
    required this.chartHeight,
    required this.todayIsAboveAverage,
    required this.compact,
    this.isSelected = false,
    this.onTap,
  });

  final DailyTokenUsage day;
  final int maxTokens;
  final double chartHeight;
  final bool todayIsAboveAverage;

  /// Single-sourced from the chart, so the bar cap and the card rail can
  /// never disagree about which form this chart is.
  final bool compact;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_DayBar> createState() => _DayBarState();
}

class _DayBarState extends State<_DayBar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final day = widget.day;
    final totalFraction = widget.maxTokens > 0
        ? day.totalTokens / widget.maxTokens
        : 0.0;

    // Full weekday and an explicit unit: screen-reader and large-text
    // users get each day's value without a pixel-precise tap, and "1K"
    // alone never has to be guessed at.
    final semanticsLabel =
        '${DateFormat('EEEE, MMM d').format(day.date)}: '
        '${formatTokenCount(day.totalTokens)} '
        '${context.messages.agentStatsTokensUnit}';

    if (totalFraction == 0) {
      return Semantics(
        button: true,
        selected: widget.isSelected,
        label: semanticsLabel,
        child: Tooltip(
          message: semanticsLabel,
          excludeFromSemantics: true,
          waitDuration: chartTooltipWaitDuration,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    // History bars ride the shared grey ramp (its floor keeps Monday's
    // stub findable for low-vision readers); only today speaks the page's
    // accent, resolved from the same flag as the stat pair.
    final barColor = day.isToday
        ? todayAccentColor(context, aboveAverage: widget.todayIsAboveAverage)
        : chartHistoryBarColor(
            context,
            selected: widget.isSelected,
            hovered: _hovered,
          );

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticsLabel,
      // Desktop value readout: hovering answers "how much" without a
      // committing click, reusing the exact accessibility string.
      child: Tooltip(
        message: semanticsLabel,
        excludeFromSemantics: true,
        waitDuration: chartTooltipWaitDuration,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            // The tap target is the full chart-height column, not just the
            // painted bar — the grammar must not fail on the smallest days.
            child: SizedBox(
              height: widget.chartHeight,
              // Both factors and the alignment live on the one
              // FractionallySizedBox (the wake bar's proven geometry): the
              // height fraction bottom-anchors every bar on the chart
              // baseline, the width fraction plus the height-aware cap keep
              // bars dominating their gutters without growing wider than
              // the chart is tall. An inner Align/Center around a
              // fixed-height child would swallow the bottom anchor and
              // float the bars mid-column.
              child: FractionallySizedBox(
                heightFactor: math.max(
                  widget.isSelected
                      ? chartSelectedBarMinHeightFraction
                      : chartBarMinHeightFraction,
                  totalFraction,
                ),
                widthFactor: chartBarWidthFraction,
                alignment: Alignment.bottomCenter,
                child: Center(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: widget.compact
                          ? tokens.spacing.step7
                          : tokens.spacing.step9,
                    ),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(tokens.radii.xs),
                      ),
                      // Ring = selection, everywhere on the page: the
                      // high-emphasis token is hue-independent over grey,
                      // teal, and amber fills.
                      border: widget.isSelected
                          ? chartSelectionBorder(context)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Selected Day Detail ─────────────────────────────────────────────────────

/// Detail rows for the selected day: date + total, one thin bar per token
/// kind, and the wake metrics.
///
/// Rendered flat on the parent card's surface, set off by a hairline
/// divider — a same-colour nested card would draw an invisible boundary
/// and waste an indent level.
///
/// [compact] is the per-model echo: breakdown bars only, no date header
/// (the hero directly above already names the selected day) and no wake
/// metrics, so page height stops scaling with model count.
class SelectedDayDetail extends StatelessWidget {
  const SelectedDayDetail({
    required this.day,
    this.compact = false,
    this.shareOfTotal,
    this.onResetToToday,
    super.key,
  });

  final DailyTokenUsage day;
  final bool compact;

  /// Compact only: this model's share (0–1) of the selected day's tokens
  /// across all models — the per-model cards' cross-card length encoding.
  final double? shareOfTotal;

  /// Snaps the page-wide selection back to today. Rendered as a tappable
  /// teal "Today" beside the date while a past day is focused — the
  /// return leg of the explore loop, so getting back never requires
  /// sniper-tapping the last bar of a dense 30D chart.
  final VoidCallback? onResetToToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dateLabel = DateFormat.MMMEd().format(day.date);
    final slices = _daySlices(context, day);

    if (compact) {
      return _CompactDayEcho(
        dateLabel: dateLabel,
        slices: slices,
        shareOfTotal: shareOfTotal,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: tokens.colors.decorative.level01),
        SizedBox(height: tokens.spacing.step4),
        ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                day.isToday
                    ? '$dateLabel · ${context.messages.agentStatsTodayLabel}'
                    : dateLabel,
                style: tokens.typography.styles.subtitle.subtitle2,
              ),
              if (!day.isToday && onResetToToday != null) ...[
                SizedBox(width: tokens.spacing.step2),
                // The interactive teal marks it as the card's one action;
                // it appears only while there is somewhere to return to.
                // Padded inside the ink so the touch target outgrows the
                // short word without shifting the header's baseline.
                InkWell(
                  onTap: onResetToToday,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step2,
                      vertical: tokens.spacing.step1,
                    ),
                    child: Text(
                      context.messages.agentStatsTodayLabel,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.interactive.enabled,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // One quiet tier: the count restates the bar the reader just
              // tapped (and, for today, the stat pair above), so it ranks
              // as a caption fact, not a second headline.
              Text(
                formatTokenCount(day.totalTokens),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.agentStatsTokensUnit,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
        ],

        // One stacked bar + swatch-keyed values: the same breakdown
        // grammar the per-model cards echo, so the page teaches it once.
        // Every slice of the total is named — including Other — so the
        // parts always sum to the headline number.
        _BreakdownStackedBar(slices: slices),
        SizedBox(height: tokens.spacing.step2),
        _BreakdownCaption(slices: slices),

        // Metrics row — only shown when wake data is available.
        if (day.wakeCount > 0 || day.cacheRate > 0) ...[
          SizedBox(height: tokens.spacing.step4),
          Row(
            children: [
              if (day.wakeCount > 0)
                _MiniMetric(
                  label: context.messages.agentStatsWakesLabel,
                  value: '${day.wakeCount}',
                ),
              if (day.wakeCount > 0) SizedBox(width: tokens.spacing.step5),
              if (day.tokensPerWake > 0)
                _MiniMetric(
                  label: context.messages.agentStatsTokensPerWakeLabel,
                  value: formatTokenCount(day.tokensPerWake),
                ),
              if (day.tokensPerWake > 0) SizedBox(width: tokens.spacing.step5),
              if (day.cacheRate > 0)
                _MiniMetric(
                  label: context.messages.agentStatsCacheRateLabel,
                  value: '${(day.cacheRate * 100).round()}%',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One named slice of a day's token total.
typedef _Slice = ({int value, Color color, String label});

/// The day's breakdown as ordered, colour-keyed slices — computed once
/// and shared by the stacked bar and the caption so the two can never
/// disagree.
///
/// Colours are the interactive ramp's real token steps (enabled → hover
/// → pressed), which lighten in dark mode and darken in light mode —
/// three legible lightness steps instead of judged alpha values. The
/// remainder outside the input/output/thoughts split is a named "Other"
/// slice on the quiet decorative step, so the parts always sum to the
/// day's total.
List<_Slice> _daySlices(BuildContext context, DailyTokenUsage day) {
  final tokens = context.designTokens;
  final ramp = tokens.colors.interactive;
  final messages = context.messages;
  final remainder =
      day.totalTokens - day.inputTokens - day.outputTokens - day.thoughtsTokens;
  return [
    (
      value: day.inputTokens,
      color: ramp.enabled,
      label: messages.agentStatsInputLabel,
    ),
    // Output takes the ramp's far step, not the neighbouring one: Input
    // and Output are the page's two dominant adjacent slices, and their
    // swatches must be tellable apart at legend size.
    (
      value: day.outputTokens,
      color: ramp.pressed,
      label: messages.agentStatsOutputLabel,
    ),
    if (day.thoughtsTokens > 0)
      (
        value: day.thoughtsTokens,
        color: ramp.hover,
        label: messages.agentStatsThoughtsLabel,
      ),
    // A named remainder: a quiet run in the bar must never be readable
    // as "no data" — if it holds tokens, it gets a number.
    if (remainder > 0)
      (
        value: remainder,
        // level03, not the hairline steps: a real 48K run must never be
        // misread as empty track against the card surface.
        color: tokens.colors.decorative.level03,
        label: messages.agentStatsOtherLabel,
      ),
  ];
}

/// One stacked segmented bar for a day's slices — proportions carry
/// the story, hairline gaps of the card surface keep the runs countable.
class _BreakdownStackedBar extends StatelessWidget {
  const _BreakdownStackedBar({required this.slices, this.shareOfTotal});

  final List<_Slice> slices;

  /// When set, the segmented bar fills only this fraction of the row over
  /// a quiet track — the per-model cards' cross-card length encoding. The
  /// hero passes null and keeps the full-width form.
  final double? shareOfTotal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visible = slices.where((s) => s.value > 0).toList();

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: SizedBox(
        height: tokens.spacing.step3,
        child: Row(
          // Stretch, or the childless ColoredBoxes collapse to zero
          // height under the row's loose cross-axis constraint.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, slice) in visible.indexed) ...[
              // A hairline of the card surface between runs, so they are
              // countable without judging neighbouring colours.
              if (index > 0) SizedBox(width: tokens.spacing.step1 / 2),
              Expanded(
                flex: slice.value,
                child: ColoredBox(color: slice.color),
              ),
            ],
          ],
        ),
      ),
    );

    final share = shareOfTotal;
    if (share == null) return bar;
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            child: ColoredBox(color: tokens.colors.decorative.level01),
          ),
        ),
        FractionallySizedBox(
          widthFactor: share.clamp(0.0, 1.0),
          // The same card-surface hairline that separates the runs also
          // ends the fill, so fill-vs-track has a crisp boundary instead
          // of a grey-on-grey seam.
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: tokens.spacing.step1 / 2,
            ),
            child: bar,
          ),
        ),
      ],
    );
  }
}

/// The values line under a stacked bar: one swatch-keyed `label value`
/// item per slice — this caption is the only place these exact numbers
/// live, so no item may ever be hidden. When one line cannot hold every
/// item, they balance onto a two-column grid (2+2, never 3+1): an
/// orphaned last item reads as an afterthought, and these numbers are
/// peers.
class _BreakdownCaption extends StatelessWidget {
  const _BreakdownCaption({required this.slices});

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final swatchSide = tokens.spacing.step4;
    final swatchGap = tokens.spacing.step2;
    final itemGap = tokens.spacing.step3;
    final textScaler = MediaQuery.textScalerOf(context);

    Widget item(_Slice slice) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The swatch keys the caption item to its bar run, so identity
        // never rests on comparing colours by eye — a step4 square, big
        // enough that the ramp's lightness steps stay tellable apart at
        // legend size.
        Container(
          width: swatchSide,
          height: swatchSide,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
        ),
        SizedBox(width: swatchGap),
        // Non-breaking space: a label and its value are one fact and
        // must never split across a wrap.
        Text(
          '${slice.label}\u00a0${formatTokenCount(slice.value)}',
          style: captionStyle,
        ),
      ],
    );

    // Painted width of one item — swatch, gap, and measured text.
    double itemWidth(_Slice slice) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${slice.label}\u00a0${formatTokenCount(slice.value)}',
          style: captionStyle,
        ),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      final width = swatchSide + swatchGap + painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = slices.map(itemWidth).toList();
        final oneLine =
            widths.fold<double>(0, (sum, w) => sum + w) +
            itemGap * (slices.length - 1);
        if (oneLine <= constraints.maxWidth || slices.length < 3) {
          return Wrap(
            spacing: itemGap,
            runSpacing: tokens.spacing.step1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [for (final slice in slices) item(slice)],
          );
        }

        // Two aligned columns; a cell never shrinks below its widest
        // item, so at extreme text scales items simply take a line each
        // instead of clipping.
        final cellWidth = math.max(
          (constraints.maxWidth - itemGap) / 2,
          widths.reduce(math.max),
        );
        return Wrap(
          spacing: itemGap,
          runSpacing: tokens.spacing.step1,
          children: [
            for (final slice in slices)
              SizedBox(width: cellWidth, child: item(slice)),
          ],
        );
      },
    );
  }
}

/// The per-model day echo: a caption date anchor over the same stacked
/// bar + caption grammar as the hero — demoted so card height stops
/// scaling with model count while no number is lost to the merge.
class _CompactDayEcho extends StatelessWidget {
  const _CompactDayEcho({
    required this.dateLabel,
    required this.slices,
    this.shareOfTotal,
  });

  final String dateLabel;
  final List<_Slice> slices;

  /// This model's share (0–1) of the selected day's tokens across all
  /// models. Length-encodes the cross-card ranking: the bar's width, not
  /// just its trailing number, says which model dominated the day.
  final double? shareOfTotal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: tokens.colors.decorative.level01),
        SizedBox(height: tokens.spacing.step4),
        // The date anchors its own line — the hero's rhythm (date, bar,
        // values) — and names the length encoding, so the quiet track can
        // never read as missing data.
        Text(
          shareOfTotal == null
              ? dateLabel
              : '$dateLabel · '
                    '${context.messages.agentStatsModelDayShare((shareOfTotal!.clamp(0.0, 1.0) * 100).round())} · '
                    '${formatTokenCount(slices.fold<int>(0, (sum, x) => sum + x.value))} '
                    '${context.messages.agentStatsTokensUnit}',
          // One size step above the legend caption: the echo's anchor
          // must outrank its values by form, not only by a colour step.
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        _BreakdownStackedBar(slices: slices, shareOfTotal: shareOfTotal),
        SizedBox(height: tokens.spacing.step2),
        _BreakdownCaption(slices: slices),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          value,
          // One tier below the Average/Today pair: the hero card keeps a
          // single subtitle1 stat row, and these diagnostics rank under
          // it.
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
