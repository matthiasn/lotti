import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';

/// What a goal's check-ins are to its agent, which decides how much of them
/// survives compaction.
enum GoalCheckInWeight {
  /// Commentary on progress measured elsewhere — a habit, a metric, tracked
  /// time. The summary keeps what bears on that progress and drops the rest.
  context,

  /// The substance of the goal itself: a journal, a reflective practice —
  /// what the user wrote or said is the thing the coach is there to engage
  /// with. The summary keeps the themes, insights, decisions and questions,
  /// not just that a check-in happened.
  substance;

  /// The user's say on [spec] when they gave one (ADR 0151); otherwise a goal
  /// measured by the time spent checking in is a journal, and any other goal
  /// is not.
  static GoalCheckInWeight of(GoalSpecVersionEntity spec) =>
      (spec.checkInsAreSubstance ??
          goalCriteriaMeasureCheckInTime(spec.criteria))
      ? substance
      : context;
}
