/// Shared string constants for agent-domain identifiers.
///
/// Keeping these centralized avoids typo-prone hard-coded literals across
/// services, workflows, and persistence layers.
abstract final class AgentKinds {
  static const taskAgent = 'task_agent';
  static const templateImprover = 'template_improver';
}

abstract final class AgentLinkTypes {
  static const basic = 'basic';
  static const agentState = 'agent_state';
  static const messagePrev = 'message_prev';
  static const messagePayload = 'message_payload';
  static const toolEffect = 'tool_effect';
  static const agentTask = 'agent_task';
  static const templateAssignment = 'template_assignment';
  static const improverTarget = 'improver_target';
}

abstract final class AgentEntityTypes {
  static const agentState = 'agentState';
  static const agentMessage = 'agentMessage';
  static const agentReport = 'agentReport';
  static const agentReportHead = 'agentReportHead';
  static const agentTemplate = 'agentTemplate';
  static const agentTemplateVersion = 'agentTemplateVersion';
  static const agentTemplateHead = 'agentTemplateHead';
  static const wakeTokenUsage = 'wakeTokenUsage';
}

abstract final class AgentReportScopes {
  static const current = 'current';
}

abstract final class AgentAuthors {
  static const evolutionAgent = 'evolution_agent';
}

/// Format a [DateTime] as YYYY-MM-DD. Returns `null` for a `null` input.
String? formatIsoDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
