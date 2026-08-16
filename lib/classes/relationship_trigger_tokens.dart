/// Workspace keys and trigger tokens of the relationship-agent wake records
/// (ADR 0059 Decisions 2–3, the `goal_trigger_tokens.dart` shape).
///
/// Lives in `lib/classes` (the `day_agent_trigger_tokens.dart` precedent)
/// because the shared agent runtime's lease predicate must recognize these
/// without `features/agents` importing the relationships feature.
library;

/// The deterministic cadence-health verdict the register carries: either the
/// desired check-in interval still has room, or it has lapsed.
///
/// Deliberately two-valued: eligibility (the relationship is `active`, marked
/// `important`, not deleted) gates whether a register exists at all, so the
/// status only ever describes a tracked relationship. Phase B tells "newly
/// due" from "still due" by the baseline token below, never from storage —
/// Phase A has already overwritten the register by the time Phase B runs.
enum RelationshipCadenceStatus { ok, due }

/// The recurring deterministic tick — one per relationship agent, re-armed
/// on every run (recurrence by re-arm; no schema change).
const relationshipCadenceWorkspaceKey = 'relationship-cadence';

/// Explicit "Brief me" / post-check-in report refresh (Phase 5). Declared
/// with the contract so the wake router can reserve the route before the
/// LLM tier exists.
const relationshipReportRefreshTriggerToken = 'relationship-report-refresh';

bool relationshipReportRefreshRequested(Set<String> triggerTokens) =>
    triggerTokens.contains(relationshipReportRefreshTriggerToken);

/// Prefix of the per-episode escalation workspaces. Escalation records are
/// lease-elected: exactly one device runs the LLM tier for a given due
/// day's transition.
const relationshipEscalationWorkspacePrefix = 'relationship-escalation';

/// Workspace key of the escalation wake for one cadence episode.
///
/// Scoped per due day (ADR 0059's `relationship-escalation:<dueDayKey>`):
/// devices arming the same logical episode write identical records, and a
/// check-in that lands while an escalation is pending moves the due day —
/// a NEW episode with its own record identity, never a rewrite of the old
/// one (the `goal-escalation:<periodKey>` precedent).
String relationshipEscalationWorkspaceKey(String dueDayKey) =>
    '$relationshipEscalationWorkspacePrefix:$dueDayKey';

/// Whether a scheduled-wake workspace is a relationship escalation (the
/// lease predicate's test).
bool isRelationshipEscalationWorkspace(String? workspaceKey) =>
    workspaceKey != null &&
    workspaceKey.startsWith('$relationshipEscalationWorkspacePrefix:');

/// The due-day key encoded in a wake's trigger tokens, or null when the
/// tokens carry no escalation marker.
///
/// The wake runner signature deliberately has no workspaceKey parameter
/// (the day agent's `digest:` prefix precedent): an escalation wake
/// carries its workspace key as a trigger token, and the LLM tier is
/// entered exactly when this returns non-null. A cadence or signal wake
/// returns null and stays on the €0 tier.
String? relationshipEscalationDueDayFromTriggerTokens(
  Set<String> triggerTokens,
) {
  for (final token in triggerTokens) {
    if (isRelationshipEscalationWorkspace(token)) {
      return token.substring(relationshipEscalationWorkspacePrefix.length + 1);
    }
  }
  return null;
}

/// Prefix of the baseline token an escalation wake carries: the cadence
/// status that was PERSISTED BEFORE the transition that armed the wake.
///
/// Phase A writes the recomputed register (new status) and the escalation
/// in one transaction, so Phase B cannot reconstruct the pre-write status
/// from storage — "newly due" vs. "still due" would be unreconstructable
/// (the `goal-baseline` lesson, ADR 0059 Decision 3).
const relationshipEscalationBaselinePrefix = 'relationship-baseline';

/// The baseline token for a pre-transition status name.
String relationshipEscalationBaselineToken(String statusName) =>
    '$relationshipEscalationBaselinePrefix:$statusName';

/// The pre-transition status name encoded in an escalation wake's trigger
/// tokens, or null when none was recorded (first-ever evaluation).
String? relationshipEscalationBaselineFromTriggerTokens(
  Set<String> triggerTokens,
) {
  for (final token in triggerTokens) {
    if (token.startsWith('$relationshipEscalationBaselinePrefix:')) {
      return token.substring(relationshipEscalationBaselinePrefix.length + 1);
    }
  }
  return null;
}
