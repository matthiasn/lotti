import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// A not-yet-resolved day slot: same footprint as a real cell, dashed
/// outline instead of a fill, so the silhouette holds without borrowing the
/// empty-week encoding.
class PlaceholderDayCell extends StatelessWidget {
  const PlaceholderDayCell({this.size = IconSizes.xs, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: DsDashedBorder(
        color: tokens.colors.text.lowEmphasis,
        radius: dayCellRadius(tokens),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

/// One day square: the measured state's fill, the recorded verdict's fill and
/// glyph where one outranks it, the partial dot or outcome glyph as the
/// non-color cue, a corner weekday letter when nothing stronger claims the
/// center, and the dashed ring on today.
///
/// Read-only by default. With [onTap] the square keeps its size while the
/// hit slot around it clears the touch floor, and the cell announces itself
/// as a button with [label].
class DayMarkCell extends StatelessWidget {
  const DayMarkCell({
    required this.mark,
    this.size = IconSizes.xs,
    this.onTap,
    this.label,
    this.tooltipDay,
    this.tooltipOutcome,
    this.weekdayLetter,
    super.key,
  });

  final DayMark mark;
  final double size;
  final VoidCallback? onTap;

  /// One-letter weekday initial nested in the cell, replacing the label row
  /// that used to run above the strip. Null on strips without dates.
  final String? weekdayLetter;

  /// Spoken name for a tappable cell. Null on a read-only strip, whose
  /// semantics are carried by the summary above it.
  final String? label;

  /// The same fact split for the hover tooltip: the day names the subject,
  /// the outcome describes it. A read-only cell still answers hover with
  /// them — the corner letter cannot tell one Tuesday from the next, and the
  /// tooltip is where a dated cell reveals which day it stands for.
  final String? tooltipDay;
  final String? tooltipOutcome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final verdict = mark.verdict;
    final state = mark.state;
    // The dot is the measured-partial cue; a recorded verdict wears its own
    // glyph instead. Either way the cell says something a reader who cannot
    // separate the hues can still act on.
    final showsPartialDot = verdict == null && state == DayMarkState.partial;
    final stateGlyph = verdict == null ? dayMarkStateGlyph(state) : null;
    final Widget? centerMark = showsPartialDot
        ? Center(
            child: partialDayDot(
              tokens,
              // The dot has to stay legible inside the square it marks, so
              // it scales with it rather than sitting at one fixed size.
              size <= IconSizes.xs
                  ? tokens.spacing.step1
                  : tokens.spacing.step2,
            ),
          )
        : verdict != null
        // The verdict's own shape at every size. Collapsing the three
        // non-met verdicts into one dot on the list's 12px cells left
        // Improving, Mixed and Missed distinguishable by hue alone —
        // which is the one thing the shapes exist to avoid.
        ? Center(
            child: Icon(
              dayVerdictGlyph(verdict),
              size: size * 0.75,
              // The ink of the fill's OWN family. Painting every glyph in
              // the success ink put a green tick's colour on a red missed
              // cell and an orange mixed one.
              color: dayVerdictInk(tokens, verdict),
            ),
          )
        : stateGlyph != null
        ? Center(
            child: Icon(
              stateGlyph,
              size: size * 0.75,
              color: dayMarkStateGlyphInk(tokens, state),
            ),
          )
        : null;
    // The corner weekday tag renders only when the center is empty: at the
    // compact cell size a glyph and a corner letter collide, and the glyph
    // is the rarer, more meaningful mark — neighbouring plain cells keep
    // carrying the axis.
    final letterTag = centerMark != null
        ? null
        : dayCellLetter(
            tokens,
            letter: weekdayLetter,
            cellSize: size,
            filled: verdict != null || state == DayMarkState.full,
          );
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: verdict == null
            ? dayMarkStateFill(tokens, state)
            : dayVerdictFill(tokens, verdict),
        borderRadius: BorderRadius.circular(dayCellRadius(tokens)),
      ),
      child: centerMark == null && letterTag == null
          ? null
          : Stack(
              children: [?centerMark, ?letterTag],
            ),
    );
    // Every cell shares one outer footprint; today only adds the dashed
    // ring inside it, so the strip's rhythm never bulges at the last cell.
    final padded = Padding(
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: cell,
    );
    final decorated = mark.isToday
        ? DsDashedBorder(
            color: todayRingInk(tokens),
            strokeWidth: BorderWidths.emphasis,
            radius: dayCellRadius(tokens),
            child: padded,
          )
        : padded;
    final onTap = this.onTap;
    if (onTap == null) {
      final tooltipDay = this.tooltipDay;
      if (tooltipDay == null) return decorated;
      return DsTooltip(
        title: tooltipDay,
        message: tooltipOutcome ?? '',
        preferBelow: false,
        child: decorated,
      );
    }
    // The square keeps its size; the hit slot around it takes the full height
    // of the touch floor and whatever width the row can spare. Growing the
    // square itself to 48px would make the strip shout over the habit rows it
    // is meant to summarise.
    // No hover fill: the hit slot is far larger than the square it serves,
    // so Material's overlay drew a phantom button bulging around the cell.
    // The cell is a data readout — hover answers with the styled tooltip
    // naming the day and its outcome, not with a fill on the data itself.
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: DsTooltip(
        title: tooltipDay,
        message: tooltipOutcome ?? '',
        preferBelow: false,
        child: DsQuietInk(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          focusRing: true,
          builder: (context, highlighted) => ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TapTargets.minimum,
            ),
            child: Center(child: decorated),
          ),
        ),
      ),
    );
  }
}
