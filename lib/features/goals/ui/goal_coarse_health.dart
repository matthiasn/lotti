import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The coarse health a goal-agent list row shows — the ONLY health
/// vocabulary that ever reaches a chip or label (design handover: no
/// percentages, no fine gradations on labels). The finer runtime statuses
/// collapse into these four; deficit counts and "aging out" drive copy and
/// the progress grid, never a chip.
enum GoalCoarseHealth { healthy, behind, restarting, notEnoughData }

/// Collapses the runtime [GoalTrackStatus] (and a null "no register yet")
/// into the coarse vocabulary. `recovering` maps to **restarting** — a
/// beginning, read in the info hue, never framed as failure or coloured red.
GoalCoarseHealth coarseHealthOf(GoalTrackStatus? status) => switch (status) {
  GoalTrackStatus.onTrack ||
  GoalTrackStatus.achieved => GoalCoarseHealth.healthy,
  GoalTrackStatus.atRisk || GoalTrackStatus.offTrack => GoalCoarseHealth.behind,
  GoalTrackStatus.recovering => GoalCoarseHealth.restarting,
  GoalTrackStatus.insufficientData || null => GoalCoarseHealth.notEnoughData,
};

/// The chip a surface should show for [status], or null when it must show
/// none.
///
/// "Not enough data" is a statement about the agent's ability to judge. Once
/// it HAS judged — once a standing report is on the same screen saying blood
/// pressure and weight are above target while steps and one habit lag — the
/// chip contradicts the very thing it sits beside, and the reader has to
/// decide which of the two to believe.
///
/// Coverage can still be genuinely thin, and the report says so in its own
/// coverage sentence. That is a caveat inside an assessment, which is honest;
/// a headline replacing the assessment is not.
///
/// Deliberately a display rule rather than a change to the evaluator:
/// [GoalTrackStatus.insufficientData] still means what it always meant, and
/// everything keyed off it — nudge tone, the contract's "name the gap; do not
/// chide" — is untouched.
GoalCoarseHealth? coarseHealthChip(
  GoalTrackStatus? status, {
  required bool hasStandingAssessment,
}) {
  final coarse = coarseHealthOf(status);
  if (coarse == GoalCoarseHealth.notEnoughData && hasStandingAssessment) {
    return null;
  }
  return coarse;
}

String goalCoarseHealthLabel(AppLocalizations messages, GoalCoarseHealth h) =>
    switch (h) {
      GoalCoarseHealth.healthy => messages.goalCoarseHealthHealthy,
      GoalCoarseHealth.behind => messages.goalCoarseHealthBehind,
      GoalCoarseHealth.restarting => messages.goalCoarseHealthRestarting,
      GoalCoarseHealth.notEnoughData => messages.goalCoarseHealthNotEnoughData,
    };

/// The chip/arrow hue for each coarse state. Restarting is the info hue — a
/// fresh start, deliberately NOT red, and deliberately not a green: the
/// interactive teal reads as Healthy's success green at chip size, and green
/// must mean exactly one thing on a health surface.
Color goalCoarseHealthColor(GoalCoarseHealth h, DsColors colors) => switch (h) {
  GoalCoarseHealth.healthy => colors.alert.success.defaultColor,
  GoalCoarseHealth.behind => colors.alert.warning.defaultColor,
  GoalCoarseHealth.restarting => colors.alert.info.defaultColor,
  GoalCoarseHealth.notEnoughData => colors.text.lowEmphasis,
};

/// The independent direction hue. A goal can be behind while improving or
/// healthy while slipping, so direction never borrows the coarse-health hue.
Color goalHealthDirectionColor(
  GoalHealthDirection direction,
  DsColors colors,
) => switch (direction) {
  GoalHealthDirection.up => colors.alert.success.defaultColor,
  GoalHealthDirection.flat => colors.text.lowEmphasis,
  GoalHealthDirection.down => colors.alert.warning.defaultColor,
};

/// The Material icon for a direction, stroked in the chip's hue by the row.
IconData goalHealthDirectionIcon(GoalHealthDirection direction) =>
    switch (direction) {
      GoalHealthDirection.up => Icons.trending_up_rounded,
      GoalHealthDirection.flat => Icons.trending_flat_rounded,
      GoalHealthDirection.down => Icons.trending_down_rounded,
    };

/// The screen-reader label for a trend direction — the arrow is otherwise the
/// row's only signal that attainment is rising, holding, or falling, and it
/// carries no text a screen reader can announce on its own.
String goalHealthDirectionLabel(
  AppLocalizations messages,
  GoalHealthDirection direction,
) => switch (direction) {
  GoalHealthDirection.up => messages.goalHealthTrendUp,
  GoalHealthDirection.flat => messages.goalHealthTrendFlat,
  GoalHealthDirection.down => messages.goalHealthTrendDown,
};

/// The coarse-health chip: a small tinted pill, the only place a list row
/// names health. Colour + label both derive from [health].
class GoalCoarseHealthChip extends StatelessWidget {
  const GoalCoarseHealthChip({required this.health, super.key});

  final GoalCoarseHealth health;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = goalCoarseHealthColor(health, tokens.colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        goalCoarseHealthLabel(context.messages, health),
        // The hue lives in the fill; the label reads in high-emphasis text so
        // the 12px caption clears the 4.5:1 contrast floor over a wash of the
        // same hue in both themes (a full-hue caption over its own wash fails
        // it for success/warning/restarting in the light theme).
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

/// A separate trend pill for the goal's direction of travel.
class GoalHealthDirectionChip extends StatelessWidget {
  const GoalHealthDirectionChip({required this.direction, super.key});

  final GoalHealthDirection direction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = goalHealthDirectionColor(direction, tokens.colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            goalHealthDirectionIcon(direction),
            size: tokens.spacing.step4,
            color: tokens.colors.text.highEmphasis,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            goalHealthDirectionLabel(context.messages, direction),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
