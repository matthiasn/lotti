/// Shared string constants for agent-domain identifiers.
///
/// Keeping these centralized avoids typo-prone hard-coded literals across
/// services, workflows, and persistence layers.
abstract final class AgentKinds {
  static const taskAgent = 'task_agent';
}

abstract final class AgentLinkTypes {
  static const basic = 'basic';
  static const agentState = 'agent_state';
  static const messagePrev = 'message_prev';
  static const messagePayload = 'message_payload';
  static const toolEffect = 'tool_effect';
  static const agentTask = 'agent_task';
  static const templateAssignment = 'template_assignment';
}

abstract final class AgentEntityTypes {
  static const agentState = 'agentState';
  static const agentMessage = 'agentMessage';
  static const agentReport = 'agentReport';
  static const agentReportHead = 'agentReportHead';
  static const agentTemplate = 'agentTemplate';
  static const agentTemplateVersion = 'agentTemplateVersion';
  static const agentTemplateHead = 'agentTemplateHead';
}

abstract final class AgentReportScopes {
  static const current = 'current';
}
