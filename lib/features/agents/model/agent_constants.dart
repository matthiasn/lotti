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
  static const soulAssignment = 'soul_assignment';
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
  static const attentionRequest = 'attentionRequest';
  static const attentionClaimDisposition = 'attentionClaimDisposition';
  static const attentionAward = 'attentionAward';
  static const standingAgreement = 'standingAgreement';
  static const agentState = 'agentState';
  static const agentMessage = 'agentMessage';
  static const agentReport = 'agentReport';
  static const agentReportHead = 'agentReportHead';
  static const scheduledWake = 'scheduledWake';
  static const plannerKnowledge = 'plannerKnowledge';
  static const projectRecommendation = 'projectRecommendation';
  static const agentTemplateVersion = 'agentTemplateVersion';
  static const agentTemplateHead = 'agentTemplateHead';
  static const evolutionSessionRecap = 'evolutionSessionRecap';
  static const soulDocument = 'soulDocument';
  static const soulDocumentVersion = 'soulDocumentVersion';
  static const soulDocumentHead = 'soulDocumentHead';
}

/// `scope` values for `AgentReport` rows. `current` marks the live report a
/// detail page renders, as opposed to any archived/historical scope.
abstract final class AgentReportScopes {
  static const current = 'current';
}

/// `author` attribution stamped on entities a non-task agent produces.
///
/// Distinguishes machine-authored content — the evolution agent's outputs vs.
/// `system`-generated bookkeeping — so the UI and prompts can label provenance.
abstract final class AgentAuthors {
  static const evolutionAgent = 'evolution_agent';
  static const system = 'system';
}

/// Fixed schedule constants for recurring agent work.
///
/// [projectDailyDigestHour] is the local hour-of-day (24h) the project agent's
/// daily digest wake is scheduled for.
abstract final class AgentSchedules {
  static const projectDailyDigestHour = 6;
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
