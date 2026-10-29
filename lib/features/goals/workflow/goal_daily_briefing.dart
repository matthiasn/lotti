import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/goals/logic/goal_today_briefing.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

/// The goal's daily briefing: the first standing report of each day.
///
/// Not a new artifact. The standing report already carries a short read of
/// where the goal stands (`tldr`, the period and rolling sections) and what
/// comes next (`nextActions`); the briefing is that report, written once a
/// day whether or not anything transitioned, with its weight on what comes
/// next. Phase A arms it on the day's cadence tick; this file is what the
/// wake tells the model when it runs.

/// Whether this wake writes the day's briefing: no report covers the
/// evaluated period yet, and nobody is waiting on a chat reply — a chat turn
/// answers the user, it is not the morning read.
bool goalDailyBriefingDue(GoalWakeFacts facts, {required bool interactive}) =>
    !interactive && !facts.periodReported;

/// What the previous briefing said, for continuity: its summary and the next
/// steps it showed the user, so today's can follow up on them instead of
/// starting cold. Null when the latest report is not from a period BEFORE
/// [periodKey] (it is today's — or, for an overdue escalation evaluating an
/// older day, written after it), when it was not written for
/// the spec [specVersionId] created at [specCreatedAt] (the goal was revised
/// since — see [goalReportBelongsToSpec]), or when it said neither.
///
/// Read from the report as STORED: the summary is the report's own `tldr`,
/// and the persisted sections carry `nextActions` as the one list of steps
/// the user actually saw — current actions already gated, later ones after.
Map<String, Object?>? goalPreviousBriefingFacts(
  AgentReportEntity? report, {
  required String periodKey,
  required String specVersionId,
  required DateTime specCreatedAt,
}) {
  if (report == null) return null;
  final reportPeriod = report.provenance['periodKey'];
  // Period keys are ISO dates, so string order is day order.
  if (reportPeriod is! String || reportPeriod.compareTo(periodKey) >= 0) {
    return null;
  }
  if (!goalReportBelongsToSpec(
    report,
    specVersionId: specVersionId,
    specCreatedAt: specCreatedAt,
  )) {
    return null;
  }
  final tldr = report.tldr?.trim();
  final nextSteps = goalReportNextSteps(report);
  final hasTldr = tldr != null && tldr.isNotEmpty;
  if (!hasTldr && nextSteps.isEmpty) return null;
  return {
    'periodKey': reportPeriod,
    if (hasTldr) 'tldr': tldr,
    if (nextSteps.isNotEmpty) 'nextSteps': nextSteps,
  };
}

/// Appended to the FACTS of a briefing wake. It rides the wake rather than
/// the system prompt, which is at its ceiling and holds only rules every turn
/// needs — this one applies to the day's first report alone.
const goalDailyBriefingInstruction =
    'DAILY BRIEFING. This is the first standing report of the period: call '
    'update_goal_report. Keep tldr to one or two sentences on where the goal '
    'stands. Put the weight on what comes next: nextActions.later leads with '
    'one to three concrete, specific next steps grounded in the FACTS — a '
    'lagging criterion, a commitment or blocker in userVoice, something the '
    'charter says the goal is for, a fact in knowledge, a trend. In '
    'reflection, engage with what the user said since the last briefing. When '
    'reporting.previousBriefing is present, follow up on its nextSteps: say '
    'which the evidence shows happened, and carry forward what did not.';

/// The pinned retry when a briefing wake answered without a report.
const goalDailyBriefingReportInstruction =
    'This wake is the daily briefing. Call update_goal_report now: a short '
    'read of where the goal stands from the FACTS block, a reflection on what '
    'the user said, and concrete next steps in nextActions.later.';
