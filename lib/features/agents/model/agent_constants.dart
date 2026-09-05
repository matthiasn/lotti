/// Shared string constants for agent-domain identifiers.
///
/// Keeping these centralized avoids typo-prone hard-coded literals across
/// services, workflows, and persistence layers.
abstract final class AgentKinds {
  static const taskAgent = 'task_agent';
  static const templateImprover = 'template_improver';
  static const projectAgent = 'project_agent';
  static const dayAgent = 'day_agent';
  static const eventAgent = 'event_agent';
  static const goalAgent = 'goal_agent';
  static const relationshipAgent = 'relationship_agent';
}

/// Notification scopes that carry meaning beyond a single agent entity ID.
abstract final class AgentNotificationScopes {
  /// Forces the Projects overview to refresh agent-authored one-liners.
  static const projectOverview = 'PROJECT_AGENT_OVERVIEW_CHANGED';
}

/// Tool-call names that carry user-visible conversation output.
///
/// A reply remains an action in the durable log rather than introducing a
/// second assistant-message schema. Conversation projections whitelist this
/// name and hide every other tool call by default.
abstract final class AgentConversationToolNames {
  static const replyToUser = 'reply_to_user';
}

/// `linkType` discriminators on `AgentLink` rows.
///
/// Every edge the agent layer persists between two entities carries one of
/// these so queries can fan out a single subject to just the related rows it
/// needs (e.g. the `message_prev` chain that orders a conversation, or
/// `tool_effect` linking a tool call to the journal entity it mutated).
abstract final class AgentLinkTypes {
  static const basic = 'basic';
  static const agentState = 'agent_state';
  static const messagePrev = 'message_prev';
  static const messagePayload = 'message_payload';
  static const toolEffect = 'tool_effect';
  static const agentTask = 'agent_task';
  static const captureToParsedItem = 'capture_to_parsed_item';
  static const parsedItemToTask = 'parsed_item_to_task';
  static const captureToPlan = 'capture_to_plan';
  static const attentionRequestEvidence = 'attention_request_evidence';
  static const attentionAwardRequest = 'attention_award_request';
  static const attentionAwardPlan = 'attention_award_plan';
  static const templateAssignment = 'template_assignment';
  static const improverTarget = 'improver_target';
  static const agentProject = 'agent_project';
  static const agentDay = 'agent_day';
  static const agentEvent = 'agent_event';
  static const agentGoal = 'agent_goal';
  static const soulAssignment = 'soul_assignment';
  static const agentRelationship = 'agent_relationship';
}

/// `entityType` discriminators on the agent domain's append-only entity rows.
///
/// Agent state, messages, reports, scheduled wakes, templates, and soul
/// documents all share one storage table and are told apart by these tags.
/// The `*Head` variants mark the current-version pointer for the versioned
/// document families (reports, templates, souls); their non-head siblings are
/// the individual immutable versions.
abstract final class AgentEntityTypes {
  static const capture = 'day_capture';
  static const parsedItem = 'parsed_capture_item';
  static const dayPlan = 'day_plan';
  static const daySummary = 'daySummary';
  static const dayDirective = 'day_directive';
  static const dayStatusEvent = 'day_status_event';
  static const weekRollup = 'week_rollup';
  static const attentionRequest = 'attentionRequest';
  static const attentionClaimDisposition = 'attentionClaimDisposition';
  static const attentionAward = 'attentionAward';
  static const standingAgreement = 'standingAgreement';
  static const agentState = 'agentState';
  static const changeDecision = 'changeDecision';
  static const agentMessage = 'agentMessage';
  static const changeSet = 'changeSet';
  static const agentReport = 'agentReport';
  static const agentReportHead = 'agentReportHead';
  static const scheduledWake = 'scheduledWake';
  static const plannerKnowledge = 'plannerKnowledge';
  static const projectRecommendationRun = 'projectRecommendationRun';
  static const projectRecommendation = 'projectRecommendation';
  static const agentTemplateVersion = 'agentTemplateVersion';
  static const agentTemplateHead = 'agentTemplateHead';
  static const evolutionSessionRecap = 'evolutionSessionRecap';
  static const soulDocument = 'soulDocument';
  static const soulDocumentVersion = 'soulDocumentVersion';
  static const soulDocumentHead = 'soulDocumentHead';
  static const goalSpecVersion = 'goalSpecVersion';
  static const goalSpecHead = 'goalSpecHead';
  static const goalProgress = 'goalProgress';
  static const goalNudge = 'goalNudge';
  static const relationshipNudge = 'relationshipNudge';
  static const relationshipHealth = 'relationshipHealth';

  /// Every nudge union variant. A new nudge kind MUST be added here so the
  /// decode-boundary cross-field validation in `agent_domain_entity.dart`
  /// covers it instead of silently skipping (fail-open) — the compiler
  /// cannot catch a miss at that string-typed gate.
  static const Set<String> nudgeTypes = {goalNudge, relationshipNudge};
}

/// `scope` values for `AgentReport` rows. `current` marks the live report a
/// detail page renders, as opposed to any archived/historical scope.
abstract final class AgentReportScopes {
  static const current = 'current';
}

