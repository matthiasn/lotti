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

/// Status of a wake run in the wake-run log.
enum WakeRunStatus {
  /// The wake is currently executing.
  running,

  /// The wake completed successfully.
  completed,

  /// The wake failed.
  failed,

  /// The wake was found in `running` state on startup (orphaned).
  abandoned,
}

/// Reason a wake was triggered.
enum WakeReason {
  /// Triggered by a subscription match on the notification stream.
  subscription,

  /// Triggered by the initial creation of a task agent.
  creation,

  /// Triggered by a manual re-analysis request from the user.
  reanalysis,
}

/// Status of an evolution session.
enum EvolutionSessionStatus {
  /// Session is currently in progress.
  active,

  /// Session completed with a new version created.
  completed,

  /// Session was abandoned without creating a version.
  abandoned,
}

/// Kind of evolution note (the evolution agent's private reasoning).
enum EvolutionNoteKind {
  /// Reflective observation about template performance.
  reflection,

  /// Hypothesis about what might improve the template.
  hypothesis,

  /// A decision made during the session.
  decision,

  /// A recurring pattern noticed across sessions.
  pattern,
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
