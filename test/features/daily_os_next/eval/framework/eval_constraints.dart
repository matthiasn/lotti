import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

import 'eval_models.dart';

part 'eval_constraints_content.dart';
part 'eval_constraints_estimates.dart';
part 'eval_constraints_schedule.dart';
part 'eval_constraints_trade.dart';

/// Whether [prose] mentions the title of [taskId].
bool _titleNamed(EvalRunOutcome outcome, String taskId, String prose) {
  final title = outcome.inputs.taskById(taskId)?.title.trim();
  if (title == null || title.isEmpty) return false;
  if (RegExp(
    r'\btask\s+' + RegExp.escape(title) + r'\b',
    caseSensitive: false,
  ).hasMatch(prose)) {
    return true;
  }
  return _allowsBareTaskTitle(title) &&
      RegExp(
        r'(?:^|[^\w-])' + RegExp.escape(title) + r'(?=$|[^\w-])',
        caseSensitive: false,
      ).hasMatch(prose);
}

bool _taskIdNamed(String taskId, String prose) => RegExp(
  r'(?:^|[^\w-])' + RegExp.escape(taskId) + r'(?=$|[^\w-])',
  caseSensitive: false,
).hasMatch(prose);

bool _allowsBareTaskTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized != 'a' && normalized != 'i';
}

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Objective constraints the day planner's output is scored against.
///
/// Every scorer here is a pure function over an [EvalRunOutcome] — no I/O, no
/// provider, no pipeline — so they run in ordinary CI and can be exercised
/// against hand-built plans.
///
/// The set is split deliberately, because the two halves measure different
/// things:
///
/// **Unguarded** constraints are scored on the persisted plan. Nothing in the
/// write path checks them, so whatever the model produced is what the user
/// gets. These are the ones that can silently ship a bad day.
///
/// **Guarded** constraints are scored on the *rejection count*. The write path
/// throws on these and hands the message back to the model, which retries — so
/// the persisted plan is always legal and tells you nothing. What varies, and
/// what a better prompt improves, is how many corrections the model needed
/// first. Zero rejections means it complied unaided.

/// Ids of the unguarded constraints, in report order.
abstract final class EvalConstraintIds {
  static const noOverlappingBlocks = 'noOverlappingBlocks';
  static const withinCapacity = 'withinCapacity';
  static const decidedTasksPlaced = 'decidedTasksPlaced';
  static const blockerBeforeBlocked = 'blockerBeforeBlocked';
  static const noFabricatedTaskIds = 'noFabricatedTaskIds';
  static const noHistoryFabrication = 'noHistoryFabrication';
  static const uniqueBlockIds = 'uniqueBlockIds';
  static const expectedOmissionsHonoured = 'expectedOmissionsHonoured';
  static const withinWorkingHours = 'withinWorkingHours';
  static const respectsEstimates = 'respectsEstimates';
  static const withinCapacityByEstimate = 'withinCapacityByEstimate';
  static const requiredWorkPlaced = 'requiredWorkPlaced';
  static const surfacedConflict = 'surfacedConflict';
  static const noInventedWork = 'noInventedWork';
  static const taskWorkIsTyped = 'taskWorkIsTyped';
  static const noFabricatedCalendarBlocks = 'noFabricatedCalendarBlocks';
  static const directiveHonoured = 'directiveHonoured';

  /// Guarded — scored on rejections rather than on the plan.
  static const compliedWithoutRejection = 'compliedWithoutRejection';

  static const all = <String>[
    noOverlappingBlocks,
    withinCapacity,
    decidedTasksPlaced,
    blockerBeforeBlocked,
    noFabricatedTaskIds,
    noHistoryFabrication,
    uniqueBlockIds,
    expectedOmissionsHonoured,
    withinWorkingHours,
    respectsEstimates,
    withinCapacityByEstimate,
    requiredWorkPlaced,
    surfacedConflict,
    noInventedWork,
    taskWorkIsTyped,
    noFabricatedCalendarBlocks,
    directiveHonoured,
    compliedWithoutRejection,
  ];
}

/// How strongly each constraint result should be interpreted.
///
/// Most constraints compare structured data and are objective. The always
/// heuristic constraints below deliberately accept string or structural
/// presence as an inexpensive indifference detector. A mixed constraint may
/// also mark only the result that used its semantic escape hatch. Such a green
/// is useful evidence that the model did not stay silent, but not that it
/// understood the dependency, capacity trade, or directive it answered.
abstract final class EvalConstraintSignals {
  static const heuristicIds = <String>{
    EvalConstraintIds.surfacedConflict,
    EvalConstraintIds.directiveHonoured,
  };

  static const mixedIds = <String>{
    EvalConstraintIds.blockerBeforeBlocked,
    EvalConstraintIds.withinCapacityByEstimate,
  };

  static const caveats = <String, String>{
    EvalConstraintIds.blockerBeforeBlocked:
        'Structured blocker ordering is objective. A pass that instead relies '
        'on a reason naming the blocker is heuristic: the match does not prove '
        'that the model understood the dependency or justified bypassing it; '
        'inspect the plan and reason in the judge bundle.',
    EvalConstraintIds.withinCapacityByEstimate:
        'Full-estimate accounting is objective. A pass that instead relies on '
        'interpreting free-form partial-placement prose is heuristic; inspect '
        'the reason and arithmetic in the judge bundle.',
    EvalConstraintIds.surfacedConflict:
        'Checks whether the output names omitted work or uses an accepted '
        'escalation reason. A match does not prove that the model understood '
        'the capacity trade; inspect the plan, reasons, and status note in the '
        'judge bundle.',
    EvalConstraintIds.directiveHonoured:
        'Checks whether commitments are named in plan or trade prose, or uses '
        'an accepted escalation whose status note may be non-empty but '
        'unrelated. A match does not prove that the model understood or '
        'answered the directive; inspect the plan, changes, reasons, and '
        'status note in the judge bundle.',
  };

  static bool isHeuristic(String id) => heuristicIds.contains(id);

  static bool isHeuristicResult(EvalConstraintResult result) =>
      isHeuristic(result.id) || result.heuristic;

  static String kindFor(String id) => isHeuristic(id)
      ? 'heuristic'
      : mixedIds.contains(id)
      ? 'mixed'
      : 'objective';

  static String kindForResult(EvalConstraintResult result) =>
      isHeuristicResult(result) ? 'heuristic' : 'objective';

  static String? caveatFor(String id) => caveats[id];
}

/// Scores every constraint against [outcome], in report order.
List<EvalConstraintResult> scoreAll(EvalRunOutcome outcome) => [
  scoreNoOverlappingBlocks(outcome),
  scoreWithinCapacity(outcome),
  scoreDecidedTasksPlaced(outcome),
  scoreBlockerBeforeBlocked(outcome),
  scoreNoFabricatedTaskIds(outcome),
  scoreNoHistoryFabrication(outcome),
  scoreUniqueBlockIds(outcome),
  scoreExpectedOmissionsHonoured(outcome),
  scoreWithinWorkingHours(outcome),
  scoreRespectsEstimates(outcome),
  scoreWithinCapacityByEstimate(outcome),
  scoreRequiredWorkPlaced(outcome),
  scoreSurfacedConflict(outcome),
  scoreNoInventedWork(outcome),
  scoreTaskWorkIsTyped(outcome),
  scoreNoFabricatedCalendarBlocks(outcome),
  scoreDirectiveHonoured(outcome),
  scoreCompliedWithoutRejection(outcome),
];
