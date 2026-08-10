import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_window.dart';

/// The result of applying a `propose_goal_revision` changes payload to a
/// criteria tree: either a revised tree plus a human summary of what
/// changed, or a rejection reason the approval surface can show.
sealed class GoalRevisionResult {
  const GoalRevisionResult();
}

class GoalRevisionApplied extends GoalRevisionResult {
  const GoalRevisionApplied({
    required this.criteria,
    required this.changeSummaries,
  });

  final GoalCriterion criteria;

  /// One line per applied field, e.g. `target: 10000 → 8000`.
  final List<String> changeSummaries;
}

class GoalRevisionRejected extends GoalRevisionResult {
  const GoalRevisionRejected(this.reason);

  final String reason;
}

/// Applies the model-proposed `changes` map (the `propose_goal_revision`
/// tool contract: `metric`, `targetValue`, `period`, `cadence`,
/// `successCriteria`) to [criteria].
///
/// Deliberately conservative — this is the ONLY path that ever rewrites a
/// goal's criteria, and it runs on user approval, so anything ambiguous is
/// rejected with a reason instead of guessed at:
///
/// - `targetValue` / `period` bind to exactly one metric-or-measurable
///   leaf: the only such leaf, or the one whose `criterionId` or dataType
///   matches `metric`. Two candidates and no disambiguator → rejected.
/// - `cadence` binds to exactly one habit leaf and must parse to a
///   positive whole count (`3`, `"3"`, `"3x"`, `"3 times per week"`).
/// - `period` accepts the FACTS vocabulary: `day`, `rolling N days`,
///   `calendar week`, `calendar month` (case-insensitive, tolerant of
///   surrounding words like "window").
/// - `successCriteria` alone never rewrites the tree — free-form intent
///   belongs in a conversation, not a silent structural guess; it is
///   rejected unless another applicable field carries the change.
GoalRevisionResult applyGoalRevisionChanges({
  required GoalCriterion criteria,
  required Map<String, dynamic> changes,
}) {
  final summaries = <String>[];
  var revised = criteria;

  final targetValue = changes['targetValue'];
  final period = changes['period'];
  final cadence = changes['cadence'];

  if (targetValue != null || period != null) {
    final leaf = _resolveQuantitativeLeaf(revised, changes['metric']);
    if (leaf == null) {
      return const GoalRevisionRejected(
        'the proposal does not identify a single measurable criterion — '
        'ask the agent (or the user) to name the criterion to change',
      );
    }
    if (targetValue != null) {
      // Zero is legal (an atMost-0 goal); only negative and non-finite
      // values are outside the creation-time domain.
      if (targetValue is! num || !targetValue.isFinite || targetValue < 0) {
        return GoalRevisionRejected(
          'targetValue must be a non-negative number, got "$targetValue"',
        );
      }
      final before = _leafTarget(leaf);
      revised = _mapLeaf(
        revised,
        leaf.criterionId,
        (c) => switch (c) {
          GoalCriterionMetric() => c.copyWith(target: targetValue),
          GoalCriterionMeasurable() => c.copyWith(target: targetValue),
          _ => c,
        },
      );
      summaries.add('target: $before → $targetValue');
    }
    if (period != null) {
      final window = parseGoalWindowPhrase('$period');
      if (window == null) {
        return GoalRevisionRejected(
          'unrecognized period "$period" — expected day, rolling N days, '
          'calendar week or calendar month',
        );
      }
      revised = _mapLeaf(
        revised,
        leaf.criterionId,
        (c) => switch (c) {
          GoalCriterionMetric() => c.copyWith(window: window),
          GoalCriterionMeasurable() => c.copyWith(window: window),
          _ => c,
        },
      );
      summaries.add('window: $period');
    }
  }

  if (cadence != null) {
    final habits = _habitLeaves(revised);
    if (habits.length != 1) {
      return GoalRevisionRejected(
        habits.isEmpty
            ? 'the goal has no habit criterion for a cadence change'
            : 'the goal has ${habits.length} habit criteria — the proposal '
                  'must identify which one',
      );
    }
    final count = parseGoalCadenceCount(cadence);
    if (count == null) {
      return GoalRevisionRejected(
        'unrecognized cadence "$cadence" — expected a positive count like '
        '"3" or "3 times per week"',
      );
    }
    // The signal reader counts at most ONE success per local day, so a
    // count beyond the window's day capacity mints a goal that can never
    // succeed (the creation form enforces the same bound).
    final capacity = switch (habits.single.window) {
      GoalWindowDay() => 1,
      GoalWindowRollingDays(:final count) => count,
      GoalWindowCalendarWeek() => 7,
      // The guaranteed minimum: a 29+ target would be unsatisfiable
      // every February.
      GoalWindowCalendarMonth() => 28,
    };
    if (count > capacity) {
      return GoalRevisionRejected(
        'cadence $count exceeds the window capacity of $capacity — one '
        'success per day is the most the signals can observe',
      );
    }
    final before = habits.single.targetCount;
    revised = _mapLeaf(
      revised,
      habits.single.criterionId,
      (c) => c is GoalCriterionHabit ? c.copyWith(targetCount: count) : c,
    );
    summaries.add('cadence: $before → $count per window');
  }

  if (summaries.isEmpty) {
    return const GoalRevisionRejected(
      'the proposal carries no applicable structural change '
      '(free-form successCriteria alone cannot rewrite the criteria)',
    );
  }
  if (revised == criteria) {
    // A stale proposal restating the current values must not supersede
    // the spec: an equivalent v(n+1) would still reset the same-version
    // grace history for no actual change.
    return const GoalRevisionRejected(
      'the proposal restates the current criteria — nothing would change',
    );
  }
  return GoalRevisionApplied(criteria: revised, changeSummaries: summaries);
}

