import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// The edge of a day square on a phone: the smallest square a weekday
/// letter is still legible in. Every day square on a page is this size or
/// the desktop size, never anything in between — see [daySquareSize].
const double kDaySquareSize = IconSizes.s;

/// The edge of a day square on a desktop window: one icon size up.
///
/// A desktop row has several times a phone card's width and shows twice the
/// days; a square sized for the phone reads as a speck there and is a
/// smaller thing to aim a pointer at than it needs to be.
const double kDaySquareSizeDesktop = IconSizes.m;

/// The edge of every day square on this page: [kDaySquareSizeDesktop] on a
/// desktop-width window, [kDaySquareSize] otherwise. One size per page, so
/// the whole-goal strip, the habit squares and the metric bars keep sharing
/// one column pitch (see `dayTrackMetrics`).
double daySquareSize(BuildContext context) =>
    isDesktopLayout(context) ? kDaySquareSizeDesktop : kDaySquareSize;

/// What a day square says inside itself: the glyph of a recorded or judged
/// outcome, or — while the day has none — its weekday initial.
///
/// A row of squares used to say which day was which only on hover, and a
/// tappable one grew a caption row above itself to say it before the tap.
/// Drawing the letter inside the unresolved squares answers the question
/// where the eye already is, and the resolved squares do not need it: a
/// tick or a cross beside a lettered neighbour is read against that
/// neighbour's day. The glyphs are the reflections history's own
/// (`dayVerdictGlyph`), so an outcome is drawn the same way wherever it is
/// shown. A recorded miss shares the neutral fill with an empty day, and the
/// cross is what tells them apart.
///
/// Null for an undated, unresolved square — a streak chain has nothing to
/// say inside its cells.
Widget? dayMarkSquareContent(
  BuildContext context, {
  required DayMarkState state,
  required DayVerdict? verdict,
  required DateTime? day,
  required double size,
}) {
  final tokens = context.designTokens;
  // The glyph is inset by one spacing step so it sits inside the square
  // rather than on its edge.
  final glyphSize = size - tokens.spacing.step1;
  if (verdict != null) {
    return Icon(
      dayVerdictGlyph(verdict),
      size: glyphSize,
      color: tokens.colors.text.onInteractiveAlert,
    );
  }
  switch (state) {
    case DayMarkState.full:
      return Icon(
        dayVerdictGlyph(DayVerdict.met),
        size: glyphSize,
        color: tokens.colors.text.onInteractiveAlert,
      );
    case DayMarkState.missed:
      return Icon(
        dayVerdictGlyph(DayVerdict.missed),
        size: glyphSize,
        color: tokens.colors.text.mediumEmphasis,
      );
    case DayMarkState.none:
    case DayMarkState.partial:
    case DayMarkState.skipped:
      if (day == null) return null;
      final locale = Localizations.localeOf(context).toLanguageTag();
      // Quiet on the neutral fill; a step louder on the partial wash, where
      // the low-emphasis ink sinks into the tint.
      final ink = state == DayMarkState.partial
          ? tokens.colors.text.mediumEmphasis
          : tokens.colors.text.lowEmphasis;
      // Scaled down, never wrapped or clipped: the caption size fits the
      // square at the default text scale, and a raised scale must not push
      // the letter out of a square that does not grow with it.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          DateFormat.EEEEE(locale).format(day),
          maxLines: 1,
          style: tokens.typography.styles.others.caption.copyWith(color: ink),
        ),
      );
  }
}

/// A not-yet-resolved day slot — a loading window, or today while it is
/// still open: same footprint as a real square, dashed outline instead of a
/// fill, so the silhouette holds without borrowing the empty-day encoding.
/// A dated one carries its weekday initial like any unresolved square.
class PlaceholderDayCell extends StatelessWidget {
  const PlaceholderDayCell({this.day, super.key});

  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = daySquareSize(context);
    return DsDashedBorder(
      color: tokens.colors.text.lowEmphasis,
      radius: tokens.radii.xs,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: dayMarkSquareContent(
            context,
            state: DayMarkState.none,
            verdict: null,
            day: day,
            size: size,
          ),
        ),
      ),
    );
  }
}

/// One day square, as the habits handover draws it: a small rounded square
/// filled in the interactive hue when the day was kept and in the neutral
/// level-03 surface otherwise — a recorded verdict paints its own hue, and an
/// empty TODAY is the dashed unresolved outline, since the day is not over.
/// Inside it, [dayMarkSquareContent]: the outcome's glyph, or the weekday
/// initial while there is none. Nothing is drawn around a square; the full
/// date, the outcome's name and a verdict's are answered by the tooltip and
/// the semantics.
///
/// Read-only by default. With [onTap] the square keeps its size while the
/// hit slot around it clears the touch floor, and the cell announces itself
/// as a button with [label].
class DayMarkCell extends StatelessWidget {
  const DayMarkCell({
    required this.mark,
    this.onTap,
    this.label,
    this.tooltipDay,
    this.tooltipOutcome,
    super.key,
  });

  final DayMark mark;
  final VoidCallback? onTap;

  /// Spoken name for a tappable cell. Null on a read-only strip, whose
  /// semantics are carried by the summary above it.
  final String? label;

  /// The hover tooltip: the day names the subject, the outcome describes it.
  /// A read-only cell still answers hover with them — the letter names a
  /// weekday, not a date, and the tooltip is where a dated cell reveals
  /// which day it stands for.
  final String? tooltipDay;
  final String? tooltipOutcome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final verdict = mark.verdict;
    final size = daySquareSize(context);
    final Widget cell = mark.pending
        ? PlaceholderDayCell(day: mark.day)
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: verdict == null
                  ? dayMarkStateFill(tokens, mark.state)
                  : dayVerdictFill(tokens, verdict),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
            child: dayMarkSquareContent(
              context,
              state: mark.state,
              verdict: verdict,
              day: mark.day,
              size: size,
            ),
          );
    final onTap = this.onTap;
    if (onTap == null) {
      final tooltipDay = this.tooltipDay;
      if (tooltipDay == null) return cell;
      return DsTooltip(
        title: tooltipDay,
        message: tooltipOutcome ?? '',
        preferBelow: false,
        child: cell,
      );
    }
    // The square keeps its size; the hit slot around it takes the full height
    // of the touch floor and whatever width the row can spare. No hover fill:
    // the slot is far larger than the square it serves, and Material's
    // overlay drew a phantom button bulging around the cell. Hover answers
    // with the tooltip instead. `excludeSemantics` drops the ink well's own
    // node, so the activation action is published here.
    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
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
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Center(child: cell),
          ),
        ),
      ),
    );
  }
}