/// Shared `author` attribution values stamped on agent-domain entities.
///
/// Distinguishes owner-authored versions, machine-authored content, and
/// `system`-generated bookkeeping so UI, sync, and prompts can label provenance.
abstract final class AgentAuthors {
  static const user = 'user';
  static const evolutionAgent = 'evolution_agent';
  static const system = 'system';

  /// A version whose directives were written by seeding rather than by a person
  /// or the evolution agent.
  ///
  /// This is the provenance signal the prompt builder uses to decide whether a
  /// template carries Lotti's own directives (ADR 0052). It answers that
  /// question directly, where comparing the text against today's seeded
  /// constant only answers it for a template seeded since that constant last
  /// changed — every earlier install reads as customised and silently loses the
  /// substitutions the constants exist to drive.
  ///
  /// Deliberately exact rather than a `system:`-prefix match. Namespaced system
  /// authors such as `system:config_change` are stamped on versions that *copy*
  /// directives forward, so on an install that evolved a template and then
  /// changed its model, that stamp sits on evolved text. Treating it as system
  /// authorship would suppress a user-approved directive, which is a worse
  /// failure than the one this fixes.
  static bool isSystemAuthored(String authoredBy) =>
      authoredBy.trim() == system;
}

/// Fixed schedule constants for recurring agent work.
///
/// [projectDailyDigestHour] is the local hour-of-day (24h) the project agent's
/// daily digest wake is scheduled for.
abstract final class AgentSchedules {
  static const projectDailyDigestHour = 6;

  /// Local hour-of-day (24h) the Daily OS coordinator's digest wake is
  /// scheduled for (ADR 0032 phase 3): consume status events + summaries,
  /// then issue the day's directives before the user's typical check-in.
  static const dayAgentDigestHour = 6;
}

/// Format a [DateTime] as YYYY-MM-DD. Returns `null` for a `null` input.
String? formatIsoDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Deterministic id for the recap entity summarizing an evolution session,
/// one per session. The fixed mapping lets readers look up a session's recap
/// without an extra link query.
String evolutionSessionRecapId(String sessionId) =>
    'evolution-session-recap-$sessionId';

/// Deterministic id for a `ScheduledWakeEntity`, one per
/// `(agentId, workspaceKey)` (ADR 0022 Decision 12).
///
/// Re-scheduling the same workspace's wake overwrites the prior record (LWW)
/// rather than accumulating; a `null` workspace is the agent's single global
/// scheduled wake.
String scheduledWakeRecordId(String agentId, {String? workspaceKey}) =>
    'scheduled_wake:$agentId:${workspaceKey ?? 'global'}';

/// Deterministic id for a goal agent's spec head pointer, one per agent
/// (ADR 0053 Decision 2). One goal agent has exactly one current spec.
String goalSpecHeadId(String agentId) => 'goal_spec_head:$agentId';

/// Unique id for a post-creation goal-spec revision.
///
/// Owner-authored revisions carry an explicit marker so the concurrent sync
/// resolver can preserve direct owner intent when a disconnected agent
/// approval independently mints the same version ordinal.
String goalSpecRevisionVersionId({
  required String agentId,
  required int version,
  required bool ownerAuthored,
  required String uniqueSuffix,
}) => '$agentId:spec-v$version${ownerAuthored ? '-owner' : ''}-$uniqueSuffix';

/// Whether [versionId] identifies a marked owner-authored goal revision.
bool isOwnerAuthoredGoalSpecVersionId(String versionId) =>
    RegExp(r':spec-v\d+-owner-').hasMatch(versionId);

/// Deterministic id for one goal's attainment register row, one per
/// `(agentId, periodKey)` (ADR 0053 Decision 4).
///
/// [periodKey] is the goal's EVALUATION-DAY key (`GoalWindow.day()`
/// `periodKey` of the reference date, `2026-08-08`) — one register row per
/// goal per day, regardless of how many windows its criteria mix: a
/// composite of a rolling-7 metric and a calendar-week habit has no single
/// "period", so the register snapshots the whole goal as-of each day and
/// per-leaf window context lives inside `criterionResults`. Recomputed-
/// never-accumulated: N devices evaluating the same day write the same id
/// and LWW-converge instead of duplicating.
String goalProgressId(String agentId, String periodKey) =>
    'goal_progress:$agentId:$periodKey';

/// Deterministic id for a relationship agent's cadence-health register —
/// ONE row per agent, recomputed on every deterministic tick (ADR 0059
/// Decision 2). Unlike `goalProgressId` there is no period component: the
/// register is current cadence state, not history; check-ins ARE the
/// history.
String relationshipHealthId(String agentId) => 'relationship_health:$agentId';

/// Deterministic agent id for the relationship agent watching
/// [relationshipId] (ADR 0059 Decision 2): two devices marking the same
/// person important converge on ONE agent via LWW instead of minting
/// duplicates (the deterministic-id contract of `createAgent`).
String relationshipAgentIdFor(String relationshipId) =>
    'relationship_agent:$relationshipId';

/// Deterministic id of the agent→relationship link — one per agent, so
/// concurrent creates write the same row.
String relationshipAgentLinkId(String agentId) => 'agent_relationship:$agentId';