/// The single metric/measurable leaf a quantitative change binds to, or
/// null when the binding is ambiguous.
GoalCriterion? _resolveQuantitativeLeaf(GoalCriterion root, Object? metric) {
  final leaves = <GoalCriterion>[];
  void visit(GoalCriterion c) {
    switch (c) {
      case GoalCriterionMetric() || GoalCriterionMeasurable():
        leaves.add(c);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(visit);
      case GoalCriterionHabit():
        break;
    }
  }

  visit(root);
  if (leaves.length == 1) return leaves.single;
  if (metric is! String || metric.isEmpty) return null;
  final needle = metric.toLowerCase();
  final matches = leaves
      .where(
        (leaf) =>
            leaf.criterionId.toLowerCase() == needle ||
            switch (leaf) {
              GoalCriterionMetric(:final dataType) =>
                dataType.toLowerCase() == needle,
              GoalCriterionMeasurable(:final dataTypeId) =>
                dataTypeId.toLowerCase() == needle,
              _ => false,
            },
      )
      .toList();
  return matches.length == 1 ? matches.single : null;
}

num _leafTarget(GoalCriterion leaf) => switch (leaf) {
  GoalCriterionMetric(:final target) => target,
  GoalCriterionMeasurable(:final target) => target,
  _ => 0,
};

List<GoalCriterionHabit> _habitLeaves(GoalCriterion root) {
  final leaves = <GoalCriterionHabit>[];
  void visit(GoalCriterion c) {
    switch (c) {
      case GoalCriterionHabit():
        leaves.add(c);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(visit);
      case GoalCriterionMetric() || GoalCriterionMeasurable():
        break;
    }
  }

  visit(root);
  return leaves;
}

/// Rebuilds the tree with [transform] applied to the node whose
/// criterionId is [criterionId]; composites are rebuilt structurally.
GoalCriterion _mapLeaf(
  GoalCriterion node,
  String criterionId,
  GoalCriterion Function(GoalCriterion) transform,
) {
  if (node.criterionId == criterionId) return transform(node);
  return switch (node) {
    GoalCriterionAllOf(:final criteria) => node.copyWith(
      criteria: [for (final c in criteria) _mapLeaf(c, criterionId, transform)],
    ),
    GoalCriterionAnyOf(:final criteria) => node.copyWith(
      criteria: [for (final c in criteria) _mapLeaf(c, criterionId, transform)],
    ),
    GoalCriterionAtLeastCount(:final criteria) => node.copyWith(
      criteria: [for (final c in criteria) _mapLeaf(c, criterionId, transform)],
    ),
    _ => node,
  };
}
