import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

/// The corner radius every day cell shares.
///
/// The whole-goal strip once drew its squares at `radii.xs` while the habit
/// squares — the identical footprint, one card below — drew theirs at
/// `radii.s`. Same instrument, same week, two shapes.
double dayCellRadius(DsTokens tokens) => tokens.radii.s;

/// Where the weekday initial sits inside a day cell, and how big it gets.
///
/// Deliberately NOT an extension on `DsTokens`. Hanging these off the token
/// object put feature-specific geometry into the canonical token API, where
/// every caller in the app would see `tokens.letterInsetStart` offered
/// alongside real exported tokens — which is a bigger claim than "these
/// three numbers live in one place" was ever meant to make.
///
/// Proportions of the cell rather than absolute lengths: the cell itself is
/// sized by `dayTrackMetrics` from the available width, so a fixed inset that
/// looked right on a fortnight track would crowd the corner on a ninety-day
/// one. They are geometry, not spacing — there is no design-system token for
/// "a fraction of a cell" — so they live here, named and in ONE place, rather
/// than as bare numbers inside the widget.
///
/// [DayCellLetter.scaleBox] is a ceiling, not a size: the rendered letter is
/// `min(fontSize, cellSize * scaleBox)`, because the glyph is fitted with
/// [BoxFit.scaleDown] and that never scales UP. The box therefore governs
/// small cells while the style's own size caps large ones.
abstract final class DayCellLetter {
  /// Inset from the cell's leading edge.
  static const double insetStart = 0.18;

  /// Inset from the cell's bottom edge.
  static const double insetBottom = 0.14;

  /// Ceiling on the letter's height, as a fraction of the cell.
  static const double scaleBox = 0.38;
}

/// Shared fill for a measured day: the full-strength success hue when the
/// requirement held as of that day, a lighter wash of the same hue for a
/// partial success (routine kept, target still building), the error hue for a
/// recorded miss, neutral for a skip or an empty day. `SurfaceAlphas.muted`
/// is the sanctioned "reduced-strength accent" alpha, so no new color token
/// is introduced. Data-that-happened wears the `alert` families; the
/// interactive teal stays strictly for things the user can tap.
Color dayMarkStateFill(DsTokens tokens, DayMarkState state) => switch (state) {
  DayMarkState.full => tokens.colors.alert.success.defaultColor,
  DayMarkState.partial => tokens.colors.alert.success.defaultColor.withValues(
    alpha: SurfaceAlphas.muted,
  ),
  DayMarkState.missed => tokens.colors.alert.error.defaultColor,
  DayMarkState.none || DayMarkState.skipped => tokens.colors.background.level03,
};

/// The non-color cue a recorded outcome carries: a cross for a miss, a dash
/// for a skip. Null for the states whose cue is the fill (or the partial dot).
IconData? dayMarkStateGlyph(DayMarkState state) => switch (state) {
  DayMarkState.missed => LottiIcons.close,
  DayMarkState.skipped => LottiIcons.remove,
  DayMarkState.none || DayMarkState.partial || DayMarkState.full => null,
};

/// The ink a state glyph is drawn in, on top of that state's own fill.
///
/// The missed cross sits on the saturated error fill, so it takes the
/// design system's on-alert ink — the family's own `ink` is tuned for a
/// neutral surface and all but vanishes on its own hue. The skip dash sits
/// on a neutral fill and keeps the medium-emphasis text ink.
Color dayMarkStateGlyphInk(DsTokens tokens, DayMarkState state) =>
    switch (state) {
      DayMarkState.missed => tokens.colors.text.onInteractiveAlert,
      DayMarkState.none ||
      DayMarkState.partial ||
      DayMarkState.full ||
      DayMarkState.skipped => tokens.colors.text.mediumEmphasis,
    };

/// The localized name of a measured state, shared by every day cell's
/// semantics and tooltip so a "done" day is called the same thing everywhere.
String dayMarkStateLabel(BuildContext context, DayMarkState state) =>
    switch (state) {
      DayMarkState.full => context.messages.goalProgressDone,
      DayMarkState.partial => context.messages.goalProgressPartial,
      DayMarkState.none => context.messages.goalProgressHabitDayNoEntry,
      DayMarkState.skipped => context.messages.completeHabitSkipButton,
      DayMarkState.missed => context.messages.completeHabitFailButton,
    };

/// Hue for a day the user has actually judged, which outranks what the app
/// measured: a reflection is a statement about the day, and the measurement is
/// only evidence toward one.
///
/// Four distinct hues, all existing alert tokens, and the same three the
/// reflections-history pill has always used — extended with the blue a
/// restarting agent wears for [DayVerdict.improving], which is progress that
/// is not yet arrival. Sharing one scheme is the point: the strip and the
/// history are two views of the same verdict, and a day filed as missed must
/// not be grey in one place and red in another.
///
/// Notably [DayVerdict.missed] is not the neutral grey a day with no data
/// wears. Deciding a day was missed and never looking at it are different
/// facts, and the strip has to be able to say which.
Color dayVerdictFill(DsTokens tokens, DayVerdict verdict) => switch (verdict) {
  DayVerdict.met => tokens.colors.alert.success.defaultColor,
  DayVerdict.improving => tokens.colors.alert.info.defaultColor,
  DayVerdict.mixed => tokens.colors.alert.warning.defaultColor,
  DayVerdict.missed => tokens.colors.alert.error.defaultColor,
};

