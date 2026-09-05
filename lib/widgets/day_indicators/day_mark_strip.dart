import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';
import 'package:material_ui/material_ui.dart';

/// A row of day squares, as the habits handover draws it: one small square
/// per day on the page's shared column pitch, and — for a habit with a run
/// going — a flame and the streak count after the last square. Each square
/// says its outcome or its weekday inside itself, names its date and outcome
/// on hover and to a screen reader, and the strip publishes one concise
/// summary. A tappable strip publishes each day as its own button as well.
class DayMarkStrip extends StatelessWidget {
  const DayMarkStrip({
    required this.marks,
    this.placeholder = false,
    this.streak,
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

  /// The current unbroken run, shown as a flame and the count after the
  /// squares. Null or zero draws no tail.
  final int? streak;

  /// Opens the day's reflection. Null leaves the strip a read-only figure —
  /// which is what the list rows want, since a tap there navigates.
  final ValueChanged<DateTime>? onDaySelected;

  /// Joins the page's unison day-track scrolling when the strip renders a
  /// span longer than a week.
  final LinkedScrollGroup? scrollGroup;

  @override
  Widget build(BuildContext context) {
    final streak = this.streak ?? 0;
    if (marks.isEmpty && streak <= 0) return const SizedBox.shrink();
    // Always measured: even a seven-square row outgrows a phone card once a
    // raised text scale widens the shared pitch for the weekday axis a goal
    // page draws on it.
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
    final metrics = dayTrackMetrics(context);
    final squareSize = daySquareSize(context);
    final dayFormat = DateFormat.MMMEd(locale);

    String outcomeOf(DayMark mark) => switch (mark.verdict) {
      final verdict? => dayVerdictLabel(context, verdict),
      null => dayMarkStateLabel(context, mark.state),
    };

    Widget cellAt(int index) {
      if (placeholder) return const PlaceholderDayCell();
      final mark = marks[index];
      final day = mark.day;
      if (day == null) return DayMarkCell(mark: mark);
      final dayName = dayFormat.format(day);
      final outcome = outcomeOf(mark);
      if (onDaySelected == null) {
        return DayMarkCell(
          mark: mark,
          tooltipDay: dayName,
          tooltipOutcome: outcome,
        );
      }
      // Colour is the only thing separating these squares, and it does not
      // reach a screen reader. Each day therefore announces its own state,
      // not just its date — the strip's summary gives a count and cannot say
      // WHICH days went well, which is exactly what a reader needs once
      // every cell is individually actionable.
      return DayMarkCell(
        mark: mark,
        label: context.messages.goalProgressHabitDaySemantics(
          dayName,
          outcome,
        ),
        tooltipDay: dayName,
        tooltipOutcome: outcome,
        onTap: () => onDaySelected(day),
      );
    }

    // The squares sit on the page's shared column track so the whole-goal
    // week lines up column-for-column with the habit squares and the metric
    // bars below it. The pitch is narrower than the touch floor — seven of
    // those do not fit a phone card — so a tappable slot takes the full pitch
    // horizontally and clears the floor vertically.
    final squares = DayTrack(
      height: onDaySelected == null ? squareSize : TapTargets.minimum,
      pitch: metrics.pitch,
      children: [
        for (var index = 0; index < marks.length; index++) cellAt(index),
      ],
    );
    final streak = this.streak ?? 0;
    final countStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    // The tail never scrolls away with the squares: the count is the one
    // fact the strip states in words, so the squares fit or pan in whatever
    // width is left beside it.
    final tailWidth = streak <= 0
        ? 0.0
        : tokens.spacing.step2 +
              squareSize +
              tokens.spacing.step1 +
              _textWidth(context, '$streak', countStyle);
    final fitted = availableWidth == null
        ? squares
        : fitOrScrollDayTrack(
            contentWidth: metrics.pitch * marks.length,
            availableWidth: math.max(0, availableWidth - tailWidth),
            group: scrollGroup,
            child: squares,
          );
    final row = streak <= 0
        ? fitted
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: fitted),
              // Text-grade separation from the chain, so the flame reads as
              // the count's icon rather than one more cell. Flame and count
              // share the handover's medium-emphasis ink — the flame in the
              // kept hue read as one more kept day — and the flame sits at
              // the square's own size so square, glyph and numeral share one
              // optical line. The count is the one fact the strip states in
              // words, so it takes the handover's 13px tier at the nearest
              // token, not the caption size of the annotations around it.
              SizedBox(width: tokens.spacing.step2),
              Icon(
                LottiIcons.streak,
                size: squareSize,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step1),
              Text('$streak', style: countStyle),
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
    final summary = placeholder
        ? context.messages.goalProgressStripLoading
        : [
            if (streak > 0)
              context.messages.habitStreakDaysSemantic(streak)
            else
              // Counted with the verdicts applied: taken from the measured
              // states alone, the strip could announce "1 successful day"
              // and name that same date as Missed in the next breath.
              context.messages.goalProgressCompactSemantics(
                marks.where((mark) => mark.successful).length,
              ),
            if (verdictSummary.isNotEmpty) verdictSummary,
          ].join('. ');

    // An extended span goes through the page's shared fit-or-scroll policy —
    // by WIDTH, like every other track. Wrapping it by day count put a span
    // that fits into a trailing-anchored scroller, which is what opened it
    // with its first days cut off the left edge. A tappable strip publishes
    // each day as its own button, so the summary becomes the container's
    // label rather than the whole story.
    final content = Align(
      alignment: AlignmentDirectional.centerStart,
      child: row,
    );
    return Semantics(
      label: summary,
      child: onDaySelected == null ? ExcludeSemantics(child: content) : content,
    );
  }
}

double _textWidth(BuildContext context, String text, TextStyle style) =>
    (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width;
