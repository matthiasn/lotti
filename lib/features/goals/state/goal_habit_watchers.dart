import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

/// One active goal that watches a habit: the goal's identity, the spec
/// version currently in force, and the id of the criterion inside that spec
/// which names the habit — the key its per-dimension verdicts are filed
/// under.
typedef GoalHabitWatcher = ({
  AgentIdentityEntity identity,
  GoalSpecVersionEntity spec,
  String criterionId,
});

/// The criterion id under which [habitId] appears in [criterion]'s tree, or
/// null when the tree does not reference it. A habit appears at most once per
/// goal; the first match is the match.
String? goalCriterionIdForHabit(GoalCriterion criterion, String habitId) =>
    switch (criterion) {
      GoalCriterionHabit(habitId: final id, :final criterionId) =>
        id == habitId ? criterionId : null,
      GoalCriterionAllOf(:final criteria) ||
      GoalCriterionAnyOf(:final criteria) ||
      GoalCriterionAtLeastCount(:final criteria) => () {
        for (final child in criteria) {
          final found = goalCriterionIdForHabit(child, habitId);
          if (found != null) return found;
        }
        return null;
      }(),
      GoalCriterionMetric() ||
      GoalCriterionMeasurable() ||
      GoalCriterionCategoryTime() ||
      GoalCriterionLabelTime() => null,
    };

/// The active goals whose current spec names the habit.
///
/// The reverse of `goalCriterionHabitIds`: the habit surfaces need to know
/// which goals judge a habit's days so they can show those judgements and
/// open the goal's reflection from the habit's own sheet. Goals without a
/// live spec (partial sync, dangling head) are skipped, exactly as the goal
/// list withholds their health.
final FutureProviderFamily<List<GoalHabitWatcher>, String>
goalsWatchingHabitProvider = FutureProvider.autoDispose
    .family<List<GoalHabitWatcher>, String>((ref, habitId) async {
      final identities = await ref.watch(activeGoalAgentsProvider.future);
      final watchers = <GoalHabitWatcher>[];
      for (final identity in identities) {
        final health = await ref.watch(
          goalAgentHealthProvider(identity.agentId).future,
        );
        final spec = health.spec;
        if (spec == null) continue;
        final criterionId = goalCriterionIdForHabit(spec.criteria, habitId);
        if (criterionId == null) continue;
        watchers.add((
          identity: identity,
          spec: spec,
          criterionId: criterionId,
        ));
      }
      return watchers;
    }, name: 'goalsWatchingHabitProvider');

/// The verdict standing for each of the habit's days across every goal that
/// watches it, keyed by UTC day.
///
/// A habit shared by two goals can be judged twice for one day. The most
/// recently recorded judgement wins — the same rule `latestAssessmentsByDay`
/// applies to one goal's own revisions — so the habit's squares show the user's latest word on
/// that day rather than one goal's older one.
final FutureProviderFamily<Map<DateTime, DayVerdict>, String>
habitDayVerdictsProvider = FutureProvider.autoDispose
    .family<Map<DateTime, DayVerdict>, String>((ref, habitId) async {
      final watchers = await ref.watch(
        goalsWatchingHabitProvider(habitId).future,
      );
      final latest = <DateTime, GoalAssessmentRecord>{};
      final verdicts = <DateTime, DayVerdict>{};
      for (final watcher in watchers) {
        final records = await ref.watch(
          goalAssessmentHistoryProvider(watcher.identity.agentId).future,
        );
        final byDay = latestAssessmentsByDay(
          records,
          specVersionId: watcher.spec.id,
        );
        for (final entry in byDay.entries) {
          final verdict = entry.value.dimensionRatings[watcher.criterionId];
          if (verdict == null) continue;
          final held = latest[entry.key];
          // The same tie-break `latestAssessmentsByDay` applies within one
          // goal: equal timestamps fall back to the higher record id, so two
          // devices iterating the goals in different orders agree.
          final record = entry.value;
          final wins =
              held == null ||
              record.createdAt.isAfter(held.createdAt) ||
              (record.createdAt == held.createdAt &&
                  record.id.compareTo(held.id) > 0);
          if (!wins) continue;
          latest[entry.key] = entry.value;
          verdicts[entry.key] = verdict;
        }
      }
      return verdicts;
    }, name: 'habitDayVerdictsProvider');
