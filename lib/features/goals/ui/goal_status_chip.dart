import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The localized display label of a track status.
String goalTrackStatusLabel(AppLocalizations messages, GoalTrackStatus status) {
  return switch (status) {
    GoalTrackStatus.onTrack => messages.goalStatusOnTrack,
    GoalTrackStatus.atRisk => messages.goalStatusAtRisk,
    GoalTrackStatus.offTrack => messages.goalStatusOffTrack,
    GoalTrackStatus.recovering => messages.goalStatusRecovering,
    GoalTrackStatus.achieved => messages.goalStatusAchieved,
    GoalTrackStatus.insufficientData => messages.goalStatusInsufficientData,
  };
}

/// The status hue, bound to the semantic alert palette: good news reads
/// success, grace reads warning, decisively-behind reads error, and a
/// data gap stays deliberately neutral (never guilt-trip over a tracker
/// outage).
Color goalTrackStatusColor(DsColors colors, GoalTrackStatus status) {
  return switch (status) {
    GoalTrackStatus.onTrack ||
    GoalTrackStatus.achieved ||
    GoalTrackStatus.recovering => colors.alert.success.defaultColor,
    GoalTrackStatus.atRisk => colors.alert.warning.defaultColor,
    GoalTrackStatus.offTrack => colors.alert.error.defaultColor,
    GoalTrackStatus.insufficientData => colors.text.lowEmphasis,
  };
}

/// The compact health chip on agent cards and detail headers.
class GoalStatusChip extends StatelessWidget {
  const GoalStatusChip({required this.status, super.key});

  final GoalTrackStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = goalTrackStatusColor(tokens.colors, status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.tint),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        goalTrackStatusLabel(context.messages, status),
        style: tokens.typography.styles.others.caption.copyWith(color: color),
      ),
    );
  }
}

/// The user-facing label for a PAST ad's outcome in the detail timeline.
/// Pipeline states (`draft`/`ready`/`active`/`failed`) never render here.
String goalNudgeStatusLabel(BuildContext context, GoalNudgeStatus status) =>
    switch (status) {
      GoalNudgeStatus.dismissed => context.messages.goalNudgeStatusDismissed,
      GoalNudgeStatus.retired => context.messages.goalNudgeStatusRetired,
      GoalNudgeStatus.expired => context.messages.goalNudgeStatusExpired,
      GoalNudgeStatus.superseded => context.messages.goalNudgeStatusSuperseded,
      GoalNudgeStatus.draft ||
      GoalNudgeStatus.ready ||
      GoalNudgeStatus.active ||
      GoalNudgeStatus.failed => '',
    };
