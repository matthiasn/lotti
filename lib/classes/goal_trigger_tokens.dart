/// Workspace keys of the goal-agent wake records (ADR 0054).
///
/// Lives in `lib/classes` (the `day_agent_trigger_tokens.dart` precedent)
/// because the shared agent runtime's lease predicate must recognize these
/// without `features/agents` importing the goals feature.
library;

/// The recurring deterministic tick — one per goal agent, re-armed on
/// every run (recurrence by re-arm; no schema change).
const goalCadenceWorkspaceKey = 'goal-cadence';

/// Prefix of the per-period escalation workspaces. Escalation records are
/// lease-elected: exactly one device runs the LLM tier for a given
/// period's transition.
const goalEscalationWorkspacePrefix = 'goal-escalation';

/// Workspace key of the escalation wake for one evaluation period.
///
/// Scoped per period (ADR 0054's `goal-escalation:<periodKey>`) so an
/// overdue prior period's escalation is never superseded away by the next
/// period's — each period's transition keeps its own record identity.
String goalEscalationWorkspaceKey(String periodKey) =>
    '$goalEscalationWorkspacePrefix:$periodKey';

/// Whether a scheduled-wake workspace is a goal escalation (the lease
/// predicate's test).
bool isGoalEscalationWorkspace(String? workspaceKey) =>
    workspaceKey != null &&
    workspaceKey.startsWith('$goalEscalationWorkspacePrefix:');

/// The escalation period encoded in a wake's trigger tokens, or null when
/// the tokens carry no escalation marker.
///
/// The wake runner signature deliberately has no workspaceKey parameter
/// (the day agent's `digest:` prefix precedent): an escalation wake
/// carries its workspace key as a trigger token, and Phase B is entered
/// exactly when this returns non-null. A cadence or signal wake returns
/// null and stays on the €0 tier.
String? goalEscalationPeriodFromTriggerTokens(Set<String> triggerTokens) {
  for (final token in triggerTokens) {
    if (isGoalEscalationWorkspace(token)) {
      return token.substring(goalEscalationWorkspacePrefix.length + 1);
    }
  }
  return null;
}
