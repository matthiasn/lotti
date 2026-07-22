import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';

/// Deterministic identity id of the Daily OS coordinator (ADR 0022/0032).
///
/// Constant across devices on purpose: concurrent `getOrCreatePlannerAgent`
/// calls on offline peers create entities with identical ids, so sync merges
/// them via LWW instead of diverging into one planner per device.
///
/// Under ADR 0032 this identity is the *coordinator*: it keeps cross-day
/// learning (durable knowledge, weekly evolution) and owns days that predate
/// the per-day cutover, while new days are executed by per-day agents
/// (see [perDayAgentId]).
const dailyOsPlannerAgentId = 'daily_os_planner';

/// Prefix of per-day agent identity ids (ADR 0032).
///
/// Distinct from bare legacy per-day ids (`dayplan-YYYY-MM-DD`, the pre-ADR-
/// 0022 model) so the legacy-migration path can archive those without ever
/// touching ADR 0032 identities.
const perDayAgentIdPrefix = 'day_agent:';

/// Deterministic per-day agent identity id for [dayId] (ADR 0032).
///
/// `day_agent:dayplan-YYYY-MM-DD`. Deterministic for the same convergence
/// reason as [dailyOsPlannerAgentId]: concurrent lazy creation on offline
/// peers merges via LWW instead of splitting a day across duplicates.
String perDayAgentId(String dayId) => '$perDayAgentIdPrefix$dayId';

/// Per-day agent identity id for the local calendar day of [date].
String perDayAgentIdForDate(DateTime date) =>
    perDayAgentId(dayPlanId(localDay(date)));

/// Whether [agentId] is an ADR 0032 per-day agent identity.
///
/// `false` for the coordinator and for bare legacy `dayplan-…` ids.
bool isPerDayAgentId(String agentId) => agentId.startsWith(perDayAgentIdPrefix);

/// The day id owned by a per-day agent, or `null` for any other id.
String? dayIdFromPerDayAgentId(String agentId) {
  if (!isPerDayAgentId(agentId)) return null;
  final dayId = agentId.substring(perDayAgentIdPrefix.length);
  return dayId.isEmpty ? null : dayId;
}

/// Whether [agentId] legitimately owns Daily OS day artifacts (plans,
/// summaries, captures): the coordinator or any per-day agent.
///
/// Used to relax reads that must span the ownership cutover — e.g. week
/// lookback over days written by the planner pre-cutover and by sibling
/// per-day agents post-cutover — while still excluding foreign agents.
bool isDailyOsDayOwner(String agentId) =>
    agentId == dailyOsPlannerAgentId || isPerDayAgentId(agentId);
