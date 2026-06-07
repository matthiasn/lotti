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

  /// A day-focused agent template for Daily OS planning.
  dayAgent,

  /// A template-improver agent template (manages one-on-one rituals).
  templateImprover,

  /// A project-focused agent template.
  projectAgent,
}

/// Lifecycle status of an agent template version.
enum AgentTemplateVersionStatus {
  /// This version is the current active version.
  active,

  /// This version has been superseded.
  archived,
}

/// Lifecycle status of a soul document version.
enum SoulDocumentVersionStatus {
  /// This version is the current active version.
  active,

  /// This version has been superseded.
  archived,
}

/// Classification target for agent observations, used to route feedback to the
/// correct evolution cycle (skill vs. personality).
enum ObservationTarget {
  /// Feedback about template skills and operational directives.
  template,

  /// Feedback about personality and soul.
  soul,

  /// Feedback that applies to both.
  both,
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

  /// The wake was aborted — either by the user (cancel button) or by the
  /// global per-cycle timeout (wakeRunMaxDuration).
  aborted,
}

/// Reason a wake was triggered.
enum WakeReason {
  /// Triggered by a subscription match on the notification stream.
  subscription,

  /// Triggered by the initial creation of a task agent.
  creation,

  /// Triggered by a manual re-analysis request from the user.
  reanalysis,

  /// Triggered by a scheduled timer (e.g., weekly one-on-one ritual).
  scheduled,

  /// Triggered immediately after speech transcription completes for an
  /// audio entry linked to a task — bypasses the throttle so the user
  /// does not wait through a 2-minute countdown after speaking.
  transcriptionComplete,
}

/// Where a durable planner-knowledge entry came from (ADR 0022 Decision 10).
enum KnowledgeSource {
  /// The user told the planner directly ("never schedule deep work before 10").
  /// May skip straight to [KnowledgeStatus.confirmed].
  userStated,

  /// The planner inferred it; reaches durable knowledge only through the weekly
  /// gate or an explicit user confirmation.
  agentInferred,
}

/// Lifecycle of a durable planner-knowledge entry (ADR 0022 Decision 10).
enum KnowledgeStatus {
  /// Awaiting the user's confirmation in the "What I've learned" panel.
  proposed,

  /// User-confirmed (or user-stated). Part of the active Head set.
  confirmed,

  /// Explicitly retracted; excluded from the active Head set.
  retracted,
}

/// Lifecycle status of a persisted scheduled-wake record (ADR 0022).
enum ScheduledWakeStatus {
  /// Not yet fired; the scheduled-wake manager will enqueue it once due.
  pending,

  /// Already enqueued by the manager. Kept (not hard-deleted) for audit and so
  /// a concurrent device's flip converges via LWW rather than resurrecting it.
  consumed,
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

/// Status of a change set (batch of proposed mutations).
enum ChangeSetStatus {
  /// Awaiting user review — no items have been resolved yet.
  pending,

  /// Some items have been confirmed or rejected, but others remain.
  partiallyResolved,

  /// All items have been resolved (confirmed or rejected).
  resolved,

  /// The change set was not reviewed within the expiration window.
  expired,
}

/// Status of an individual change item within a change set.
enum ChangeItemStatus {
  /// Awaiting user decision.
  pending,

  /// User confirmed — the mutation has been applied.
  confirmed,

  /// User rejected — the mutation was not applied.
  rejected,

  /// User deferred — will review later.
  deferred,

  /// The agent withdrew this proposal on its own (e.g., it became redundant
  /// with the current task state or duplicated another open proposal).
  /// No user action occurred.
  retracted,
}

/// Verdict on a single change item, persisted for decision history.
enum ChangeDecisionVerdict {
  /// User approved the proposed change.
  confirmed,

  /// User rejected the proposed change.
  rejected,

  /// User deferred the decision.
  deferred,

  /// The agent withdrew its own proposal autonomously — never user-gated.
  retracted,
}

/// Who recorded a [ChangeDecisionVerdict] — disambiguates user decisions from
/// agent-autonomous retractions.
enum DecisionActor {
  /// The end user confirmed, rejected, or deferred the proposal.
  user,

  /// The task agent retracted its own proposal during a wake.
  agent,
}

/// Lifecycle state of a persisted project recommendation.
enum ProjectRecommendationStatus {
  /// Currently relevant and visible on the project detail page.
  active,