/// The ink a verdict glyph is drawn in, on top of that verdict's own fill.
///
/// One high-contrast ink for every verdict rather than each family's own:
/// the families' inks are tuned to sit on a NEUTRAL surface, so a success ink
/// on a success fill is green on green and the glyph all but disappears —
/// which defeats the point of having a shape at all, since the shape exists
/// for readers who cannot separate the hues. `onInteractiveAlert` is the
/// design system's ink for exactly this: text over a saturated alert fill.
Color dayVerdictInk(DsTokens tokens, DayVerdict verdict) =>
    tokens.colors.text.onInteractiveAlert;

/// The verdict's ink for a glyph drawn on an ordinary card surface.
///
/// Distinct from [dayVerdictInk], which is for a glyph sitting on that
/// verdict's own saturated fill. Using the on-alert ink here paints
/// near-background on background; using this one on a fill would be its own
/// hue on itself.
Color dayVerdictSurfaceInk(DsTokens tokens, DayVerdict verdict) =>
    switch (verdict) {
      DayVerdict.met => tokens.colors.alert.success.ink,
      DayVerdict.improving => tokens.colors.alert.info.ink,
      DayVerdict.mixed => tokens.colors.alert.warning.ink,
      DayVerdict.missed => tokens.colors.alert.error.ink,
    };

/// The glyph that names a recorded verdict without relying on its hue.
///
/// Four fills that differ only by colour are four fills a red-green colour
/// deficiency cannot tell apart, and the strip's whole job is to be read at a
/// glance. Each verdict therefore carries a shape as well: a tick for met, a
/// rising arrow for improving, a half-filled circle for mixed, a cross for
/// missed.
IconData dayVerdictGlyph(DayVerdict verdict) => switch (verdict) {
  DayVerdict.met => LottiIcons.confirm,
  DayVerdict.improving => LottiIcons.trendingUp,
  DayVerdict.mixed => LottiIcons.contrast,
  DayVerdict.missed => LottiIcons.close,
};

/// The localized name of a day verdict, shared by the strip's semantics and
/// the reflection sheet's own toggle so the two can never drift apart.
String dayVerdictLabel(BuildContext context, DayVerdict verdict) =>
    switch (verdict) {
      DayVerdict.met => context.messages.goalAssessmentMet,
      DayVerdict.improving => context.messages.goalAssessmentImproving,
      DayVerdict.mixed => context.messages.goalAssessmentMixed,
      DayVerdict.missed => context.messages.goalAssessmentMissed,
    };

/// The weekday's one-letter initial, tucked into the bottom-left corner of
/// its own day cell.
///
/// Replaces the separate label row that used to run above every track: one
/// letter per node keeps the weekday axis without spending a full row on it.
/// A quiet corner tag rather than a centered label. It yields entirely to
/// the marks that outrank it — a verdict glyph, the partial dot, the missed
/// cross — because at the compact cell size a corner letter and a center
/// glyph collide; the rarer mark wins and neighbouring plain cells keep
/// carrying the axis. Scaled down with the cell (never up past the
/// `bodySmall` size), and null when the cell is too small to hold a legible
/// letter — a squeezed ninety-day track drops the letters rather than
/// painting mush.
///
/// Ink follows the fill so the letter stays readable on both states: the
/// on-alert ink over a saturated fill, medium emphasis over the neutral and
/// washed fills. Returns a [PositionedDirectional]; the cell hosts it in a
/// [Stack].
Widget? dayCellLetter(
  DsTokens tokens, {
  required String? letter,
  required double cellSize,
  required bool filled,
}) {
  if (letter == null || cellSize < IconSizes.l) return null;
  return PositionedDirectional(
    // Off the corner, not in it. The letter reads better with a little air
    // under and behind it than pinned to the rounded rect's inner angle —
    // but it stays an annotation, so it moves TOWARD the center rather than
    // to it.
    start: cellSize * DayCellLetter.insetStart,
    bottom: cellSize * DayCellLetter.insetBottom,
    child: SizedBox(
      // The scale bound: the glyph shrinks into this box, so the letter
      // stays a small corner annotation at every cell size instead of
      // competing with the mark in the center. The effective size is
      // `min(fontSize, this height)` — `scaleDown` never scales UP — so
      // raising the letter one step means raising BOTH: the box governs the
      // small cells, the style's own size caps the large ones.
      height: cellSize * DayCellLetter.scaleBox,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter,
          maxLines: 1,
          // One step up the type scale from caption (12 → 14), so a cell
          // roomy enough to show the letter at full size shows it a step
          // larger too.
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: filled
                ? tokens.colors.text.onInteractiveAlert
                : tokens.colors.text.mediumEmphasis,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

/// The glyph inside a day square, as a fraction of the square: large enough
/// to read as a shape, small enough to leave the fill visible around it. One
/// rule for the cells and for the legend swatches that key them, so the key
/// cannot drift from the map.
double dayMarkGlyphSize(double cellSize) => cellSize * 0.75;

/// The ink the "today" ring is drawn in, on every surface that draws one —
/// the habit day cells, the whole-goal strip and the legend swatch that keys
/// them.
///
/// Medium emphasis rather than low: at `radii.xs` on a dark surface a
/// hairline in the low-emphasis ink is a rumour, not a ring. It still has to
/// stay quieter than a day's own fill, which is the thing the cell is
/// actually reporting — so it lifts one step and takes the emphasis stroke,
/// rather than becoming an accent.
Color todayRingInk(DsTokens tokens) => tokens.colors.text.mediumEmphasis;

/// The non-color cue for a partial day: a full-strength dot inside the
/// lighter wash, so full/partial/none survive without a legend (the list
/// rows carry none) and for color-blind readers.
Widget partialDayDot(DsTokens tokens, double diameter) => Container(
  width: diameter,
  height: diameter,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: tokens.colors.alert.success.ink,
  ),
);
