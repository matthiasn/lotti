import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// One goal on the unified Goals list (design handover "Goals, Unified"
/// §4.2): header (persona chip · name · status pill with folded recovery
/// hint · trend chip · 7-day strip), a deterministic templated summary line,
/// then the goal's habit rows — **expanded by default**, because grouping
/// never means hiding the one-tap complete (§P3). A card whose rows are all
/// filtered out collapses to its header.
///
/// The card watches the same per-agent providers the agents list row does;
/// habits-side state ([successToday], [streaksByHabit]) is supplied by the
/// page so every card shares one read of the habits controller.
class UnifiedGoalCard extends ConsumerWidget {
  const UnifiedGoalCard({
    required this.identity,
    required this.successToday,
    required this.streaksByHabit,
    this.visibleHabitIds,
    super.key,
  });

  final AgentIdentityEntity identity;

  /// Habit ids with a REAL success recorded today (success-only — skips
  /// excluded). Goal criteria credit only `HabitCompletionType.success`, so a
  /// skipped habit keeps its one-tap success button here instead of reading
  /// green while the window reading still reports a deficit.
  final Set<String> successToday;

  /// Per-habit current streaks (the heatmap controller's deep history).
  final Map<String, int> streaksByHabit;

  /// Habit ids the page's due/later/done filter currently shows, or null for
  /// the unfiltered `all` view. Rows outside the set are omitted; the goal
  /// header always renders so the goal itself never vanishes under a filter.
  final Set<String>? visibleHabitIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final healthAsync = ref.watch(goalAgentHealthProvider(identity.agentId));
    // Stale-while-revalidate mirror of the agents list row: only a RESOLVED
    // health carries a verdict; while loading the card shows no pill rather
    // than a false "No data".
    final health = healthAsync.value;
    final progressAsync = health?.spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(identity.agentId));
    final progress = progressAsync?.value;
    // A spec claims this goal's habits for the page's grouping even while
    // the progress projection is unavailable — so a FAILED first progress
    // read must not make every linked habit vanish (not here, not in the
    // orphan group). Fall back to plain action rows built from the spec's
    // own criteria tree: no window readings, but the daily loop survives.
    final progressFailedFirstLoad =
        progressAsync != null && progress == null && progressAsync.hasError;
    final status = healthAsync.hasValue
        ? unifiedGoalStatusOf(health?.trackStatus)
        : null;
    final hasStanding = health?.reportOneLiner?.trim().isNotEmpty ?? false;
    // The coarse-health chip's documented display rule, carried over: a
    // "No data" pill must not sit beside a standing assessment that plainly
    // contains data-driven judgement.
    final showPill =
        status != null && !(status == UnifiedGoalStatus.noData && hasStanding);
    final recoveryHint = switch (health?.deficit) {
      final int deficit when deficit > 0 => messages.goalDaysToRecover(deficit),
      _ => null,
    };
    final summary = status == null
        ? null
        : unifiedGoalSummary(
            messages,
            status: status,
            progress: progress,
            oneLiner: health?.reportOneLiner,
          );
    final color = status == null
        ? tokens.colors.text.lowEmphasis
        : unifiedGoalStatusColor(status, tokens.colors);

    // Same placeholder contract as the agents list: an unresolved strip
    // reserves its footprint with dashed cells, never the filled grey of a
    // genuinely-empty week.
    final resolvedDays = switch (progress?.compactWindow) {
      final days? when days.isNotEmpty => days,
      _ => null,
    };
    final days =
        resolvedDays ??
        List<GoalCompactDayState>.filled(7, GoalCompactDayState.none);
    final ratingsByDay = health?.spec == null
        ? const <DateTime, GoalAssessmentRating>{}
        : latestRatingsByDay(
            ref.watch(goalAssessmentHistoryProvider(identity.agentId)).value ??
                const [],
            specVersionId: health!.spec!.id,
          );

    final fallbackHabitIds = progressFailedFirstLoad
        ? goalCriterionHabitIds(health!.spec!.criteria)
        : const <String>{};
    final habitRows = [
      for (final habit in progress?.habits ?? const <GoalHabitProgressView>[])
        if (visibleHabitIds?.contains(habit.habitId) ?? true)
          HabitActionRow(
            // Criterion id included: a composite tree may reference the
            // same habit in several leaves (different windows/targets), and
            // each leaf keeps its own row.
            key: Key(
              'unified-goal-${identity.agentId}'
              '-${habit.criterionId}-${habit.habitId}',
            ),
            habitId: habit.habitId,
            completedToday: successToday.contains(habit.habitId),
            currentStreak: streaksByHabit[habit.habitId] ?? 0,
            history: _HabitWindowReading(habit: habit),
          ),
      for (final habitId in fallbackHabitIds)
        if (visibleHabitIds?.contains(habitId) ?? true)
          HabitActionRow(
            key: Key('unified-goal-${identity.agentId}-fallback-$habitId'),
            habitId: habitId,
            completedToday: successToday.contains(habitId),
            currentStreak: streaksByHabit[habitId] ?? 0,
          ),
    ];

    final header = InkWell(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      onTap: () => beamToNamed('/goals/details/${identity.agentId}'),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kActionListContentMaxWidth;
            final identityBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      health?.spec?.title ?? identity.displayName,
                      style: tokens.typography.styles.subtitle.subtitle1
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                    if (showPill)
                      UnifiedGoalStatusPill(
                        status: status,
                        recoveryHint: recoveryHint,
                      ),
                    if (health?.direction case final direction?)
                      GoalHealthDirectionChip(direction: direction),
                  ],
                ),
                if (summary != null) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            );
            final strip = GoalCompactWindowStrip(
              days: days,
              placeholder: resolvedDays == null,
              lastDay: progress?.today,
              ratingsByDay: ratingsByDay,
            );
            final leading = GoalBannerPersonaChip(
              monogram: GoalBannerPersonaChip.monogramFor(
                identity.displayName,
              ),
              fill: color.withValues(alpha: SurfaceAlphas.washChip),
            );
            if (wide) {
              return Row(
                children: [
                  leading,
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(child: identityBlock),
                  SizedBox(width: tokens.spacing.step4),
                  strip,
                ],
              );
            }
            return Row(
              children: [
                leading,
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identityBlock,
                      SizedBox(height: tokens.spacing.step2),
                      strip,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    return Material(
      color: tokens.colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (habitRows.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.cardPadding,
                0,
                tokens.spacing.cardPadding,
                tokens.spacing.step2,
              ),
              child: Column(children: habitRows),
            ),
        ],
      ),
    );
  }
}

/// The unified habit row's window reading, rendered in the row's `history`
/// slot: the deterministic "N of M this window" fraction plus the amber
/// off-track word when the habit is behind. Per-habit day strips stay a
/// detail-page privilege (§P5 — one glance element per row beyond the streak
/// chain the row already carries).
class _HabitWindowReading extends StatelessWidget {
  const _HabitWindowReading({required this.habit});

  final GoalHabitProgressView habit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Wrap(
      spacing: tokens.spacing.step3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          messages.goalDimensionHabitReading(
            habit.successesInWindow,
            habit.targetCount,
          ),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (habit.deficit > 0)
          Text(
            messages.goalDimensionNeedsAttentionStatus,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.alert.warning.ink,
            ),
          ),
      ],
    );
  }
}
