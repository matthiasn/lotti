import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// How long a row may stay in the agent store.
enum AgentRetentionClass {
  /// The user's own material. Never deleted by retention, at any age.
  userAuthored,

  /// Derived, but kept anyway — each for a stated reason, so "we decided
  /// against it" never looks like "we didn't get to it".
  keptDerived,

  /// Derived and bounded by age.
  ageBounded,

  /// Derived, bounded by age, and pruned only in causally-safe sets.
  ///
  /// Observations sit inside the agent's `messagePrev` DAG, so they cannot be
  /// deleted row-by-row like a status event: the sweep prunes an
  /// ancestor-closed set and the edges pointing into it, leaving the head set
  /// and `viewComplete` untouched. `planObservationPrune` holds the reasoning.
  observation,
}

/// What the agent store may forget, and after how long.
///
/// The store holds two very different kinds of row under one table. **User
/// authored** rows are the user's own material — captures, day plans, day
/// summaries, directives, knowledge, reports and the identities that own them.
/// **Derived** rows are the machine's working residue: observations it wrote
/// about itself, status events it raised.
///
/// [classify] is **exhaustive over the entity union**, so a new
/// `AgentDomainEntity` variant does not compile until someone decides what
/// happens to it. That is deliberate: a wildcard would let a new machine-derived
/// row start accumulating forever with no test and no compiler failure.
class AgentRetentionPolicy {
  const AgentRetentionPolicy({
    this.dayStatusEvents = const Duration(days: 90),
    this.observations = const Duration(days: 180),
    this.agentsPerSweep = 25,
    this.maxAgentsPerSweep = 500,
    this.maxAgentMessages = 20000,
    this.batchSize = 500,
    this.maxBatchesPerSweep = 20,
  });

  /// How long raised day-status events are kept.
  ///
  /// The digest reads them from its watermark (plus 12h sync-lag slack), so a
  /// window measured in months is far beyond any read that exists.
  final Duration dayStatusEvents;

  /// How long an agent's own observations are kept.
  ///
  /// Twice the status-event window: observations are the agent's working notes
  /// about itself, and a wake may still summarise several months back. Nothing
  /// reads them by age after that, but the cost of keeping them a while longer
  /// is one row, whereas deleting one early loses context permanently.
  final Duration observations;

  /// Agents fetched per page while walking toward the delete budget.
  final int agentsPerSweep;

  /// Hard ceiling on agents examined in one sweep, so a store where nothing is
  /// prunable still ends in bounded time rather than walking every agent.
  final int maxAgentsPerSweep;

  /// An agent whose message log is longer than this is skipped rather than
  /// partially pruned — ancestor-closure needs the chain from its root, and a
  /// truncated view would hide the parents that block a delete.
  final int maxAgentMessages;

  /// Rows deleted per statement. Each batch commits on its own.
  final int batchSize;

  /// Batches per type per sweep, so one start-up pass on a very large store
  /// stays bounded and the remainder is collected on the next start.
  final int maxBatchesPerSweep;

  /// What retention may do with [entity].
  ///
  /// Exhaustive by construction — `map` has no fallback branch, so adding a
  /// variant is a compile error until it is classified here.
  AgentRetentionClass classify(AgentDomainEntity entity) => entity.map(
    // ── The user's own material ──────────────────────────────────────────
    capture: (_) => AgentRetentionClass.userAuthored,
    parsedItem: (_) => AgentRetentionClass.userAuthored,
    dayPlan: (_) => AgentRetentionClass.userAuthored,
    daySummary: (_) => AgentRetentionClass.userAuthored,
    dayDirective: (_) => AgentRetentionClass.userAuthored,
    plannerKnowledge: (_) => AgentRetentionClass.userAuthored,
    agentReport: (_) => AgentRetentionClass.userAuthored,
    agentReportHead: (_) => AgentRetentionClass.userAuthored,
    soulDocument: (_) => AgentRetentionClass.userAuthored,
    soulDocumentVersion: (_) => AgentRetentionClass.userAuthored,
    soulDocumentHead: (_) => AgentRetentionClass.userAuthored,
    agentTemplate: (_) => AgentRetentionClass.userAuthored,
    agentTemplateVersion: (_) => AgentRetentionClass.userAuthored,
    agentTemplateHead: (_) => AgentRetentionClass.userAuthored,
    evolutionSession: (_) => AgentRetentionClass.userAuthored,
    evolutionSessionRecap: (_) => AgentRetentionClass.userAuthored,
    evolutionNote: (_) => AgentRetentionClass.userAuthored,

    // ── Identity and live state: deleting these breaks the agent ─────────
    agent: (_) => AgentRetentionClass.keptDerived,
    agentState: (_) => AgentRetentionClass.keptDerived,
    scheduledWake: (_) => AgentRetentionClass.keptDerived,
    unknown: (_) => AgentRetentionClass.keptDerived,

    // ── Derived, kept deliberately ───────────────────────────────────────
    // weekRollup: one register per ISO week (~52 rows/year) and the digest's
    // only month-scale trend source. Bounded and load-bearing.
    weekRollup: (_) => AgentRetentionClass.keptDerived,
    // wakeTokenUsage: the template detail page aggregates it over ALL TIME.
    // Pruning would silently rewrite a number the user can read off the
    // screen; compacting into per-month aggregates is the way to bound it.
    wakeTokenUsage: (_) => AgentRetentionClass.keptDerived,
    // The audit trail behind proposals the user accepted or rejected.
    changeSet: (_) => AgentRetentionClass.keptDerived,
    changeDecision: (_) => AgentRetentionClass.keptDerived,
    attentionRequest: (_) => AgentRetentionClass.keptDerived,
    attentionClaimDisposition: (_) => AgentRetentionClass.keptDerived,
    attentionAward: (_) => AgentRetentionClass.keptDerived,
    standingAgreement: (_) => AgentRetentionClass.keptDerived,
    projectRecommendation: (_) => AgentRetentionClass.keptDerived,

    // ── Derived and bounded ──────────────────────────────────────────────
    dayStatusEvent: (_) => AgentRetentionClass.ageBounded,
    // Only observations are bounded; summaries and every other message kind
    // are the agent's durable memory and stay.
    agentMessage: (e) => e.kind == AgentMessageKind.observation
        ? AgentRetentionClass.observation
        : AgentRetentionClass.keptDerived,
    // A payload's fate follows the message that owns it, which the sweep
    // resolves by id — never by age of its own.
    agentMessagePayload: (_) => AgentRetentionClass.keptDerived,
  );
}
