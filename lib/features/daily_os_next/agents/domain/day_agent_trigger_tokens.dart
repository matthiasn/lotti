/// Wake trigger-token vocabulary for the Daily OS planner (ADR 0022).
///
/// Tokens are the wire contract between enqueue sites and the planner
/// workflow. Every day-scoped wake carries an explicit day workspace token
/// (`planning_day:<dayId>`); mode tokens (`drafting:` / `refine:`) and
/// payload tokens (`capture_submitted:` / `decided_task:` /
/// `decided_capture_item:`) ride alongside it.
///
/// All extractors in this file are deterministic under merged token sets:
/// once one planner identity owns many day workspaces, a queued job may
/// carry tokens for more than one day, and "first match from a `Set`" is
/// not a stable answer. Day-scoped extraction is therefore either
/// workspace-filtered (`hasDraftingTokenForDay`) or exhaustive + ordered
/// (`captureIdsFromTriggerTokens`, [resolvePlannerWakeDay]).
library;

/// Wake trigger token prefix that scopes a wake to a day workspace.
///
/// `planning_day:<dayId>` is the authoritative day-workspace claim on a
/// wake (ADR 0022 Decision 4). Mode tokens may corroborate it but the
/// workspace token is what enqueue sites must include on every day-scoped
/// wake.
const dayAgentPlanningDayPrefix = 'planning_day:';

/// Wake trigger token prefix used when a capture should be parsed.
const dayAgentCaptureSubmittedPrefix = 'capture_submitted:';

/// Wake scheduling reason used when a capture was submitted.
const dayAgentCaptureSubmittedReason = 'capture_submitted';

/// Wake trigger token prefix used to request a day-plan drafting wake.
const dayAgentDraftingPrefix = 'drafting:';

/// Wake scheduling reason used when a draft is requested.
const dayAgentDraftingReason = 'drafting';

/// Wake trigger token prefix used to request a day-plan refine wake.
const dayAgentRefinePrefix = 'refine:';

/// Wake scheduling reason used when a refine is requested.
const dayAgentRefineReason = 'refine';

/// Wake trigger token prefix used to advertise a task the UI considers
/// "decided" (one the user said yes to and wants placed in the day plan).
const dayAgentDecidedTaskPrefix = 'decided_task:';

/// Wake trigger token prefix used to advertise a parsed capture item the UI
/// considers "decided" but which does not have a persisted task ID yet.
const dayAgentDecidedCaptureItemPrefix = 'decided_capture_item:';

/// Creates the planning-day workspace trigger token for [dayId].
String dayAgentPlanningDayToken(String dayId) {
  return '$dayAgentPlanningDayPrefix$dayId';
}

/// Creates the capture-submitted wake trigger token.
String dayAgentCaptureSubmittedToken(String captureId) {
  return '$dayAgentCaptureSubmittedPrefix$captureId';
}

/// Creates the drafting wake trigger token for [dayId].
String dayAgentDraftingToken(String dayId) {
  return '$dayAgentDraftingPrefix$dayId';
}

/// Creates the refine wake trigger token for [dayId].
String dayAgentRefineToken(String dayId) {
  return '$dayAgentRefinePrefix$dayId';
}

/// Creates the decided-task trigger token for [taskId].
String dayAgentDecidedTaskToken(String taskId) {
  return '$dayAgentDecidedTaskPrefix$taskId';
}

/// Creates the decided capture-item trigger token for [parsedItemId].
String dayAgentDecidedCaptureItemToken(String parsedItemId) {
  return '$dayAgentDecidedCaptureItemPrefix$parsedItemId';
}

/// Whether [triggerTokens] requests a drafting wake for the [dayId]
/// workspace.
///
/// Workspace-filtered on purpose: under one planner a merged token set may
/// hold `drafting:` tokens for several days, so "is there any drafting
/// token" is not a meaningful question — only "is there one for *this*
/// day".
bool hasDraftingTokenForDay(Set<String> triggerTokens, String dayId) {
  return triggerTokens.contains(dayAgentDraftingToken(dayId));
}

