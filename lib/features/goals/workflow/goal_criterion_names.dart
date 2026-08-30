import 'package:lotti/classes/goal_criterion.dart';

/// The user-defined entities a criteria tree refers to, by kind.
typedef GoalCriterionEntityIds = ({
  Set<String> habitIds,
  Set<String> dataTypeIds,
});

/// Resolves display names for the habits and measurables a criteria tree
/// refers to, keyed by their id.
///
/// A function rather than a repository handle, so the agent tier depends on
/// the shape of the data and not on the journal stack. The FACTS renderer
/// names a criterion by its title; a criterion authored without one — an
/// older or hand-written spec — is named after the entity it measures
/// instead, and this is where that name comes from. Ids missing from the
/// result simply stay unnamed.
typedef GoalCriterionNameReader =
    Future<Map<String, String>> Function(GoalCriterionEntityIds ids);

/// Every habit id and measurable data-type id under [criterion].
GoalCriterionEntityIds goalCriterionEntityIds(GoalCriterion criterion) {
  final habitIds = <String>{};
  final dataTypeIds = <String>{};
  void visit(GoalCriterion node) {
    switch (node) {
      case GoalCriterionHabit(:final habitId):
        habitIds.add(habitId);
      case GoalCriterionMeasurable(:final dataTypeId):
        dataTypeIds.add(dataTypeId);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(visit);
      case GoalCriterionMetric() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        break;
    }
  }

  visit(criterion);
  return (habitIds: habitIds, dataTypeIds: dataTypeIds);
}
