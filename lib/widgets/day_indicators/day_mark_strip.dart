import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

/// A row of day cells — the seven-cell picture on each goal row, the
/// completion chain on a dashboard habit card. It is intentionally unlabeled
/// visually, but exposes one concise semantic summary; a tappable strip
/// publishes each day as its own button as well.
class DayMarkStrip extends StatelessWidget {
  const DayMarkStrip({
    required this.marks,
    this.placeholder = false,
    this.onDaySelected,
    this.scrollGroup,
    super.key,
  });

  static bool _allDated(List<DayMark> marks) =>
      marks.every((mark) => mark.day != null);

  final List<DayMark> marks;

  /// True while the strip stands in for a window that has not resolved yet.
  /// Placeholder cells render as dashed outlines, never as the filled grey a
  /// genuinely-empty week wears — "no data yet" and "nothing happened" must
  /// not share an encoding, or the strip contradicts a Healthy chip beside
  /// it.
  final bool placeholder;

  /// Opens the day's reflection. Null leaves the strip a read-only figure —
  /// which is what the list rows want, since a tap there navigates.
  final ValueChanged<DateTime>? onDaySelected;

  /// Joins the page's unison day-track scrolling when the strip renders a
  /// span longer than a week.
  final LinkedScrollGroup? scrollGroup;

  @override
  Widget build(BuildContext context) {
    // The full span, not a seven-day cap: on the detail page the strip
    // follows the page's shared range like every other day track (the list
    // rows keep passing seven-day windows).
    if (marks.isEmpty) return const SizedBox.shrink();
    // Only the extended span needs to know the width it has to fit into; the
    // seven-cell list rows keep their authored pitch and their scale-down fit.
    if (marks.length <= 7) return _build(context, availableWidth: null);
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        availableWidth: constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null,
      ),
    );
  }

  Widget _build(BuildContext context, {required double? availableWidth}) {
    final tokens = context.designTokens;
    final onDaySelected = this.onDaySelected;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dated = _allDated(marks);
    assert(
      onDaySelected == null || placeholder || dated,
      'A tappable strip needs dated marks to name the cell that was tapped.',
    );
    final metrics = dayTrackMetrics(
      context,
      dayCount: marks.length,
      availableWidth: availableWidth,
    );
    final resolvedCellSize = metrics.cellSize;

    // One-letter weekday initials, nested inside the cells themselves — the
    // separate label row above the strip spent a full row on what a letter
    // per node now carries. Dateless strips render no letters.
    final letterFormat = DateFormat.EEEEE(locale);
    final dayFormat = DateFormat.MMMEd(locale);

    String outcomeOf(DayMark mark) => switch (mark.verdict) {
      final verdict? => dayVerdictLabel(context, verdict),
      null => dayMarkStateLabel(context, mark.state),
    };

    Widget cellAt(int index) {
      if (placeholder) return PlaceholderDayCell(size: resolvedCellSize);
      final mark = marks[index];
      final day = mark.day;
      final letter = day == null ? null : letterFormat.format(day);
      if (onDaySelected == null || day == null) {
        return DayMarkCell(
          mark: mark,
          size: resolvedCellSize,
          weekdayLetter: letter,
        );
      }
      final dayName = dayFormat.format(day);
      // Colour and an inner dot are the only thing separating these cells,
      // and neither reaches a screen reader. Each day therefore announces its
      // own state, not just its date — the strip's summary gives a count and
      // cannot say WHICH days went well, which is exactly what a reader needs
      // once every cell is individually actionable.
      final outcome = outcomeOf(mark);
      return DayMarkCell(
        mark: mark,
        size: resolvedCellSize,
        weekdayLetter: letter,
        label: context.messages.goalProgressHabitDaySemantics(
          dayName,
          outcome,
        ),
        tooltipDay: dayName,
        tooltipOutcome: outcome,
        onTap: () => onDaySelected(day),
      );
    }

    // On the page's shared seven-column track when it carries dates, so the
    // whole-goal week lines up column-for-column with the habit squares and
    // the metric bars below it. Three grids for one week meant a reader
    // could not follow a Wednesday down the page.
    //
    // The pitch is narrower than the 48px touch floor — seven of those do not
    // fit a phone card — so, exactly as the habit cells already do, the slot
    // takes the full pitch horizontally and clears the floor vertically.
    final row = !dated
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < marks.length; index++) ...[
                if (index > 0) SizedBox(width: tokens.spacing.step1),
                cellAt(index),
              ],
            ],
          )
        : DayTrack(
            height: onDaySelected == null
                ? resolvedCellSize + tokens.spacing.step2
                : TapTargets.minimum,
            pitch: metrics.pitch,
            children: [
              for (var index = 0; index < marks.length; index++) cellAt(index),
            ],
          );

    // A read-only strip publishes one summary rather than seven nodes, so any
    // recorded verdicts have to reach it there — otherwise the list announces
    // a measured day count while showing four verdict hues.
    final verdictSummary = [
      for (final mark in marks)
        if (mark.verdict case final verdict?)
          if (mark.day case final day?)
            context.messages.goalProgressHabitDaySemantics(
              dayFormat.format(day),
              dayVerdictLabel(context, verdict),
            ),
    ].join(', ');

    return Semantics(
      label: placeholder
          ? context.messages.goalProgressStripLoading
          : [
              // Counted with the verdicts applied. Taken from the measured
              // states alone, the strip could announce "1 successful day"
              // and name that same date as Missed in the next breath, while
              // the cell itself correctly showed the verdict.
              context.messages.goalProgressCompactSemantics(
                marks.where((mark) => mark.successful).length,
              ),
              if (verdictSummary.isNotEmpty) verdictSummary,
            ].join('. '),
      // A tappable strip publishes each day as its own button, so the summary
      // above becomes the container's label rather than the whole story.
      // The scale-down FittedBox is the overflow bound: the track (and the
      // dateless placeholder Row) size themselves to `pitch * days`, and on
      // a 320px phone a list row's column is a few pixels narrower than
      // seven full-size cells. Everywhere with room, the fit is identity.
      // An extended span goes through the page's shared fit-or-scroll policy
      // instead — by WIDTH, like every other track. Wrapping it by day count
      // put a span that fits into a trailing-anchored scroller, which is what
      // opened it with its first days cut off the left edge.
      child: availableWidth != null
          ? fitOrScrollDayTrack(
              contentWidth: metrics.pitch * marks.length,
              availableWidth: availableWidth,
              group: scrollGroup,
              child: row,
            )
          : onDaySelected == null
          ? ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: row,
              ),
            )
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: row,
              ),
            ),
    );
  }
}