  /// Explicitly marked complete by the user.
  resolved,

  /// Explicitly dismissed by the user.
  dismissed,

  /// Replaced by a newer recommendation set.
  superseded,
}

/// Sentiment classification for agent feedback.
enum FeedbackSentiment {
  /// Positive signal (e.g., confirmed change, high confidence report).
  positive,

  /// Negative signal (e.g., rejected change, low confidence report).
  negative,

  /// Neutral or ambiguous signal.
  neutral,
}

/// Category of agent feedback for aggregation and trending.
enum FeedbackCategory {
  /// Accuracy of agent observations and reports.
  accuracy,

  /// Quality of agent communication and report clarity.
  communication,

  /// Task prioritization and focus decisions.
  prioritization,

  /// Tool usage patterns and effectiveness.
  tooling,

  /// Response timeliness and wake frequency appropriateness.
  timeliness,

  /// General feedback that doesn't fit other categories.
  general,
}

/// Priority level for agent observations.
///
/// Allows agents to encode urgency when recording observations, ensuring
/// that grievances and excellence notes surface prominently in rituals.
enum ObservationPriority {
  /// Routine observation — patterns, insights, process notes.
  routine,

  /// Notable observation — worth reviewing but not urgent.
  notable,

  /// Critical observation — user grievance or excellence note that MUST
  /// be reviewed in the next one-on-one session.
  critical,
}

/// Category of an agent observation, assigned at recording time.
///
/// This is distinct from [FeedbackCategory] (which is for aggregated
/// feedback classification). Observation categories encode the agent's
/// intent when writing the observation.
enum ObservationCategory {
  /// A user-reported grievance — something went wrong, a request was
  /// ignored, or behavior was unsatisfactory.
  grievance,

  /// A note of excellence — something the agent or template did
  /// particularly well, or explicit user praise.
  excellence,

  /// A suggestion for template or process improvement from the user.
  templateImprovement,

  /// A routine operational note (patterns, insights, failure notes).
  operational,
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

/// Marks an agent message as recording the completion of a wake milestone.
///
/// When set on `AgentMessageMetadata.milestone`, the message's `createdAt`
/// becomes the watermark for the corresponding derived-state field. The
/// State-as-Projection fold (PR 4) computes each watermark as the
/// `max(createdAt)` of messages carrying the matching milestone, so the
/// watermark converges across devices by set-union instead of being clobbered
/// by last-writer-wins.
///
/// This enum is the milestone vocabulary only — nothing emits these markers
/// yet (B1). Emission is wired in B2 and folded into the projection in B5.
enum AgentMilestone {
  /// A wake cycle finished, including the dormant-skip path → `lastWakeAt`.
  wakeCompleted,

  /// An improver one-on-one ritual completed → `slots.lastOneOnOneAt`.
  oneOnOneCompleted,

  /// An improver feedback scan completed → `slots.lastFeedbackScanAt`.
  feedbackScanCompleted,

  /// A project agent's scheduled daily wake completed → `slots.lastDailyWakeAt`.
  dailyWakeCompleted,

  /// A project agent's weekly review completed → `slots.lastWeeklyReviewAt`.
  weeklyReviewCompleted,
}

/// Parsed capture item role in the Daily OS day-agent reconcile flow.
enum ParsedItemKind {
  /// The phrase should become a new task or planning input.
  newTask,

  /// The phrase appears to refer to an existing task.
  matched,

  /// The phrase proposes an update to an existing task.
  update,
}

/// Confidence bucket for a parsed capture item match.
enum ParsedItemConfidence {
  /// No reliable corpus match.
  low,

  /// A possible corpus match that should be shown as low-confidence.
  medium,

  /// A strong corpus match.
  high,
}

/// Safely looks up an enum value by name, returning `null` on mismatch.
///
/// Normalizes the input by trimming whitespace, stripping underscores, and
/// lowercasing — so both `camelCase` enum names and `snake_case` schema
/// values (e.g., `template_improvement` → `templateimprovement`) match.
T? parseEnumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  final normalized = name.trim().replaceAll('_', '').toLowerCase();
  for (final value in values) {
    if (value.name.toLowerCase() == normalized) return value;
  }
  return null;
}
