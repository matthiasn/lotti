/// Shared string constants for agent-domain identifiers.
///
/// Keeping these centralized avoids typo-prone hard-coded literals across
/// services, workflows, and persistence layers.
abstract final class AgentKinds {
  static const taskAgent = 'task_agent';
  static const templateImprover = 'template_improver';
  static const projectAgent = 'project_agent';
  static const dayAgent = 'day_agent';
}

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
  static const soulAssignment = 'soul_assignment';
}

abstract final class AgentEntityTypes {
  static const capture = 'day_capture';
  static const parsedItem = 'parsed_capture_item';
  static const dayPlan = 'day_plan';
  static const attentionRequest = 'attentionRequest';
  static const attentionAward = 'attentionAward';
  static const agentState = 'agentState';
  static const agentMessage = 'agentMessage';
  static const agentReport = 'agentReport';
  static const agentReportHead = 'agentReportHead';
  static const projectRecommendation = 'projectRecommendation';
  static const agentTemplateVersion = 'agentTemplateVersion';
  static const agentTemplateHead = 'agentTemplateHead';
  static const evolutionSessionRecap = 'evolutionSessionRecap';
  static const soulDocument = 'soulDocument';
  static const soulDocumentVersion = 'soulDocumentVersion';
  static const soulDocumentHead = 'soulDocumentHead';
}

abstract final class AgentReportScopes {
  static const current = 'current';
}

abstract final class AgentAuthors {
  static const evolutionAgent = 'evolution_agent';
  static const system = 'system';
}

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

String evolutionSessionRecapId(String sessionId) =>
    'evolution-session-recap-$sessionId';
