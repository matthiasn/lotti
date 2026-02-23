/// Enums for the agent domain.
library;

/// Lifecycle states for an agent.
enum AgentLifecycle {
  /// Agent has been created but not yet activated.
  created,

  /// Agent is active and will wake on triggers.
  active,

  /// Agent is paused — will not wake on triggers until resumed.
  dormant,

  /// Agent is permanently deactivated and its data may be cleaned up.
  destroyed,
}

/// How the agent interacts with the user.
enum AgentInteractionMode {
  /// Agent operates without user prompts during execution.
  autonomous,

  /// Agent requires user input at decision points.
  interactive,

  /// Agent can operate autonomously but may request user input.
  hybrid,
}

/// Runtime status of an agent (in-memory only, not persisted).
enum AgentRunStatus {
  /// Agent is sleeping, waiting for triggers.
  idle,

  /// A wake has been enqueued but not yet started.
  queued,

  /// Agent is currently executing a wake.
  running,

  /// Last wake failed.
  failed,
}

/// Kind of agent template.
enum AgentTemplateKind {
  /// A task-focused agent template.
  taskAgent,
}

/// Lifecycle status of an agent template version.
enum AgentTemplateVersionStatus {
  /// This version is the current active version.
  active,

  /// This version has been superseded.
  archived,
}

/// Kind of message in the agent's message log.
enum AgentMessageKind {
  /// Agent's private working notes (agentJournal entries).
  observation,

  /// User-originated message to the agent.
  user,

  /// Agent's internal reasoning (not shown to user).
  thought,

  /// Tool call request from the agent.
  action,

  /// Result of a tool call execution.
  toolResult,

  /// Summary of a message span (for memory compaction, future).
  summary,

  /// System-generated message (e.g., lifecycle events).
  system,
}
