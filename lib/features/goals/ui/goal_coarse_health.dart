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
/// beginning, read in teal, never framed as failure or coloured red.
GoalCoarseHealth coarseHealthOf(GoalTrackStatus? status) => switch (status) {
  GoalTrackStatus.onTrack ||
  GoalTrackStatus.achieved => GoalCoarseHealth.healthy,
  GoalTrackStatus.atRisk || GoalTrackStatus.offTrack => GoalCoarseHealth.behind,
  GoalTrackStatus.recovering => GoalCoarseHealth.restarting,
  GoalTrackStatus.insufficientData || null => GoalCoarseHealth.notEnoughData,
};

String goalCoarseHealthLabel(AppLocalizations messages, GoalCoarseHealth h) =>
    switch (h) {
      GoalCoarseHealth.healthy => messages.goalCoarseHealthHealthy,
      GoalCoarseHealth.behind => messages.goalCoarseHealthBehind,
      GoalCoarseHealth.restarting => messages.goalCoarseHealthRestarting,
      GoalCoarseHealth.notEnoughData => messages.goalCoarseHealthNotEnoughData,
    };

/// The chip/arrow hue for each coarse state. Restarting is the interactive
/// teal — a fresh start, deliberately NOT red.
Color goalCoarseHealthColor(GoalCoarseHealth h, DsColors colors) => switch (h) {
  GoalCoarseHealth.healthy => colors.alert.success.defaultColor,
  GoalCoarseHealth.behind => colors.alert.warning.defaultColor,
  GoalCoarseHealth.restarting => colors.interactive.enabled,
  GoalCoarseHealth.notEnoughData => colors.text.lowEmphasis,
};

/// The Material icon for a direction, stroked in the chip's hue by the row.
IconData goalHealthDirectionIcon(GoalHealthDirection direction) =>
    switch (direction) {
      GoalHealthDirection.up => Icons.trending_up_rounded,
      GoalHealthDirection.flat => Icons.trending_flat_rounded,
      GoalHealthDirection.down => Icons.trending_down_rounded,
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
        style: tokens.typography.styles.others.caption.copyWith(color: color),
      ),
    );
  }
}
