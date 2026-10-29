import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';

/// What a goal's check-ins are to its agent, which decides how much of them
/// survives compaction.
enum GoalCheckInWeight {
  /// Commentary on progress measured elsewhere — a habit, a metric, tracked
  /// time. The summary keeps what bears on that progress and drops the rest.
  context,

  /// The substance of the goal itself: a goal measured by the time spent
  /// checking in is a journal, and what the user wrote or said is the thing
  /// the coach is there to engage with. The summary keeps the themes,
  /// insights, decisions and questions, not just that a check-in happened.
  substance;

  static GoalCheckInWeight of(GoalCriterion criteria) =>
      goalCriteriaMeasureCheckInTime(criteria) ? substance : context;
}
