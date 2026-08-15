import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_card.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
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

class _UnifiedGoalsPageState extends ConsumerState<UnifiedGoalsPage> {
  final _scrollController = ScrollController();

  /// The handover's confirmed reading measure for this surface: narrower than
  /// the Habits page's 1100 so goal cards read as one comfortable column.
  static const _maxContentWidth = 700.0;

  @override
  void initState() {
    _scrollController.addListener(getIt<UserActivityService>().updateActivity);
    super.initState();
  }

  @override
  void dispose() {
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
    // Stale-while-revalidate: background wakes reload the provider
    // constantly; an established list must never flash away. Before the
    // first value the goal section simply renders nothing.
    final identities = agents.value ?? const [];

    // The due/later/done tabs select habit ROWS; `all` shows everything.
    final visibleHabitIds = switch (state.displayFilter) {
      HabitDisplayFilter.openNow => {for (final h in state.openNow) h.id},
      HabitDisplayFilter.pendingLater => {
        for (final h in state.pendingLater) h.id,
      },
      HabitDisplayFilter.completed => {for (final h in state.completed) h.id},
      HabitDisplayFilter.all => null,
    };

    // Which habits any goal claims, from the resolved specs' criteria trees.
    // Orphan membership must not flicker while per-goal health is still on
    // its FIRST load, so the group renders only once every health has a
    // value (stale values from a background refresh are fine).
    final healths = [
      for (final identity in identities)
        ref.watch(goalAgentHealthProvider(identity.agentId)),
    ];
    final healthsResolved = healths.every((health) => health.hasValue);
    final claimedHabitIds = <String>{
      for (final health in healths)
        if (health.value?.spec?.criteria case final criteria?)
          ...goalCriterionHabitIds(criteria),
    };

    final orphanSource = switch (state.displayFilter) {
      HabitDisplayFilter.openNow => state.openNow,
      HabitDisplayFilter.pendingLater => state.pendingLater,
      HabitDisplayFilter.completed => state.completed,
      HabitDisplayFilter.all => [
        ...state.openNow,
        ...state.pendingLater,
        ...state.completed,
      ],
    };
    final orphanHabits = healthsResolved
        ? orphanSource
              .where((habit) => !claimedHabitIds.contains(habit.id))
              .toList()
        : const <HabitDefinition>[];

    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width > _maxContentWidth + tokens.spacing.step6 * 2
        ? (width - _maxContentWidth) / 2
        : tokens.spacing.step6;

    HabitActionRow buildOrphanRow(HabitDefinition habitDefinition) {
      return HabitActionRow(
        key: Key('unified-orphan-${habitDefinition.id}'),
        habitId: habitDefinition.id,
        completedToday: state.successfulToday.contains(habitDefinition.id),
        currentStreak: streaks[habitDefinition.id] ?? 0,
      );
    }

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: DesignSystemFloatingActionButton(
          semanticLabel: messages.agentsCreateGoal,
          onPressed: () => beamToNamed('/agents/create'),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                tokens.spacing.step5,
                pagePadding,
                tokens.spacing.step6 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
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
                  const HabitsSummaryCard(),
                  SizedBox(height: tokens.spacing.step5),
                  for (final identity in identities) ...[
                    UnifiedGoalCard(
                      key: Key('unified-goal-card-${identity.agentId}'),
                      identity: identity,
                      successfulToday: state.successfulToday,
                      streaksByHabit: streaks,
                      visibleHabitIds: visibleHabitIds,
                    ),
                    SizedBox(height: tokens.spacing.cardItemSpacing),
                  ],
                  if (orphanHabits.isNotEmpty) ...[
                    HabitsSectionHeader(
                      label: messages.unifiedGoalsUngroupedHabitsHeader,
                      count: orphanHabits.length,
                    ),
                    ...orphanHabits.map(buildOrphanRow),
                  ],
                  SizedBox(height: tokens.spacing.sectionGap),
                  const HabitHeatmapCard(),
                  SizedBox(height: tokens.spacing.sectionGap),
                  const HabitsChartCard(),
                ]),
              ),
            ),
          ],
        ),
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
        if (constraints.maxWidth >= 520) {
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
            tabs,
          ],
        );
      },
    );
  }
}
