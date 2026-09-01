import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_card.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The unified Goals tab (flag: `enable_unified_goals`; design handover
/// "Goals, Unified" §4.2): one calm centered column in the Habits page's
/// visual language — the Done-today summary card, one expanded
/// [UnifiedGoalCard] per goal, the "not in a goal" habit group, then the
/// aggregate Consistency heatmap and Completion-rate chart.
///
/// The habits controller and heatmap controller are read once here and their
/// state fanned out to every card, so the daily loop (page-open → + →
/// Record) costs exactly what it costs on the Habits tab. The due/later/done
/// filter tabs act on habit ROWS globally; a goal whose rows all filter out
/// collapses to its header — pills always reflect full state, filters never
/// change a verdict.
class UnifiedGoalsPage extends ConsumerStatefulWidget {
  const UnifiedGoalsPage({super.key});

  @override
  ConsumerState<UnifiedGoalsPage> createState() => _UnifiedGoalsPageState();
}

class _UnifiedGoalsPageState extends ConsumerState<UnifiedGoalsPage>
    with GoalHealthRefreshOnEntry {
  final _scrollController = ScrollController();

  /// Fires just past local midnight so the lifecycle-gated sets
  /// (recordable ids, orphan rows, the scoped summary) recompute the moment
  /// a habit's activeFrom/activeUntil boundary passes — a page parked
  /// overnight must not keep offering rows the recording path would reject
  /// the next day. Rescheduled after each fire.
  Timer? _midnightTimer;

  @override
  void initState() {
    _scrollController.addListener(getIt<UserActivityService>().updateActivity);
    super.initState();
    _scheduleMidnightRebuild();
  }

  void _scheduleMidnightRebuild() {
    final now = ref.read(habitsNowProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(
      // A second past the boundary so day-granular comparisons land firmly
      // on the new date.
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        // The controller's buckets are time-derived too (`showFrom` moves a
        // habit between Due and Later at the boundary) — a bare rebuild
        // would re-gate against yesterday's split. The heatmap projection
        // has no clock of its own either: without this it keeps yesterday's
        // range cap, today-cell and streak baselines until a data event.
        // Both refreshes preserve their established state — never an
        // invalidate, which would flash the grid empty (no-flash rule).
        unawaited(ref.read(habitsControllerProvider.notifier).refreshNow());
        unawaited(
          ref.read(habitHeatmapControllerProvider.notifier).refreshNow(),
        );
        setState(() {});
        _scheduleMidnightRebuild();
      },
    );
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);
    final streaks = ref.watch(habitHeatmapControllerProvider).streaksByHabit;
    final agents = ref.watch(activeGoalAgentsProvider);
    final archivedAgents = ref.watch(dormantGoalAgentsProvider);
    // Stale-while-revalidate: background wakes reload the provider
    // constantly; an established list must never flash away. Before the
    // first value the goal section renders nothing — unless that first load
    // FAILED, which must say so instead of silently hiding every goal and
    // ungrouped habit (the agents list's own rule).
    // A goal's category is its identity's allowed-category set (see
    // `goal_timeline_page.dart`); lockdown hides goals outside the locked
    // set. Filtered here rather than in the agent providers, which the
    // runtime watchers share and which must keep every goal alive.
    final lockdown = ref.watch(lockdownControllerProvider);
    bool visibleUnderLockdown(AgentIdentityEntity identity) =>
        !lockdown.isActive || identity.allowedCategoryIds.any(lockdown.allows);
    final identities = (agents.value ?? const <AgentIdentityEntity>[])
        .where(visibleUnderLockdown)
        .toList(growable: false);
    final failedFirstLoad = agents.value == null && agents.hasError;
    final archivedIdentities =
        (archivedAgents.value ?? const <AgentIdentityEntity>[])
            .where(visibleUnderLockdown)
            .toList(growable: false);

    // A quick-complete on any row writes through the shared habit
    // persistence path; the habits controller refetches on the completion
    // notification, but the mounted per-goal progress projections would keep
    // serving their cached pre-completion read. Invalidate them whenever the
    // controller's completion data changes, so "N of M this window", the
    // attention words and the templated summaries recompute deterministically
    // in the same beat as the row's done flip. (The PILL deliberately stays
    // on the evaluator's persisted register until the agent runtime ticks.)
    ref.listen(habitsControllerProvider, (previous, next) {
      if (identical(previous?.habitCompletions, next.habitCompletions)) {
        return;
      }
      for (final identity in identities) {
        ref
          ..invalidate(goalAgentProgressViewProvider(identity.agentId))
          ..invalidate(goalAgentProgressViewForSpanProvider);
      }
    });

    // The due/later/done tabs select habit ROWS; `all` shows every habit
    // that is recordable TODAY. Deliberately the category-UNFILTERED
    // buckets: this page exposes no category-filter control, so it must not
    // silently inherit a selection made on the Habits tab. Every branch
    // additionally intersects with the goal recording path's own lifecycle
    // gate (`GoalHabitCompletionService.isRecordableDay` — active flag AND
    // the activeFrom/activeUntil window): a goal's criteria tree can
    // reference a habit that was deactivated or has aged out of its window,
    // and such a row must not render an actionable quick-complete that the
    // service itself would reject.
    // Lockdown is the one category scope this page does honour: a habit
    // outside the locked category is not recordable here, which keeps it out
    // of the orphan group and out of every goal card's rows alike.
    final gatingNow = ref.watch(habitsNowProvider)();
    final recordableIds = {
      for (final habit in state.habitDefinitions)
        if (lockdown.allows(habit.categoryId) &&
            GoalHabitCompletionService.isRecordableDay(
              habit,
              day: gatingNow,
              now: gatingNow,
            ))
          habit.id,
    };
    // Goal-card rows count only real successes as done: goal criteria credit
    // `HabitCompletionType.success` alone, while `successfulToday` also
    // contains skips (the Habits tab's broader "handled today"). A skipped
    // habit must keep its one-tap success button on a goal card, or the card
    // reads green while the goal's window reading still reports a deficit.
    final todayYmd = gatingNow.ymd;
    final successToday = state.successfulByDay[todayYmd] ?? const <String>{};

    // Which habits any goal claims, from the resolved specs' criteria trees.
    // Orphan membership must not flicker while per-goal health is still on
    // its FIRST load, so the group renders only once every health has a
    // value (stale values from a background refresh are fine).
    final healths = [
      for (final identity in identities)
        ref.watch(goalAgentHealthProvider(identity.agentId)),
    ];
    // `agents.hasValue` guards the first load: with no identities resolved
    // yet, `every` on the empty healths list is vacuously true and cached
    // habit state would flash into "not in a goal" before jumping back. A
    // health whose FIRST load errored counts as settled (claiming nothing):
    // its card renders header-only, and one failing goal must not black out
    // the whole ungrouped section indefinitely.
    final healthsResolved =
        agents.hasValue &&
        healths.every((health) => health.hasValue || health.hasError);
    final claimedHabitIds = <String>{
      for (final health in healths)
        if (health.value?.spec?.criteria case final criteria?)
          ...goalCriterionHabitIds(criteria),
    };
    // Opening Goals pulls every goal's health signals forward — nothing else
    // on this page imports, so the cards would otherwise be as stale as the
    // last time something else happened to fetch.
    refreshHealthSignals([
      for (final health in healths) ?health.value?.spec?.criteria,
    ]);

    // The summary's done set mirrors each group's OWN semantics: goal-owned
    // habits count success-only (their rows stay due after a skip or fail),
    // while ungrouped habits count the FULL legacy handled set —
    // `completedToday`, which includes skips AND fails, exactly the records
    // that file an orphan row under Done — otherwise a skipped or failed
    // orphan reads "1 to go" above a row that already shows as handled.
    final summaryDoneIds = {
      ...successToday,
      for (final id in state.completedToday)
        if (!claimedHabitIds.contains(id)) id,
    };

    final orphanSource = switch (state.displayFilter) {
      HabitDisplayFilter.openNow => state.openNowAll,
      HabitDisplayFilter.pendingLater => state.pendingLaterAll,
      HabitDisplayFilter.completed => state.completedAll,
      HabitDisplayFilter.all => [
        ...state.openNowAll,
        ...state.pendingLaterAll,
        ...state.completedAll,
      ],
    };
    // Same lifecycle gate as the goal-owned rows: an orphan row's
    // quick-complete must not offer what the recording path would reject.
    final orphanHabits = healthsResolved
        ? orphanSource
              .where(
                (habit) =>
                    recordableIds.contains(habit.id) &&
                    !claimedHabitIds.contains(habit.id),
              )
              .toList()
        : const <HabitDefinition>[];

    HabitActionRow buildOrphanRow(HabitDefinition habitDefinition) {
      return HabitActionRow(
        key: Key('unified-orphan-${habitDefinition.id}'),
        habitId: habitDefinition.id,
        // Orphan rows keep the Habits tab's semantics (skip counts as
        // handled) — they ARE the old habits list, just grouped.
        completedToday: state.successfulToday.contains(habitDefinition.id),
        autoCompleted: state.autoCompletedToday.containsKey(habitDefinition.id),
        autoCompleteReason: state.autoCompletedToday[habitDefinition.id],
        autoCompletedAt: state.autoCompletedAt(habitDefinition.id),
        currentStreak: streaks[habitDefinition.id] ?? 0,
        history: habitHistoryMarks(
          state,
          habitDefinition.id,
          count: habitHistoryDays(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: DesignSystemFloatingActionButton(
          semanticLabel: messages.agentsCreateGoal,
          onPressed: () => beamToNamed(goalCreatePath),
        ),
      ),
      body: SafeArea(
        // Centered against the ACTUAL pane, not the window: in desktop layout
        // this page renders beside the navigation sidebar, and window-width
        // arithmetic would subtract the sidebar twice (the agents-page idiom).
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kUnifiedGoalsContentMaxWidth + tokens.spacing.step6 * 2,
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step6,
                    tokens.spacing.step5,
                    tokens.spacing.step6,
                    tokens.spacing.step6 +
                        DesignSystemBottomNavigationBar.occupiedHeight(
                          context,
                        ) +
                        tokens.spacing.step12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _GoalsHeader(
                        filter: state.displayFilter,
                        onFilterChanged: ref
                            .read(habitsControllerProvider.notifier)
                            .setDisplayFilter,
                      ),
                      SizedBox(height: tokens.spacing.sectionGap),
                      HabitsSummaryCard(
                        visibleHabitIds: recordableIds,
                        doneHabitIds: summaryDoneIds,
                        // Scoped to the recordable set, from the SAME
                        // per-habit streaks the visible row chains render —
                        // a hidden out-of-window habit's streak must not be
                        // advertised here.
                        streakCounts: (
                          short: recordableIds
                              .where((id) => (streaks[id] ?? 0) >= 3)
                              .length,
                          long: recordableIds
                              .where((id) => (streaks[id] ?? 0) >= 7)
                              .length,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step5),
                      if (failedFirstLoad)
                        Padding(
                          padding: EdgeInsets.only(
                            top: tokens.spacing.sectionGap,
                          ),
                          child: Text(
                            messages.agentsPageLoadFailed,
                            textAlign: TextAlign.center,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ),
                      // The page's own first run gets the same designed
                      // invitation its sub-states already have: a blank
                      // stretch of chrome with an unexplained FAB is not an
                      // empty state. Gated on a RESOLVED first load — the
                      // no-flash rule: while loading, render nothing here.
                      if (agents.hasValue &&
                          identities.isEmpty &&
                          archivedIdentities.isEmpty &&
                          !failedFirstLoad)
                        const _NoGoalsYet(),
                      for (final identity in identities) ...[
                        UnifiedGoalCard(
                          key: Key('unified-goal-card-${identity.agentId}'),
                          identity: identity,
                        ),
                        SizedBox(height: tokens.spacing.cardItemSpacing),
                      ],
                      if (archivedIdentities.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.step3),
                        _ArchivedGoalsSection(
                          identities: archivedIdentities,
                        ),
                      ],
                      if (orphanHabits.isNotEmpty) ...[
                        HabitsSectionHeader(
                          label: messages.unifiedGoalsUngroupedHabitsHeader,
                          count: orphanHabits.length,
                        ),
                        ...orphanHabits.map(buildOrphanRow),
                      ],
                      SizedBox(height: tokens.spacing.sectionGap),
                      // Unfiltered: the aggregate heatmap must not inherit
                      // the Habits tab's hidden category selection either.
                      const HabitHeatmapCard(ignoreCategoryFilter: true),
                      SizedBox(height: tokens.spacing.sectionGap),
                      const HabitsChartCard(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An invitation, not an apology (the check-in rail's own empty-state
/// pattern): says what a goal is for and offers the one action that starts
/// one, so the page's first run is as designed as its mid-life.
class _NoGoalsYet extends StatelessWidget {
  const _NoGoalsYet();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.sectionGap),
      child: Column(
        children: [
          Icon(
            LottiIcons.flag,
            size: IconSizes.l,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.unifiedGoalsEmptyInvitation,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemButton(
            key: const ValueKey('unified-goals-empty-cta'),
            label: context.messages.agentsCreateGoal,
            leadingIcon: LottiIcons.add,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () => beamToNamed(goalCreatePath),
          ),
        ],
      ),
    );
  }
}

class _ArchivedGoalsSection extends StatelessWidget {
  const _ArchivedGoalsSection({required this.identities});

  final List<AgentIdentityEntity> identities;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.l),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('unified-goals-archive'),
        title: Text(
          context.messages.unifiedGoalsArchivedTitle(identities.length),
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          tokens.spacing.cardPadding,
          0,
          tokens.spacing.cardPadding,
          tokens.spacing.cardPadding,
        ),
        children: [
          for (final identity in identities) ...[
            UnifiedGoalCard(
              key: Key('unified-archived-goal-card-${identity.agentId}'),
              identity: identity,
            ),
            if (identity != identities.last)
              SizedBox(height: tokens.spacing.cardItemSpacing),
          ],
        ],
      ),
    );
  }
}

/// Page header: the Goals title plus the reused due/later/done/all filter
/// tabs. Folds to two lines on narrow widths, the Habits header's breakpoint.
class _GoalsHeader extends StatelessWidget {
  const _GoalsHeader({required this.filter, required this.onFilterChanged});

  final HabitDisplayFilter filter;
  final ValueChanged<HabitDisplayFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final title = Text(
      context.messages.navTabTitleGoals,
      style: calmPageTitleStyle(tokens),
    );
    final tabs = HabitStatusSegmentedControl(
      filter: filter,
      onValueChanged: onFilterChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kPageHeaderFoldWidth) {
          return Row(
            children: [
              title,
              const Spacer(),
              tabs,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            SizedBox(height: tokens.spacing.step3),
            // Horizontally scrollable, the habits header's own narrow-width
            // treatment: longer localized labels or large text scales must
            // pan instead of overflowing the column.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tabs,
            ),
          ],
        );
      },
    );
  }
}
