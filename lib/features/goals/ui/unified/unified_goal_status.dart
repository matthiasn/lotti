import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The unified Goals surface's four-pill status vocabulary (design handover
/// "Goals, Unified" §Q2): the ONLY health words a goal card ever shows.
///
/// Differs deliberately from `GoalCoarseHealth`: `recovering` reads as
/// **atRisk** here rather than "Restarting" — the pill's folded recovery hint
/// ("2 more by Thursday brings this back") carries the fresh-start framing
/// instead of a dedicated label, keeping the vocabulary at four.
enum UnifiedGoalStatus { onTrack, atRisk, behind, noData }

/// Collapses the runtime [GoalTrackStatus] (null = no register yet) into the
/// unified four-pill vocabulary.
UnifiedGoalStatus unifiedGoalStatusOf(GoalTrackStatus? status) =>
    switch (status) {
      GoalTrackStatus.onTrack ||
      GoalTrackStatus.achieved => UnifiedGoalStatus.onTrack,
      GoalTrackStatus.atRisk ||
      GoalTrackStatus.recovering => UnifiedGoalStatus.atRisk,
      GoalTrackStatus.offTrack => UnifiedGoalStatus.behind,
      GoalTrackStatus.insufficientData || null => UnifiedGoalStatus.noData,
    };

String unifiedGoalStatusLabel(
  AppLocalizations messages,
  UnifiedGoalStatus status,
) => switch (status) {
  UnifiedGoalStatus.onTrack => messages.goalDimensionOnTrackStatus,
  UnifiedGoalStatus.atRisk => messages.unifiedGoalStatusAtRisk,
  UnifiedGoalStatus.behind => messages.goalCoarseHealthBehind,
  UnifiedGoalStatus.noData => messages.unifiedGoalStatusNoData,
};

/// The pill's hue per status. Behind and At risk share the warning hue — the
/// fill strength separates them (solid vs wash), never a red: the surface
/// stays calm and every negative state carries a recovery door instead.
Color unifiedGoalStatusColor(UnifiedGoalStatus status, DsColors colors) =>
    switch (status) {
      UnifiedGoalStatus.onTrack => colors.alert.success.defaultColor,
      UnifiedGoalStatus.atRisk ||
      UnifiedGoalStatus.behind => colors.alert.warning.defaultColor,
      UnifiedGoalStatus.noData => colors.text.lowEmphasis,
    };

/// Every habit id referenced anywhere in [criterion]'s tree — the join used
/// to decide which habits a goal claims (and, by complement, which habits are
/// "not in a goal" on the unified list).
Set<String> goalCriterionHabitIds(GoalCriterion criterion) =>
    switch (criterion) {
      GoalCriterionHabit(:final habitId) => {habitId},
      GoalCriterionAllOf(:final criteria) ||
      GoalCriterionAnyOf(:final criteria) ||
      GoalCriterionAtLeastCount(:final criteria) => {
        for (final child in criteria) ...goalCriterionHabitIds(child),
      },
      GoalCriterionMetric() ||
      GoalCriterionMeasurable() ||
      GoalCriterionCategoryTime() => const {},
    };

/// The goal card's one-line summary — TEMPLATED from live deterministic state,
/// never generated prose, so it can never be stale (design handover §4.8).
///
/// Habit goals summarise their on-track fraction. Goals without habit
/// dimensions (signal-only goals like Steps) fall back to the agent's
/// standing [oneLiner] — except in the no-data state, where the summary is
/// the setup nudge unless a standing one-liner already describes the goal
/// (the same "never contradict a standing assessment" display rule the
/// coarse-health chip follows). Null means: render no summary line.
String? unifiedGoalSummary(
  AppLocalizations messages, {
  required UnifiedGoalStatus status,
  required GoalProgressView? progress,
  String? oneLiner,
}) {
  final standing = (oneLiner?.trim().isNotEmpty ?? false) ? oneLiner : null;
  if (status == UnifiedGoalStatus.noData) {
    return standing ?? messages.unifiedGoalSummaryNoData;
  }
  final habits = progress?.habits ?? const <GoalHabitProgressView>[];
  if (habits.isEmpty) return standing;
  final onTrackCount = habits.where((habit) => habit.deficit == 0).length;
  if (onTrackCount == habits.length) {
    return messages.unifiedGoalSummaryAllOnTrack(habits.length);
  }
  return messages.unifiedGoalSummaryPartial(onTrackCount, habits.length);
}

/// The unified status pill. Behind is the only solid fill (warning hue,
/// [DsColorsText.onInteractiveAlert] label — the strongest signal on the
/// card); At risk / On track are washes; No data is a neutral wash. An
/// off-track pill folds its recovery hint into the label ("Behind · 1 day to
/// recover") so the door is part of the state, not garnish.
class UnifiedGoalStatusPill extends StatelessWidget {
  const UnifiedGoalStatusPill({
    required this.status,
    this.recoveryHint,
    super.key,
  });

  final UnifiedGoalStatus status;

  /// Deterministic recovery copy folded into the label after a separator.
  /// Rendered only for the off-track states — a hint on an on-track pill
  /// would blow the glance budget for no decision value.
  final String? recoveryHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = unifiedGoalStatusColor(status, tokens.colors);
    final solid = status == UnifiedGoalStatus.behind;
    final hint =
        recoveryHint != null &&
            (status == UnifiedGoalStatus.behind ||
                status == UnifiedGoalStatus.atRisk)
        ? recoveryHint
        : null;
    final label = [
      unifiedGoalStatusLabel(context.messages, status),
      ?hint,
    ].join(' · ');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Solid fill takes the on-alert ink; washes keep high-emphasis text so
        // the 12px caption clears the 4.5:1 floor over a wash of its own hue
        // (the coarse-health chip's documented contrast rule).
        style: tokens.typography.styles.others.caption.copyWith(
          color: solid
              ? tokens.colors.text.onInteractiveAlert
              : tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}
