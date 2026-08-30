import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

/// Shared fill for a measured day: the interactive hue when the day was
/// kept — the handover's `--interactive` square — a wash of it for a partial
/// success (routine kept, target still building), and the neutral level-03
/// surface for anything else. A skipped or missed day is not painted in an
/// alert hue: the strip is a record of what was kept, and a struggling habit
/// is never a wall of red. A recorded miss is told apart from a day nobody
/// looked at by the cross drawn inside the grey (`dayMarkSquareContent`),
/// not by its fill; a skip keeps its weekday letter, and is named by the
/// tooltip and semantics.
/// `SurfaceAlphas.muted` is the sanctioned "reduced-strength accent" alpha, so
/// no new color token is introduced.
Color dayMarkStateFill(DsTokens tokens, DayMarkState state) => switch (state) {
  DayMarkState.full => tokens.colors.interactive.enabled,
  DayMarkState.partial => tokens.colors.interactive.enabled.withValues(
    alpha: SurfaceAlphas.muted,
  ),
  DayMarkState.none ||
  DayMarkState.skipped ||
  DayMarkState.missed => tokens.colors.background.level03,
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
/// A day judged met wears the same interactive hue a measured kept day
/// wears — one green for "good" on every track, so a card that mixes judged
/// and measured days is a baseline plus judgements, not two greens. The
/// three other verdicts take the alert families the reflections history has
/// always used, extended with the blue a restarting agent wears for
/// [DayVerdict.improving], which is progress that is not yet arrival. Sharing
/// one scheme is the point: the strip and the history are two views of the
/// same verdict, and a day filed as missed must not be grey in one place and
/// red in another.
///
/// Notably [DayVerdict.missed] is not the neutral grey a day with no data
/// wears. Deciding a day was missed and never looking at it are different
/// facts, and the strip has to be able to say which.
Color dayVerdictFill(DsTokens tokens, DayVerdict verdict) => switch (verdict) {
  DayVerdict.met => tokens.colors.interactive.enabled,
  DayVerdict.improving => tokens.colors.alert.info.defaultColor,
  DayVerdict.mixed => tokens.colors.alert.warning.defaultColor,
  DayVerdict.missed => tokens.colors.alert.error.defaultColor,
};

/// The verdict's ink for a glyph drawn on an ordinary card surface.
///
/// The family's own ink, tuned for a neutral surface — not the on-alert ink,
/// which would paint near-background on background.
Color dayVerdictSurfaceInk(DsTokens tokens, DayVerdict verdict) =>
    switch (verdict) {
      DayVerdict.met => tokens.colors.alert.success.ink,
      DayVerdict.improving => tokens.colors.alert.info.ink,
      DayVerdict.mixed => tokens.colors.alert.warning.ink,
      DayVerdict.missed => tokens.colors.alert.error.ink,
    };

/// The glyph that names a recorded verdict without relying on its hue.
///
/// The reflections history and the reflect button name a verdict by shape as
/// well as hue: a tick for met, a rising arrow for improving, a half-filled
/// circle for mixed, a cross for missed. A day square draws the same glyph
/// inside its verdict fill (`dayMarkSquareContent`), and the tick and the
/// cross double as the marks of a measured kept and missed day.
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