/// Whether [triggerTokens] requests a refine wake for the [dayId] workspace.
///
/// Workspace-filtered for the same reason as [hasDraftingTokenForDay].
bool hasRefineTokenForDay(Set<String> triggerTokens, String dayId) {
  return triggerTokens.contains(dayAgentRefineToken(dayId));
}

/// Extracts every submitted capture ID from a trigger-token set.
///
/// Returns IDs trimmed of surrounding whitespace and **sorted** so callers
/// behave deterministically when a merged token set advertises several
/// captures. Skips prefix-only and whitespace-only tokens.
List<String> captureIdsFromTriggerTokens(Set<String> triggerTokens) {
  return _idsForPrefix(triggerTokens, dayAgentCaptureSubmittedPrefix)..sort();
}

/// Extracts every decided-task ID advertised on a trigger-token set.
///
/// Returns IDs trimmed of surrounding whitespace and **sorted**, so the
/// decided-task ordering rendered into the drafting prompt is stable under a
/// merged token set. Skips prefix-only and whitespace-only tokens. Returns an
/// empty list when no decided-task tokens are present.
List<String> decidedTaskIdsFromTriggerTokens(Set<String> triggerTokens) =>
    _idsForPrefix(triggerTokens, dayAgentDecidedTaskPrefix)..sort();

/// Extracts every decided capture-item ID advertised on a trigger-token set.
///
/// These IDs refer to parsed capture items rather than journal tasks. They let
/// drafting carry approved NEW/unlinked items forward so the model can create
/// tasks before placing them. Returned trimmed and **sorted** for the same
/// determinism reason as [decidedTaskIdsFromTriggerTokens].
List<String> decidedCaptureItemIdsFromTriggerTokens(
  Set<String> triggerTokens,
) => _idsForPrefix(triggerTokens, dayAgentDecidedCaptureItemPrefix)..sort();

List<String> _idsForPrefix(Set<String> tokens, String prefix) {
  final out = <String>[];
  for (final token in tokens) {
    if (token.startsWith(prefix)) {
      final id = token.substring(prefix.length).trim();
      if (id.isNotEmpty) out.add(id);
    }
  }
  return out;
}

/// Day workspace claimed by a trigger-token set.
///
/// Produced by [resolvePlannerWakeDay]. A wake resolves to a day only when
/// every day-scoped token on the set agrees on a single workspace;
/// disagreement is surfaced as ambiguity instead of an arbitrary pick so the
/// workflow can fail fast (ADR 0022 Decision 3).
class PlannerWakeDayResolution {
  /// Creates a resolution over the distinct day [candidates] found.
  const PlannerWakeDayResolution({required this.candidates});

  /// All distinct day IDs advertised by day-scoped tokens.
  final Set<String> candidates;

  /// Whether the token set claims more than one day workspace.
  bool get isAmbiguous => candidates.length > 1;

  /// The single claimed day workspace, or `null` when none or ambiguous.
  String? get dayId => candidates.length == 1 ? candidates.first : null;
}

/// Resolves the day workspace claimed by [triggerTokens].
///
/// Considers the day-carrying token families: `planning_day:`, `drafting:`,
/// and `refine:`. Capture tokens carry capture IDs, not day IDs, so a
/// capture-only wake resolves no candidate here; the caller falls back to
/// the capture's own day scope (or, pre-cutover, the legacy
/// `activeDayId` slot).
PlannerWakeDayResolution resolvePlannerWakeDay(Set<String> triggerTokens) {
  const dayPrefixes = [
    dayAgentPlanningDayPrefix,
    dayAgentDraftingPrefix,
    dayAgentRefinePrefix,
  ];
  final candidates = <String>{};
  for (final token in triggerTokens) {
    for (final prefix in dayPrefixes) {
      if (token.startsWith(prefix)) {
        final dayId = token.substring(prefix.length).trim();
        if (dayId.isNotEmpty) candidates.add(dayId);
      }
    }
  }
  return PlannerWakeDayResolution(candidates: candidates);
}
