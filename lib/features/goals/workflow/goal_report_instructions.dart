/// What a wake tells the model about why it must write a standing report.
///
/// Every reason has two texts: the one appended to the FACTS of the primary
/// turn, and the one a forced retry sends when that turn wrote no report.
/// They name the reason that actually applies — a retry that told the model
/// "the user edited a habit day" on a wake Phase A armed by itself described
/// something that never happened.
library;

import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_daily_briefing.dart';

/// Why a wake carries the report-refresh token.
///
/// The detail page's "Update now" and a habit-day edit enqueue it without an
/// escalation period; Phase A arms every escalation with it. So the period
/// tells them apart, and only one of them is something the user asked for.
enum GoalReportRefreshCause {
  /// No refresh token on the wake.
  none,

  /// The user asked from the goal page.
  userRequested,

  /// Phase A armed the wake: evidence changed, a check-in landed, or the
  /// day's cadence tick found no report.
  automatic;

  static GoalReportRefreshCause of({
    required bool reportRefresh,
    required String? escalationPeriod,
  }) => !reportRefresh
      ? none
      : escalationPeriod == null
      ? userRequested
      : automatic;
}

/// Appended when the user asked for a refresh from the goal page.
const goalUserRefreshInstruction =
    'USER REQUESTED REPORT REFRESH AFTER WATCHED EVIDENCE CHANGED. Update the '
    'standing report from the authoritative FACTS.';

/// Appended when Phase A armed the wake and it is not the day's briefing,
/// which carries its own instruction.
const goalAutomaticRefreshInstruction =
    'THE STANDING REPORT IS OUT OF DATE: watched evidence or the '
    "user's check-ins changed since it was written. Update it from the "
    'authoritative FACTS, and reflect every userVoice entry marked '
    'sinceLastReport.';

/// Appended when the user asked in chat for the report itself to change.
const goalUserReportRequestInstruction =
    'USER EXPLICITLY ASKED FOR THE STANDING REPORT TO CHANGE. Call '
    'update_goal_report in this turn with the full rewritten report honouring '
    'their instruction; replying without it leaves the report they '
    'complained about untouched.';

/// The pinned retry for a wake that had to report and did not, naming the
/// strongest reason that applies.
String goalForcedReportInstruction({
  required bool userRequestedReport,
  required GoalReportRefreshCause refreshCause,
  required bool statusTransitioned,
  required bool dailyBriefing,
}) {
  if (userRequestedReport) {
    return 'The user asked in chat for the standing report itself to change. '
        'Call update_goal_report now with the full rewritten report honouring '
        'their instruction, keeping every value faithful to the FACTS block.';
  }
  if (refreshCause == GoalReportRefreshCause.userRequested) {
    return 'The user explicitly requested a standing-report refresh after '
        'editing a habit day. Call update_goal_report now with the status '
        'and current evidence from the FACTS block.';
  }
  if (statusTransitioned) return goalStatusTransitionReportInstruction;
  if (dailyBriefing) return goalDailyBriefingReportInstruction;
  return 'The standing report is out of date. Call update_goal_report now '
      'with the status from the FACTS block, and a reflection on every '
      'userVoice entry marked sinceLastReport.';
}
