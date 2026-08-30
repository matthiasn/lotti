import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// The edge of a day square on a phone: the control-glyph tier, the
/// smallest square two weekday letters sit inside at a comfortable size.
/// Every day square on a page is this size or the desktop size, never
/// anything in between — see [daySquareSize].
const double kDaySquareSize = IconSizes.m;

/// The edge of every day square on this page: [kDaySquareSize] on a phone,
/// one spacing step more on a desktop-width window. One size per page, so
/// the whole-goal strip, the habit squares and the metric bars keep sharing
/// one column pitch (see `dayTrackMetrics`).
///
/// A desktop row has several times a phone card's width and shows twice the
/// days; a square sized for the phone reads as a speck there and is a
/// smaller thing to aim a pointer at than it needs to be. There is no icon
/// tier between `m` and `l`, and `l` is a callout glyph, so the desktop
/// square is the phone square plus the smallest step rather than a tier up.
double daySquareSize(BuildContext context) => isDesktopLayout(context)
    ? kDaySquareSize + context.designTokens.spacing.step1
    : kDaySquareSize;

/// The weekday a day square names: the first two characters of the locale's
/// abbreviated weekday, so Tuesday and Thursday, Saturday and Sunday can be
/// told apart — one letter left `T T S S` in English and `D D S S` in German
/// (`Di Do Sa So`). Locales whose abbreviation is already one character
/// keep it.
String dayMarkWeekdayLabel(String locale, DateTime day) =>
    DateFormat.E(locale).format(day).characters.take(2).toString();

/// What a day square says inside itself: the glyph of a recorded or judged
/// outcome, or — while the day has none — its weekday.
///
/// A row of squares used to say which day was which only on hover, and a
/// tappable one grew a caption row above itself to say it before the tap.
/// Drawing the weekday inside the unresolved squares answers the question
/// where the eye already is, and the resolved squares do not need it: a
/// tick or a cross beside a lettered neighbour is read against that
/// neighbour's day. The glyphs are the reflections history's own
/// (`dayVerdictGlyph`), so an outcome is drawn the same way wherever it is
/// shown. A recorded miss shares the neutral fill with an empty day, and the
/// cross — in the error family's surface ink — is what tells them apart.
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
  // The content is inset by two spacing steps so it sits inside the square
  // rather than filling it: at one step, two caption letters filled the
  // square edge to edge and read larger than the square they were in.
  final glyphSize = size - tokens.spacing.step2;
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
    case DayMarkState.partial:
      // Kept too — the routine held while a window target was still
      // building — so the tick, in the kept hue itself: the on-accent ink
      // sinks into the muted wash.
      return Icon(
        dayVerdictGlyph(DayVerdict.met),
        size: glyphSize,
        color: tokens.colors.interactive.enabled,
      );
    case DayMarkState.missed:
      // The one touch of the error family a habit square gets: the cross
      // in the family's surface ink, on the neutral fill. A miss should
      // sting a little, and a bad week should still not be a wall of red —
      // the mark carries the hue, the square does not.
      return Icon(
        dayVerdictGlyph(DayVerdict.missed),
        size: glyphSize,
        color: dayVerdictSurfaceInk(tokens, DayVerdict.missed),
      );
    case DayMarkState.none:
    case DayMarkState.skipped:
      if (day == null) return null;
      final locale = Localizations.localeOf(context).toLanguageTag();
      // Scaled down into the same inset the glyphs keep, never wrapped or
      // clipped: two caption-size letters are wider than the square, and a
      // raised text scale must not push them out of a square that does not
      // grow with it. There is no type token below the caption tier, so the
      // fit is what sets the size.
      return SizedBox.square(
        dimension: glyphSize,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            dayMarkWeekdayLabel(locale, day),
            maxLines: 1,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      );
  }
}

/// A not-yet-resolved day slot — a loading window, or today while it is
/// still open: same footprint as a real square, dashed outline instead of a
/// fill, so the silhouette holds without borrowing the empty-day encoding.
/// A dated one carries its weekday like any unresolved square.
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
/// while there is none. Nothing is drawn around a square; the full
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
