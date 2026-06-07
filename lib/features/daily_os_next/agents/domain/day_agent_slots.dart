import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Slot helpers for day-agent identities.
extension DayAgentSlots on AgentSlots {
  /// Whether this state is bound to a Daily OS day plan.
  bool get hasActiveDay => activeDayId != null && activeDayId!.isNotEmpty;
}

/// Normalizes [date] to the local calendar day used by DayPlan IDs.
DateTime localDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Stable day-agent subject ID for a local calendar [date].
String dayAgentIdForDate(DateTime date) => dayPlanId(localDay(date));

/// Day workspace a capture belongs to (ADR 0022), derived-on-read.
///
/// Returns the explicit [CaptureEntity.dayId] when present, otherwise derives
/// it from [CaptureEntity.capturedAt] so captures synced from older peers
/// (which carry no `dayId`) still resolve to a concrete day workspace.
String captureDayId(CaptureEntity capture) => capture.dayId.isNotEmpty
    ? capture.dayId
    : dayAgentIdForDate(capture.capturedAt);

/// Deterministic agent-entity ID for the drafted day plan keyed by [dayId].
///
/// Same prefix used by `DayAgentPlanService` so cross-service lookups
/// (e.g. `DayAgentService.enqueueRefineWake` pre-checking that a plan
/// exists) stay in sync without leaking the constant.
String dayAgentPlanEntityId(String dayId) => 'day_agent_plan:$dayId';
