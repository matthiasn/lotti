import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The unified Goals surface's four-pill status vocabulary (design handover
/// "Goals, Unified" §Q2): the ONLY health words a goal card ever shows.
///
/// `recovering` reads as **atRisk** — the pill's folded recovery hint
/// ("2 more by Thursday brings this back") carries the fresh-start framing
/// instead of a dedicated label, keeping the vocabulary at four. This is the
/// ONE health dialect every goal surface speaks: list rows, the detail
/// header and the chat header all render these words, in these hues, so the
/// app can never disagree with itself about the same goal in one viewport.
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

/// The status a surface should show, or null when it must show none.
///
/// "No data" is a statement about the agent's ability to judge. Once it HAS
/// judged — once a standing report on the same screen says what is above and
/// below target — the label contradicts the very thing it sits beside, and
/// the reader has to decide which of the two to believe. Coverage can still
/// be genuinely thin, and the report says so in its own coverage sentence;
/// that is a caveat inside an assessment, which is honest — a headline
/// replacing the assessment is not.
UnifiedGoalStatus? unifiedGoalStatusChip(
  GoalTrackStatus? status, {
  required bool hasStandingAssessment,
}) {
  final unified = unifiedGoalStatusOf(status);
  if (unified == UnifiedGoalStatus.noData && hasStandingAssessment) {
    return null;
  }
  return unified;
}

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

/// The goal card's one-line summary — TEMPLATED from live deterministic state,
/// never generated prose, so it can never be stale (design handover §4.8).
///
/// Habit-ONLY goals summarise their on-track fraction. Goals with any
/// non-habit dimension — signal-only goals like Steps, and mixed composites
/// — fall back to the agent's standing [oneLiner]: a habit fraction beside
/// a pill that also weighs a metric could contradict it ("Behind" next to
/// "all habits on track"). In the no-data state the summary is the setup
/// nudge unless a standing one-liner already describes the goal (the same
/// "never contradict a standing assessment" display rule
/// [unifiedGoalStatusChip] follows). Null means: render no summary line.
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
  final metrics = progress?.metrics ?? const <GoalMetricProgressView>[];
  if (habits.isEmpty || metrics.isNotEmpty) return standing;
  final onTrackCount = habits.where((habit) => habit.deficit == 0).length;
  // The "nothing needed today" all-clear only beside an on-track pill: right
  // after a quick-complete the live projection can reach full count while
  // the pill still carries the evaluator's persisted Behind register — until
  // the runtime ticks, the factual fraction ("2 of 2 habits on track")
  // must not escalate to an all-clear the pill contradicts.
  if (onTrackCount == habits.length && status == UnifiedGoalStatus.onTrack) {
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
        // Informative, not tappable: the small-chip radius, never the pill —
        // full rounding is reserved for clickable elements on goal surfaces.
        borderRadius: BorderRadius.circular(tokens.radii.smallChips),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Solid fill takes the on-alert ink; washes keep high-emphasis text so
        // the 12px caption clears the 4.5:1 floor over a wash of its own hue
        // (the pill's documented contrast rule).
        style: tokens.typography.styles.others.caption.copyWith(
          color: solid
              ? tokens.colors.text.onInteractiveAlert
              : tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}
